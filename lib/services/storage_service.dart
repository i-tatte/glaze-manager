import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  StorageService({FirebaseStorage? storage, FirebaseAuth? auth})
    : _storage = storage ?? FirebaseStorage.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// アップロード先のファイルパスを生成して返す
  String getUploadPath({required String name}) {
    if (_userId == null) throw Exception("User not logged in");
    return 'users/$_userId/test_pieces/images/$name';
  }

  /// 画像をアップロードする (待機しない)
  Future<void> uploadTestPieceImage({
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (_userId == null) throw Exception("User not logged in");

    try {
      final filePath = getUploadPath(name: name);
      final ref = _storage.ref(filePath);

      final metadata = mimeType != null
          ? SettableMetadata(contentType: mimeType)
          : null;

      await ref.putData(bytes, metadata);
    } catch (e) {
      debugPrint('Image upload failed: $e');
    }
  }

  /// 画像を削除する
  Future<void> deleteTestPieceImage(String imageUrl) async {
    if (_userId == null) throw Exception("User not logged in");

    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Image deletion failed: $e');
    }
  }
}
