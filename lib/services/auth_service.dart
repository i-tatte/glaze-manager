import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ユーザーの状態を監視するStream
  Stream<User?> get user => _auth.authStateChanges();

  /// 匿名でサインインする
  /// アプリ起動時に呼び出すことで、ユーザーに操作を意識させることなく
  /// バックグラウンドでFirebaseにサインインし、ユニークIDを取得します。
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      debugPrint("Signed in anonymously with user: ${userCredential.user?.uid}");
      return userCredential.user;
    } catch (e) {
      debugPrint("Error signing in anonymously: $e");
      return null;
    }
  }
  
  // /// Googleでサインイン (将来的に実装)
  // Future<User?> signInWithGoogle() async {
  //   // to be implemented
  // }

  /// サインアウト
  Future<void> signOut() async {
    // 匿名認証の場合、通常サインアウトは不要ですが、
    // デバッグやアカウント切り替えのために実装しておきます。
    await _auth.signOut();
  }
}
