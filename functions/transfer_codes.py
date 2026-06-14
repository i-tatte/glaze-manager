import hashlib
import secrets

from firebase_functions import https_fn
from firebase_admin import auth as admin_auth
from firebase_admin import firestore

TRANSFER_CODE_LENGTH = 12
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
