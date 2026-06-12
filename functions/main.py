import hashlib
import os
import secrets
import tempfile
import uuid

import numpy as np
import cv2
from firebase_functions import https_fn, storage_fn, options
from firebase_admin import auth as admin_auth
from firebase_admin import initialize_app, storage, firestore
from PIL import Image

# Firebase Admin SDKを初期化
initialize_app()

# リージョンを設定 (Storageバケットと同じリージョン)
options.set_global_options(region="us-central1")

# --- 引き継ぎコード (機種変更時のデータ引き継ぎ) ---
#
# 仕組み:
#   1. 旧端末: issue_transfer_code がコードを発行。
#      コードは平文では保存せず SHA-256 ハッシュをドキュメントIDとして
#      transfer_codes コレクションに保存する。
#      有効期限はない (代替ログイン手段としてメモ保管できる位置づけ)。
#      ただし「1回使用で無効化」「再発行で旧コード無効化」により、
#      1ユーザーにつき有効なコードは常に最大1つ・最大1回分。
#   2. 新端末: redeem_transfer_code がコードを検証し、
#      旧アカウント (uid) のカスタムトークンを返す。
#      クライアントは signInWithCustomToken で旧アカウントとしてログインする。
#
# transfer_codes コレクションは Admin SDK からのみアクセスする
# (セキュリティルールは users/ 配下しか許可していないため、クライアントは読めない)。
#
# 注意: create_custom_token には Functions の実行サービスアカウント
# (このプロジェクトでは 942515568123-compute@developer.gserviceaccount.com) に
# 「サービス アカウント トークン作成者 (roles/iam.serviceAccountTokenCreator)」
# ロールが必要。

TRANSFER_CODE_LENGTH = 12
# 紛らわしい文字 (0/O, 1/I/L) を除いた英大文字+数字
_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


@https_fn.on_call()
def issue_transfer_code(req: https_fn.CallableRequest):
    """ログイン中ユーザーの引き継ぎコードを発行する。

    再発行すると同じユーザーの既存コードはすべて無効化 (削除) される。
    """
    if req.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="ログインが必要です。",
        )

    db = firestore.client()
    codes_ref = db.collection("transfer_codes")

    # 既存コードの無効化 (再発行で古いコードが生き残らないようにする)
    for old_doc in codes_ref.where("uid", "==", req.auth.uid).stream():
        old_doc.reference.delete()

    code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(TRANSFER_CODE_LENGTH))
    codes_ref.document(_hash_code(code)).set({
        "uid": req.auth.uid,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "used": False,
    })

    return {"code": code}


@https_fn.on_call()
def redeem_transfer_code(req: https_fn.CallableRequest):
    """引き継ぎコードを検証し、元アカウントのカスタムトークンを返す"""
    raw = (req.data or {}).get("code", "")
    code = str(raw).strip().upper().replace(" ", "").replace("-", "")
    if len(code) != TRANSFER_CODE_LENGTH:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="コードの形式が正しくありません。",
        )

    db = firestore.client()
    doc_ref = db.collection("transfer_codes").document(_hash_code(code))

    # 1. 検証 (この段階ではまだ使用済みにしない)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.NOT_FOUND,
            message="コードが無効です。入力内容を確認してください。",
        )
    data = snapshot.to_dict()
    if data.get("used"):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="このコードは使用済みです。旧端末で再発行してください。",
        )

    # 2. 先にカスタムトークンを作成する。
    #    (ここで失敗してもコードは未使用のまま残り、再試行できる)
    token = admin_auth.create_custom_token(data["uid"])

    # 3. トークン発行に成功してから使用済み化する (トランザクションで二重使用を防止)
    transaction = db.transaction()

    @firestore.transactional
    def _mark_used(txn):
        snap = doc_ref.get(transaction=txn)
        if not snap.exists or snap.to_dict().get("used"):
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="このコードは使用済みです。旧端末で再発行してください。",
            )
        txn.update(doc_ref, {"used": True, "usedAt": firestore.SERVER_TIMESTAMP})

    _mark_used(transaction)
    return {"token": token.decode("utf-8")}

