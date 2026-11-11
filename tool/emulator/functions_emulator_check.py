"""Cloud Functions (process_uploaded_image) をエミュレータで確かめる。

Firestore / Storage / Functions のエミュレータが起動している前提。
実プロジェクトには一切触れない (demo- プロジェクトのエミュレータの REST だけを使う)。
"""
import io
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

from PIL import Image

sys.stdout = io.TextIOWrapper(
    sys.stdout.buffer, encoding="utf-8", errors="replace", line_buffering=True
)

PROJECT = "demo-glaze-manager"
BUCKET = sys.argv[1] if len(sys.argv) > 1 else f"{PROJECT}.appspot.com"
FIRESTORE = f"http://127.0.0.1:8080/v1/projects/{PROJECT}/databases/(default)/documents"
STORAGE = "http://127.0.0.1:9199"
ADMIN = {"Authorization": "Bearer owner"}

UID = "fn-check-" + uuid.uuid4().hex[:8]
results: list[tuple[str, bool, str]] = []


def http(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method)
    for k, v in {**ADMIN, **(headers or {})}.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            raw = res.read()
            return res.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw.decode("utf-8", "replace")


def to_value(v):
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [to_value(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: to_value(x) for k, x in v.items()}}}
    raise TypeError(type(v))


def from_value(v):
    if "nullValue" in v:
        return None
    if "booleanValue" in v:
        return v["booleanValue"]
    if "integerValue" in v:
        return int(v["integerValue"])
    if "doubleValue" in v:
        return float(v["doubleValue"])
    if "stringValue" in v:
        return v["stringValue"]
    if "timestampValue" in v:
        return v["timestampValue"]
    if "arrayValue" in v:
        return [from_value(x) for x in v["arrayValue"].get("values", [])]
    if "mapValue" in v:
        return {k: from_value(x) for k, x in v["mapValue"].get("fields", {}).items()}
    return v


def doc_url(doc_id):
    return f"{FIRESTORE}/users/{UID}/test_pieces/{doc_id}"


def set_doc(doc_id, fields):
    status, body = http(
        "PATCH",
        doc_url(doc_id),
        json.dumps({"fields": {k: to_value(v) for k, v in fields.items()}}).encode(),
        {"Content-Type": "application/json"},
    )
    assert status == 200, (status, body)


def update_doc(doc_id, fields):
    mask = "&".join(
        "updateMask.fieldPaths=" + urllib.parse.quote(k) for k in fields
    )
    status, body = http(
        "PATCH",
        doc_url(doc_id) + "?" + mask,
        json.dumps({"fields": {k: to_value(v) for k, v in fields.items()}}).encode(),
        {"Content-Type": "application/json"},
    )
    assert status == 200, (status, body)


def get_doc(doc_id):
    status, body = http("GET", doc_url(doc_id))
    if status == 404:
        return None
    assert status == 200, (status, body)
    return {k: from_value(v) for k, v in body.get("fields", {}).items()}


def image_path(doc_id, name):
    return f"users/{UID}/test_pieces/images/{doc_id}/{name}"


def thumb_path(doc_id, name):
    return f"users/{UID}/test_pieces/thumbnails/{doc_id}/thumb_{name}"


def jpeg(color):
    buf = io.BytesIO()
    Image.new("RGB", (400, 400), color).save(buf, "JPEG", quality=90)
    return buf.getvalue()


def upload(path, data, content_type="image/jpeg"):
    """Firebase の SDK と同じマルチパート形式で送る (contentType をメタデータで渡す)。"""
    boundary = "gmcheck" + uuid.uuid4().hex
    meta = json.dumps({"name": path, "contentType": content_type}).encode()
    body = b"".join(
        [
            f"--{boundary}\r\nContent-Type: application/json; charset=utf-8\r\n\r\n".encode(),
            meta,
            f"\r\n--{boundary}\r\nContent-Type: {content_type}\r\n\r\n".encode(),
            data,
            f"\r\n--{boundary}--".encode(),
        ]
    )
    url = f"{STORAGE}/v0/b/{BUCKET}/o?name=" + urllib.parse.quote(path, safe="")
    status, res = http(
        "POST",
        url,
        body,
        {
            "Content-Type": f"multipart/related; boundary={boundary}",
            "X-Goog-Upload-Protocol": "multipart",
        },
    )
    assert status == 200, (status, res)
    assert (res or {}).get("contentType") == content_type, res


