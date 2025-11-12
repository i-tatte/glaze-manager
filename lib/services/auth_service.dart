import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';

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
      debugPrint(
        "Signed in anonymously with user: ${userCredential.user?.uid}",
      );
      return userCredential.user;
    } catch (e) {
      debugPrint("Error signing in anonymously: $e");
      return null;
    }
  }

  /// メールアドレスとパスワードで新規登録
  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Error signing up with email: $e");
      // 例外を再スローしてUI側でハンドリングさせる
      rethrow;
    }
  }

  /// メールアドレスとパスワードでサインイン
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Error signing in with email: $e");
      // 例外を再スローしてUI側でハンドリングさせる
      rethrow;
    }
  }

  /// Googleでサインイン
  Future<UserCredential?> signInWithGoogle() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Trigger the authentication flow
        final signin = GoogleSignIn.instance;
        await signin.initialize(
          serverClientId:
              '942515568123-g7d6nih90qkc70t17i8qaqka6dcmr6ah.apps.googleusercontent.com',
        );
        final GoogleSignInAccount googleUser = await signin.authenticate();

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        // Once signed in, return the UserCredential
        return await FirebaseAuth.instance.signInWithCredential(credential);
      case TargetPlatform.windows:
        final googleSignInArgs = GoogleSignInArgs(
          clientId:
              '942515568123-g7d6nih90qkc70t17i8qaqka6dcmr6ah.apps.googleusercontent.com',
          redirectUri: 'https://glaze-manager.firebaseapp.com/__/auth/handler',
          scope: 'email',
        );

        try {
          final result = await DesktopWebviewAuth.signIn(googleSignInArgs);
          if (result?.accessToken == null) {
            throw GoogleSignInCanceled();
          }
          final credential = GoogleAuthProvider.credential(
            accessToken: result?.accessToken,
          );
          final userCredential = await _auth.signInWithCredential(credential);
          return userCredential;
        } catch (err) {
          // something went wrong
          //print(err);
          return null;
        }
      case TargetPlatform.macOS:
      default:
        return null;
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// Googleサインインがユーザーによってキャンセルされたことを示すためのカスタム例外
class GoogleSignInCanceled implements Exception {}