def analyze_glaze_color(image_path: str, k_init: int = 10, merge_threshold: float = 6.0) -> list[dict]:
    """
    画像から釉薬の主要な色構成を解析する。
    Over-segmentation & Merge手法により、多色釉薬にも対応する。

    Args:
        image_path (str): 解析対象の画像ファイルパス
        k_init (int): K-Meansの初期クラスタ数
        merge_threshold (float): 色を統合する際の色差(ΔE)の閾値

    Returns:
        list[dict]: 解析結果の色のリスト。
                    例: [{'L': 75.4, 'a': -1.2, 'b': 3.4, 'percentage': 60.5}, ...]
    """
    # 1. 画像読み込み
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error: Failed to load image at {image_path}")
        return []

    # 2. 領域抽出 (中心の50%をクロップ)
    h, w, _ = img.shape
    start_x, start_y = w // 4, h // 4
    end_x, end_y = w * 3 // 4, h * 3 // 4
    center_img = img[start_y:end_y, start_x:end_x]

    # 3. 高速化のための縮小
    resized_img = cv2.resize(center_img, (64, 64), interpolation=cv2.INTER_AREA)

    # 3.5. Lab 色空間への変換準備 (float32 正規化; しないと0-255になってLが2.55倍鋭敏になる)
    img_float = resized_img.astype(np.float32) / 255.0

    # 4. 色空間変換 (BGR -> CIELAB)
    lab_img = cv2.cvtColor(img_float, cv2.COLOR_BGR2LAB)
    pixels = lab_img.reshape(-1, 3).astype(np.float32)

    # 5. 初期クラスタリング (K-Means)
    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0)
    _, labels, centers = cv2.kmeans(pixels, k_init, None, criteria, 10, cv2.KMEANS_PP_CENTERS) # type: ignore

    # 6. 色の統合 (Agglomerative Merging)
    # 各クラスタの画素数を計算
    unique_labels, counts = np.unique(labels, return_counts=True)
    # centersがk_initより少ない場合があるため、実際に存在するラベルのみで初期化
    clusters = [
        {'center': centers[i], 'count': counts[np.where(unique_labels == i)[0][0]]}
        for i in unique_labels
    ]

    while True:
        min_dist = float('inf')
        merge_indices = None

        # 最も近い色のペアを探す
        for i in range(len(clusters)):
            for j in range(i + 1, len(clusters)):
                dL = clusters[i]['center'][0] - clusters[j]['center'][0]
                da = clusters[i]['center'][1] - clusters[j]['center'][1]
                db = clusters[i]['center'][2] - clusters[j]['center'][2]
                # 明度の違いを 0.5倍 (50%) に過小評価させる
                dist = np.sqrt((dL * 0.5) ** 2 + da ** 2 + db ** 2)
                if dist < min_dist:
                    min_dist = dist
                    merge_indices = (i, j)

        # 閾値以下のペアがなければ統合を終了
        if min_dist >= merge_threshold or merge_indices is None:
            break

        # 色の統合 (彩度を考慮した加重平均)
        i, j = merge_indices
        c1, c2 = clusters[i], clusters[j]

        # 6.1. 彩度(Saturation)を計算: sqrt(a^2 + b^2)
        # centerは [L, a, b] なので、[1]と[2]を使います
        sat1 = np.sqrt(c1['center'][1]**2 + c1['center'][2]**2)
        sat2 = np.sqrt(c2['center'][1]**2 + c2['center'][2]**2)

        # 6.2. 重み(Weight)を計算: 面積 × (彩度 + 補正値)
        # 補正値(epsilon=1.0)を入れて、無彩色同士のゼロ計算を防ぎます
        epsilon = 1.0
        w1 = c1['count'] * (sat1 + epsilon)
        w2 = c2['count'] * (sat2 + epsilon)

        # 6.3. 新しい重心を計算
        # 単純な面積比ではなく、彩度重み(w)を使うことで白飛びによる色汚染を防ぎます
        new_center = (c1['center'] * w1 + c2['center'] * w2) / (w1 + w2)
        
        # 6.4. 合計画素数は単純加算でOK
        total_count = c1['count'] + c2['count']
        
        # クラスタリストを更新
        clusters.pop(j) # 後ろのインデックスから削除 (インデックスズレ防止)
        clusters.pop(i)
        clusters.append({'center': new_center, 'count': total_count})

    # 7. 出力整形
    total_pixels = resized_img.shape[0] * resized_img.shape[1]
    color_data = []
    for cluster in clusters:
        l, a, b = cluster['center']
        percentage = (cluster['count'] / total_pixels) * 100
        color_data.append({
            'L': round(float(l), 2),
            'a': round(float(a), 2),
            'b': round(float(b), 2),
            'percentage': round(percentage, 2)
        })

    # 構成比率の高い順にソート
    return sorted(color_data, key=lambda x: x['percentage'], reverse=True)

