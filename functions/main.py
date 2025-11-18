import os
import tempfile
import uuid
from firebase_functions import storage_fn, options
from firebase_admin import initialize_app, storage, firestore
from PIL import Image

# Firebase Admin SDKを初期化
initialize_app()

# リージョンを設定 (Storageバケットと同じリージョン)
options.set_global_options(region="us-central1")

@storage_fn.on_object_finalized()
def generate_thumbnail(event: storage_fn.CloudEvent):
    """テストピース画像がアップロードされたときにサムネイルを生成し、Firestoreドキュメントを更新する"""

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
        original_image_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{original_blob.name.replace('/', '%2F')}?alt=media&token={original_token}"
        print(f"Generated original image URL with token: {original_image_url}")

        # サムネイル画像のURL
        thumbnail_token = uuid.uuid4()
        thumb_blob.metadata = {"firebaseStorageDownloadTokens": str(thumbnail_token)}
        thumb_blob.patch()
        thumbnail_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{thumb_blob.name.replace('/', '%2F')}?alt=media&token={thumbnail_token}"
        print(f"Generated thumbnail URL with token: {thumbnail_url}")
        
        # 7. Firestoreドキュメントを両方のURLで更新
        doc_snapshot.reference.update({
            "imageUrl": original_image_url,
            "thumbnailUrl": thumbnail_url
            # TODO: ここでPillowやOpenCVを使って色味データ(colorData)の生成・更新も可能
        })

        print(f"Firestore document {doc_snapshot.id} updated with image and thumbnail URLs.")

    return