def list_objects(prefix):
    url = (
        f"{STORAGE}/storage/v1/b/{BUCKET}/o?prefix="
        + urllib.parse.quote(prefix, safe="")
    )
    status, body = http("GET", url)
    assert status == 200, (status, body)
    return sorted(item["name"] for item in (body or {}).get("items", []))


def wait_for(predicate, timeout=60.0, interval=0.5):
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        last = predicate()
        if last:
            return last
        time.sleep(interval)
    return None


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    print(("  PASS " if ok else "  FAIL ") + name + (f"  -- {detail}" if detail else ""))


def files_of(doc_id):
    return (
        list_objects(f"users/{UID}/test_pieces/images/{doc_id}/"),
        list_objects(f"users/{UID}/test_pieces/thumbnails/{doc_id}/"),
    )


def settle(doc_id, expect_images, expect_thumbs, timeout=30.0):
    """フォルダの中身が期待どおりになるまで待つ。最後に見えた中身を返す。"""
    state = {}

    def pred():
        state["files"] = files_of(doc_id)
        return state["files"] == (sorted(expect_images), sorted(expect_thumbs))

    wait_for(pred, timeout=timeout)
    return state["files"]


base_doc = {
    "glazeId": "g1",
    "clayId": "c1",
    "additionalGlazeIds": [],
    "relatedGlazeIds": ["g1"],
    "createdAt": "2026-11-11T00:00:00Z",
}

print(f"bucket={BUCKET} uid={UID}")

# --- S1: 新規登録 (文書に imagePath を書いてから画像を送る) ---
print("S1: 新規登録")
d1 = "doc-s1"
a = "a.jpg"
set_doc(d1, {**base_doc, "imagePath": image_path(d1, a)})
t0 = time.time()
upload(image_path(d1, a), jpeg((200, 30, 30)))
doc = wait_for(lambda: (get_doc(d1) or {}).get("thumbnailUrl") and get_doc(d1), timeout=45)
check("S1 書き戻しが届く", doc is not None, f"{time.time() - t0:.1f}s")
if doc:
    check("S1 imageUrl は送った画像を指す", urllib.parse.quote(image_path(d1, a), safe="") in doc.get("imageUrl", ""))
    check("S1 thumbnailUrl はサムネイルを指す", urllib.parse.quote(thumb_path(d1, a), safe="") in doc.get("thumbnailUrl", ""))
    colors = doc.get("colorData") or []
    check("S1 colorData が書かれる", len(colors) >= 1 and {"L", "a", "b", "percentage"} <= set(colors[0]), json.dumps(colors[:1]))
    check("S1 imagePath は変わらない", doc.get("imagePath") == image_path(d1, a))
imgs, thumbs = settle(d1, [image_path(d1, a)], [thumb_path(d1, a)])
check("S1 画像とサムネイルが 1 組だけある", (imgs, thumbs) == ([image_path(d1, a)], [thumb_path(d1, a)]), f"{imgs} {thumbs}")