@storage_fn.on_object_finalized()
def process_uploaded_image(event: storage_fn.CloudEvent): # type: ignore exported
    """テストピース画像がアップロードされたときに、サムネイル生成と色解析を行い、Firestoreを更新する"""

    bucket_name = event.data.bucket
    file_path = event.data.name
    content_type = event.data.content_type

    print(f"Storage object finalized: {file_path}")

    # 1. トリガー対象のパスか検証
    #    - test_pieces/images/ フォルダ内の画像のみを対象とする
    #    - サムネイル自身の生成ループを防ぐ
    if not file_path.startswith("users/") or \
       "/test_pieces/images/" not in file_path or \
       not content_type.startswith("image/"):
        print("This is not a target image.")
        return

    file_dir, file_name = os.path.split(file_path)
    segments = file_path.split("/")
    user_id = segments[1]

    # パス形式の判定:
    #   新形式: users/{uid}/test_pieces/images/{docId}/{file} (6セグメント)
    #     → docId で直接ドキュメントを特定できる (検索クエリ不要・競合なし)
    #   旧形式: users/{uid}/test_pieces/images/{file} (5セグメント)
    #     → 従来どおり imagePath でクエリ検索する
    doc_id = segments[4] if len(segments) == 6 else None

    # 2. 一時ファイルに画像をダウンロード
    bucket = storage.bucket(bucket_name)
    original_blob = bucket.blob(file_path)

    # 一時ディレクトリとファイルパスを生成
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_file_path = os.path.join(temp_dir, file_name)
        original_blob.download_to_filename(temp_file_path)
        print(f"Image downloaded locally to {temp_file_path}")

        # 3. サムネイルを生成 (例: 200x200 px)
        thumb_file_name = f"thumb_{file_name}"
        temp_thumb_path = os.path.join(temp_dir, thumb_file_name)

        with Image.open(temp_file_path) as im:
            # アスペクト比を維持したままリサイズ
            im.thumbnail((200, 200))
            im.save(temp_thumb_path, "JPEG")
        print(f"Thumbnail created at {temp_thumb_path}")

        # 3.5. 色味を解析
        color_analysis_result = analyze_glaze_color(temp_file_path)
        print(f"Color analysis result: {color_analysis_result}")

        # 4. サムネイルをStorageにアップロード
        #    新形式の場合はサムネイルも docId フォルダ配下に置く
        if doc_id is not None:
            thumb_upload_path = "/".join(
                ["users", user_id, "test_pieces", "thumbnails", doc_id, thumb_file_name]
            )
        else:
            thumb_upload_path = "/".join(
                ["users", user_id, "test_pieces", "thumbnails", thumb_file_name]
            )
        thumb_blob = bucket.blob(thumb_upload_path)
        thumb_blob.upload_from_filename(temp_thumb_path, content_type="image/jpeg")
        print(f"Thumbnail uploaded to {thumb_upload_path}")

        # 5. Firestoreの該当ドキュメントを特定する
        db = firestore.client()
        test_pieces_ref = db.collection("users").document(user_id).collection("test_pieces")

        doc_snapshot = None
        if doc_id is not None:
            # 新形式: パスに含まれる docId で直接取得
            snapshot = test_pieces_ref.document(doc_id).get()
            if snapshot.exists:
                doc_snapshot = snapshot

        if doc_snapshot is None:
            # 旧形式 (または docId 直接取得に失敗した場合): imagePath で検索
            query = test_pieces_ref.where("imagePath", "==", file_path).limit(1).stream()
            doc_snapshot = next(query, None)

        if doc_snapshot is None:
            print(f"No matching test piece found for imagePath: {file_path}")
            return

        # 6. オリジナル画像とサムネイル画像のダウンロードURLを生成
        
        # オリジナル画像のURL
        original_token = uuid.uuid4()
        original_blob.metadata = {"firebaseStorageDownloadTokens": str(original_token)}
        original_blob.patch()
        original_image_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{str(original_blob.name).replace('/', '%2F')}?alt=media&token={original_token}"
        print(f"Generated original image URL with token: {original_image_url}")

        # サムネイル画像のURL
        thumbnail_token = uuid.uuid4()
        thumb_blob.metadata = {"firebaseStorageDownloadTokens": str(thumbnail_token)}
        thumb_blob.patch()
        thumbnail_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{str(thumb_blob.name).replace('/', '%2F')}?alt=media&token={thumbnail_token}"
        print(f"Generated thumbnail URL with token: {thumbnail_url}")
        
        # 7. Firestoreドキュメントを両方のURLで更新、色解析結果も保存
        doc_snapshot.reference.update({
            "imageUrl": original_image_url,
            "thumbnailUrl": thumbnail_url,
            "colorData": color_analysis_result
        })

        print(f"Firestore document {doc_snapshot.id} updated with image and thumbnail URLs.")

        # 8. 旧世代ファイルの掃除 (新形式のみ)
        #    画像差し替え時、docId フォルダ内に残った過去の画像・サムネイルを削除する
        if doc_id is not None:
            keep_paths = {file_path, thumb_upload_path}
            for subdir in ("images", "thumbnails"):
                prefix = f"users/{user_id}/test_pieces/{subdir}/{doc_id}/"
                for blob in bucket.list_blobs(prefix=prefix):
                    if blob.name in keep_paths:
                        continue
                    try:
                        blob.delete()
                        print(f"Deleted stale file: {blob.name}")
                    except Exception as e:
                        print(f"Failed to delete stale file {blob.name}: {e}")

    return
