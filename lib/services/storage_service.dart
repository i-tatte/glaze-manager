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

  /// アップロード先のファイルパスを生成して返す。
  ///
  /// パスにテストピースのドキュメントIDを含めることで、Cloud Function 側が
  /// パスから直接ドキュメントを特定できる (検索クエリによる競合を排除)。
  String getUploadPath({required String testPieceId, required String name}) {
    if (_userId == null) throw Exception("User not logged in");
    return 'users/$_userId/test_pieces/images/$testPieceId/$name';
  }

  /// 画像をアップロードする。
  ///
  /// 失敗時は例外を伝播する。呼び出し側が完了を待たない場合でも、
  /// catchError 等でユーザーへの通知を行うこと。
  Future<void> uploadTestPieceImage({
    required String testPieceId,
    required String name,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final filePath = getUploadPath(testPieceId: testPieceId, name: name);
    final ref = _storage.ref(filePath);

    final metadata = mimeType != null
        ? SettableMetadata(contentType: mimeType)
        : null;

    await ref.putData(bytes, metadata);
  }

  /// URL指定で画像を削除する (旧形式パスのテストピース用)。
  ///
  /// 失敗してもアプリの動作に支障はない (孤児ファイルが残るだけ) ため、
  /// エラーはログに留める。
  Future<void> deleteTestPieceImage(String imageUrl) async {
    if (_userId == null) throw Exception("User not logged in");

    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Image deletion failed: $e');
    }
  }

  /// テストピースに紐づく画像・サムネイルのフォルダごと削除する (新形式パス用)。
  ///
  /// 旧形式 (フォルダなし) のテストピースではフォルダが空なので何も起きない。
  /// 失敗はログに留める。
  Future<void> deleteAllTestPieceFiles(String testPieceId) async {
    if (_userId == null) throw Exception("User not logged in");

    for (final dir in ['images', 'thumbnails']) {
      try {
        final folderRef = _storage.ref(
          'users/$_userId/test_pieces/$dir/$testPieceId',
        );
        final listing = await folderRef.listAll();
        await Future.wait(listing.items.map((item) => item.delete()));
      } catch (e) {
        debugPrint('Test piece file cleanup failed ($dir): $e');
      }
    }
  }
}
