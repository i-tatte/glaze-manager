import os
import unittest
from datetime import datetime, timedelta, timezone

# storage_fn.on_object_finalized() は import 時にバケット名を要求する。
# テストでは Storage に触れないので、ダミーのバケット名を与える。
os.environ.setdefault("FIREBASE_CONFIG", '{"storageBucket": "demo-test-bucket"}')

from image_pipeline import is_stale_processing, select_stale_files  # noqa: E402

UID = "u1"
DOC = "doc1"
IMAGES = f"users/{UID}/test_pieces/images/{DOC}/"
THUMBS = f"users/{UID}/test_pieces/thumbnails/{DOC}/"


class IsStaleProcessingTest(unittest.TestCase):
    def test_same_path_is_current(self):
        path = IMAGES + "a.jpg"
        self.assertFalse(is_stale_processing(path, path, DOC))

    def test_different_path_is_stale(self):
        self.assertTrue(is_stale_processing(IMAGES + "b.jpg", IMAGES + "a.jpg", DOC))

    def test_empty_or_missing_image_path_is_not_checked(self):
        for value in (None, "", 123, []):
            with self.subTest(value=value):
                self.assertFalse(is_stale_processing(value, IMAGES + "a.jpg", DOC))

    def test_legacy_path_is_not_checked(self):
        legacy = f"users/{UID}/test_pieces/images/a.jpg"
        self.assertFalse(is_stale_processing("other.jpg", legacy, None))


class SelectStaleFilesTest(unittest.TestCase):
    def setUp(self):
        self.t0 = datetime(2026, 1, 1, tzinfo=timezone.utc)

    def test_deletes_only_older_images_and_their_thumbnails(self):
        older = (IMAGES + "old.jpg", self.t0 - timedelta(seconds=10))
        current = (IMAGES + "cur.jpg", self.t0)
        newer = (IMAGES + "new.jpg", self.t0 + timedelta(seconds=10))
        thumbs = [THUMBS + "thumb_old.jpg", THUMBS + "thumb_cur.jpg", THUMBS + "thumb_new.jpg"]

        stale = select_stale_files([older, current, newer], thumbs, self.t0)

        self.assertCountEqual(stale, [IMAGES + "old.jpg", THUMBS + "thumb_old.jpg"])

    def test_same_time_is_kept(self):
        same = (IMAGES + "same.jpg", self.t0)
        current = (IMAGES + "cur.jpg", self.t0)
        stale = select_stale_files(
            [same, current], [THUMBS + "thumb_same.jpg", THUMBS + "thumb_cur.jpg"], self.t0
        )
        self.assertEqual(stale, [])

    def test_orphan_thumbnail_is_deleted(self):
        current = (IMAGES + "cur.jpg", self.t0)
        stale = select_stale_files(
            [current], [THUMBS + "thumb_cur.jpg", THUMBS + "thumb_gone.jpg"], self.t0
        )
        self.assertEqual(stale, [THUMBS + "thumb_gone.jpg"])

    def test_unknown_creation_time_is_kept(self):
        unknown = (IMAGES + "unknown.jpg", None)
        current = (IMAGES + "cur.jpg", self.t0)
        stale = select_stale_files(
            [unknown, current], [THUMBS + "thumb_unknown.jpg"], self.t0
        )
        self.assertEqual(stale, [])


if __name__ == "__main__":
    unittest.main()
