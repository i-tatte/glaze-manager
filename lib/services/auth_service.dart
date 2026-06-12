import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
  //
  // cloud_functions プラグインは Windows に対応していないため、
  // callable プロトコル (POST {"data": ...} / Authorization: Bearer <idToken>)
  // を HTTPS で直接呼び出す。

  static const _functionsBaseUrl =
      'https://us-central1-glaze-manager.cloudfunctions.net';

  /// callable関数を呼び出し、result部分を返す。
  /// サーバーが返したエラーは [TransferCodeException] (日本語メッセージ) にして投げる。
  Future<Map<String, dynamic>> _callFunction(
    String name,
    Map<String, dynamic> payload, {
    required bool requireAuth,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requireAuth) {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) {
        throw TransferCodeException('ログインが必要です。');
      }
      headers['Authorization'] = 'Bearer $idToken';
    }

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$_functionsBaseUrl/$name'),
        headers: headers,
        body: jsonEncode({'data': payload}),
      );
    } catch (e) {
      throw TransferCodeException('サーバーに接続できませんでした。通信環境を確認してください。');
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body == null || body['error'] != null) {
      final error = body?['error'];
      var message = error is Map ? error['message'] as String? : null;
      // HttpsError以外の内部エラーは "INTERNAL" 等のステータス文字列が入るため日本語に置き換える
      if (message == null || RegExp(r'^[A-Z_ ]+$').hasMatch(message)) {
        message = 'サーバーでエラーが発生しました。時間をおいて再度お試しください。';
      }
      throw TransferCodeException(message);
    }

    return Map<String, dynamic>.from(body['result'] as Map);
  }

  /// 引き継ぎコードを発行する (旧端末で実行)。
  /// 返されたコードを新端末で [signInWithTransferCode] に入力すると、
  /// このアカウントとしてログインできる。
  ///
  /// コードに有効期限はないが、1回使用するか再発行すると無効になる。
  Future<String> issueTransferCode() async {
    final result = await _callFunction(
      'issue_transfer_code',
      {},
      requireAuth: true,
    );
    return result['code'] as String;
  }

  /// 引き継ぎコードでサインインする (新端末で実行)。
  /// コードが無効・使用済みの場合は [TransferCodeException] をスローする。
  Future<User?> signInWithTransferCode(String code) async {
    final result = await _callFunction(
      'redeem_transfer_code',
      {'code': code},
      requireAuth: false,
    );
    final userCredential = await _auth.signInWithCustomToken(
      result['token'] as String,
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

/// 引き継ぎコードの発行・引き換えに失敗したことを示す例外 (messageは表示可能な日本語)
class TransferCodeException implements Exception {
  final String message;
  TransferCodeException(this.message);

  @override
  String toString() => message;
}
