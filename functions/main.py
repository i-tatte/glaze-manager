import os
import tempfile
import uuid
import numpy as np
import cv2
from firebase_functions import storage_fn, options
from firebase_admin import initialize_app, storage, firestore
from PIL import Image

# Firebase Admin SDKを初期化
initialize_app()

# リージョンを設定 (Storageバケットと同じリージョン)
options.set_global_options(region="us-central1")

def analyze_glaze_color(image_path: str, k_init: int = 10, merge_threshold: float = 10.0) -> list[dict]:
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
    _, labels, centers = cv2.kmeans(pixels, k_init, None, criteria, 10, cv2.KMEANS_RANDOM_CENTERS) # type: ignore

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
                dist = np.linalg.norm(clusters[i]['center'] - clusters[j]['center'])
                if dist < min_dist:
                    min_dist = dist
                    merge_indices = (i, j)

        # 閾値以下のペアがなければ統合を終了
        if min_dist >= merge_threshold or merge_indices is None:
            break

        # 色の統合 (加重平均)
        i, j = merge_indices
        c1, c2 = clusters[i], clusters[j]
        total_count = c1['count'] + c2['count']
        new_center = (c1['center'] * c1['count'] + c2['center'] * c2['count']) / total_count
        
        # クラスタリストを更新
        clusters.pop(j) # 後ろのインデックスから削除
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
    user_id = file_path.split("/")[1]

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
        thumb_upload_path = os.path.join("users", user_id, "test_pieces", "thumbnails", thumb_file_name)
        thumb_blob = bucket.blob(thumb_upload_path)
        thumb_blob.upload_from_filename(temp_thumb_path, content_type="image/jpeg")
        print(f"Thumbnail uploaded to {thumb_upload_path}")

        # 5. Firestoreの該当ドキュメントを更新
        #    元の画像のURLを元にドキュメントを検索する
        db = firestore.client()

        test_pieces_ref = db.collection("users").document(user_id).collection("test_pieces")
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

    return
