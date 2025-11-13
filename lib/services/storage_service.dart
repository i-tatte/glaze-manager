import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// 画像をアップロードし、ダウンロードURLを返す
  Future<String?> uploadTestPieceImage(XFile imageFile) async {
    if (_userId == null) throw Exception("User not logged in");

    try {
      final filePath =
          'users/$_userId/test_pieces/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final ref = _storage.ref(filePath);

      final uploadTask = await ref.putFile(File(imageFile.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Image upload failed: $e');
      return null;
    }
  }

  /// 画像を削除する
  Future<void> deleteTestPieceImage(String imageUrl) async {
    if (_userId == null) throw Exception("User not logged in");

    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Image deletion failed: $e');
    }
  }
}
