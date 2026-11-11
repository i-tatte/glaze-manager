"""Storage エミュレータ用の補助 (エミュレータで Functions を動かすときだけ読み込む)。

firebase-tools の Storage エミュレータは、GCS JSON API のオブジェクトの PATCH を
`/b/{bucket}/o/{object}` でしか受け付けず、Python のクライアントが使う
`/storage/v1/b/{bucket}/o/{object}` には 501 (Not Implemented) を返す。
本番の GCS では問題なく動くので、製品コードは変えず、エミュレータで動かす
ときだけ `Blob.patch()` を接頭辞なしのパスへ送り直す。

PYTHONPATH にこのディレクトリを入れてエミュレータを起動すると、Python が
起動時に自動で読み込む。
"""
import json
import os
import urllib.request


def _install():
    try:
        from google.cloud.storage import _helpers
    except Exception:  # Functions 以外の Python では何もしない
        return

    original_patch = _helpers._PropertyMixin.patch

    def patch(self, *args, **kwargs):
        host = os.environ.get("STORAGE_EMULATOR_HOST")
        if not host:
            return original_patch(self, *args, **kwargs)
        if not host.startswith("http"):
            host = "http://" + host
        changed = {key: self._properties[key] for key in self._changes}
        request = urllib.request.Request(
            host.rstrip("/") + self.path,
            data=json.dumps(changed).encode("utf-8"),
            method="PATCH",
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer owner",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            self._set_properties(json.loads(response.read()))

    _helpers._PropertyMixin.patch = patch


_install()
