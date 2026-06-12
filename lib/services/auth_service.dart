import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:desktop_webview_auth/desktop_webview_auth.dart';
import 'package:desktop_webview_auth/google.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static const _googleClientId =
      '942515568123-g7d6nih90qkc70t17i8qaqka6dcmr6ah.apps.googleusercontent.com';

  /// ユーザーの状態を監視するStream
  Stream<User?> get user => _auth.authStateChanges();

  /// 現在のユーザー (未ログイン時はnull)
  User? get currentUser => _auth.currentUser;

  /// 匿名ユーザーかどうか
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

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

  /// プラットフォームに応じてGoogleの認証クレデンシャルを取得する。
  /// ユーザーがキャンセルした場合は [GoogleSignInCanceled] を投げる。
  Future<AuthCredential> _obtainGoogleCredential() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final signin = GoogleSignIn.instance;
        await signin.initialize(serverClientId: _googleClientId);
        final GoogleSignInAccount googleUser;
        try {
          googleUser = await signin.authenticate();
        } on GoogleSignInException {
          throw GoogleSignInCanceled();
        }
        final googleAuth = googleUser.authentication;
        return GoogleAuthProvider.credential(idToken: googleAuth.idToken);

      case TargetPlatform.windows:
        final googleSignInArgs = GoogleSignInArgs(
          clientId: _googleClientId,
          redirectUri: 'https://glaze-manager.firebaseapp.com/__/auth/handler',
          scope: 'email',
        );
        final result = await DesktopWebviewAuth.signIn(googleSignInArgs);
        if (result?.accessToken == null) {
          throw GoogleSignInCanceled();
        }
        return GoogleAuthProvider.credential(accessToken: result?.accessToken);

      default:
        throw UnsupportedError('このプラットフォームではGoogleサインインに対応していません。');
    }
  }

  /// Googleでサインイン
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final credential = await _obtainGoogleCredential();
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInCanceled {
      return null;
    }
  }

  /// 現在の匿名アカウントをGoogleアカウントに昇格 (リンク) する。
  /// データ (uid) を保ったまま、Googleでログインできるようになる。
  ///
  /// キャンセル時はnullを返す。既に使用中のGoogleアカウント等のエラーは
  /// [FirebaseAuthException] としてUI側にスローする。
  Future<UserCredential?> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    try {
      final credential = await _obtainGoogleCredential();
      return await user.linkWithCredential(credential);
    } on GoogleSignInCanceled {
      return null;
    }
  }

  /// 現在の匿名アカウントをメールアドレス+パスワードに昇格 (リンク) する。
  /// エラー (登録済みメール・弱いパスワード等) は [FirebaseAuthException] としてスローする。
  Future<UserCredential> linkWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    return await user.linkWithCredential(credential);
  }

  // --- 引き継ぎコード (機種変更時のデータ引き継ぎ) ---

  /// 引き継ぎコードを発行する (旧端末で実行)。
  /// 返されたコードを新端末で [signInWithTransferCode] に入力すると、
  /// このアカウントとしてログインできる。
  Future<({String code, int expiresInMinutes})> issueTransferCode() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('issue_transfer_code')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      code: data['code'] as String,
      expiresInMinutes: (data['expiresInMinutes'] as num).toInt(),
    );
  }

  /// 引き継ぎコードでサインインする (新端末で実行)。
  /// コードが無効・期限切れ・使用済みの場合は
  /// [FirebaseFunctionsException] をスローする (messageは日本語)。
  Future<User?> signInWithTransferCode(String code) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('redeem_transfer_code')
        .call({'code': code});
    final data = Map<String, dynamic>.from(result.data as Map);
    final userCredential = await _auth.signInWithCustomToken(
      data['token'] as String,
    );
    return userCredential.user;
  }

  /// サインアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

/// Googleサインインがユーザーによってキャンセルされたことを示すためのカスタム例外
class GoogleSignInCanceled implements Exception {}