# --- S2: 続けて 2 回差し替える (最後に選んだ画像が残ること) ---
print("S2: 続けて 2 回差し替え")
b, c = "b.jpg", "c.jpg"
update_doc(d1, {"imagePath": image_path(d1, b), "colorData": []})
upload(image_path(d1, b), jpeg((30, 200, 30)))
update_doc(d1, {"imagePath": image_path(d1, c), "colorData": []})
upload(image_path(d1, c), jpeg((30, 30, 200)))
doc = wait_for(
    lambda: (lambda x: x if urllib.parse.quote(image_path(d1, c), safe="") in (x or {}).get("imageUrl", "") else None)(get_doc(d1)),
    timeout=45,
)
check("S2 文書は最後の画像 C を指す", doc is not None, (get_doc(d1) or {}).get("imageUrl", "")[-60:])
imgs, thumbs = settle(d1, [image_path(d1, c)], [thumb_path(d1, c)], timeout=45)
check("S2 画像は C だけが残る", imgs == [image_path(d1, c)], str(imgs))
check("S2 サムネイルは C のものだけが残る", thumbs == [thumb_path(d1, c)], str(thumbs))
doc = get_doc(d1)
check("S2 thumbnailUrl は C のサムネイル", urllib.parse.quote(thumb_path(d1, c), safe="") in doc.get("thumbnailUrl", ""))
colors = doc.get("colorData") or []
# C は青 (b* が大きく負)。B (緑) や A (赤) の色が残っていないこと
check("S2 colorData は C の色 (青)", len(colors) >= 1 and colors[0]["b"] < -40, json.dumps(colors[:1]))
check("S2 imagePath は C のまま", doc.get("imagePath") == image_path(d1, c))

# --- S3: 古い画像が後から届く (再送) ---
print("S3: 古い画像が後から届く")
late = "late.jpg"
before = get_doc(d1)
upload(image_path(d1, late), jpeg((240, 240, 30)))
imgs, thumbs = settle(d1, [image_path(d1, c)], [thumb_path(d1, c)], timeout=45)
check("S3 古い画像は消され、C は残る", imgs == [image_path(d1, c)], str(imgs))
check("S3 古い画像のサムネイルは残らない", thumbs == [thumb_path(d1, c)], str(thumbs))
after = get_doc(d1)
check("S3 文書は書き換えられない", after == before)

# --- S4: 手動で登録した色は上書きしない ---
print("S4: 手動の色を保つ")
d4 = "doc-s4"
manual = [{"L": 50.0, "a": 1.0, "b": 2.0, "percentage": 100.0}]
set_doc(d4, {**base_doc, "imagePath": image_path(d4, a), "colorData": manual})
upload(image_path(d4, a), jpeg((200, 30, 30)))
doc = wait_for(lambda: (get_doc(d4) or {}).get("thumbnailUrl") and get_doc(d4), timeout=45)
check("S4 書き戻しが届く", doc is not None)
if doc:
    check("S4 手動の色はそのまま", doc.get("colorData") == manual, json.dumps(doc.get("colorData")))

# --- S5: 文書の書き込みより先に画像が届く (クライアントが守るべき順序の裏返し) ---
print("S5: 文書がないまま画像が届く")
d5 = "doc-s5"
upload(image_path(d5, a), jpeg((200, 30, 30)))
time.sleep(8)
check("S5 文書は作られない", get_doc(d5) is None)
imgs, thumbs = files_of(d5)
print(f"  (参考) 残ったファイル: {imgs} {thumbs}")

# --- S6: 画像を差し替えたが imagePath の更新が届く前に新しい画像が届く ---
print("S6: imagePath の更新より先に新しい画像が届く")
d6 = "doc-s6"
set_doc(d6, {**base_doc, "imagePath": image_path(d6, a)})
upload(image_path(d6, a), jpeg((200, 30, 30)))
wait_for(lambda: (get_doc(d6) or {}).get("thumbnailUrl"), timeout=45)
settle(d6, [image_path(d6, a)], [thumb_path(d6, a)])
upload(image_path(d6, b), jpeg((30, 200, 30)))  # 文書はまだ A を指している
time.sleep(8)
imgs, thumbs = files_of(d6)
doc = get_doc(d6)
print(f"  (参考) imagePath 更新前に届いた B の扱い: images={[i.rsplit('/', 1)[-1] for i in imgs]} thumbs={[t.rsplit('/', 1)[-1] for t in thumbs]}")
check("S6 文書は A を指したまま", urllib.parse.quote(image_path(d6, a), safe="") in doc.get("imageUrl", ""))
check("S6 先に届いた B は古い処理として消される (だからクライアントは文書の到達を待つ)", image_path(d6, b) not in imgs, str(imgs))

failed = [r for r in results if not r[1]]
print(f"\n{len(results) - len(failed)}/{len(results)} passed")
sys.exit(1 if failed else 0)
