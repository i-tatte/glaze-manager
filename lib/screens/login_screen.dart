import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:glaze_manager/screens/email_password_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// サインイン方法を識別するためのenum
enum AuthMethod { anonymous, google }

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリ開始')),
      body: _buildBody(),
    );
  }

  /// 画面のメインコンテンツを構築する
  Widget _buildBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '釉薬レシピ管理アプリへようこそ！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'サインイン方法を選択してください。',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.person_outline),
                          label: const Text(
                            '匿名で始める',
                            style: TextStyle(fontSize: 18),
                          ),
                          onPressed: () => _signIn(AuthMethod.anonymous),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          // Googleアイコンは別途画像アセットを用意するか、標準アイコンで代用します
                          icon: const Icon(Icons.login),
                          label: const Text(
                            'Googleでサインイン',
                            style: TextStyle(fontSize: 18),
                          ),
                          onPressed: () => _signIn(AuthMethod.google),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.email_outlined),
                          label: const Text(
                            'メールアドレスでサインイン/登録',
                            style: TextStyle(fontSize: 18),
                          ),
                          onPressed: () => _navigateToEmailLogin(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        icon: const Icon(Icons.move_down),
                        label: const Text('引き継ぎコードでログイン (機種変更の方)'),
                        onPressed: _showTransferCodeDialog,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToEmailLogin(BuildContext context) async {
    // インターネット接続を確認
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.mobile) &&
        !connectivityResult.contains(ConnectivityResult.wifi) &&
        !connectivityResult.contains(ConnectivityResult.ethernet)) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('インターネット接続がありません'),
            content: const Text('サインイン/登録するにはインターネット接続が必要です。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EmailPasswordLoginScreen()));
  }

  /// 引き継ぎコードの入力ダイアログを表示し、コードでログインする
  Future<void> _showTransferCodeDialog() async {
    final codeController = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('引き継ぎコードでログイン'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('旧端末の「設定 > 引き継ぎコードを発行」で表示されたコードを入力してください。'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '引き継ぎコード',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(codeController.text.trim()),
            child: const Text('ログイン'),
          ),
        ],
      ),
    );

    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithTransferCode(code);
      // 成功時はAuthWrapperが画面遷移をハンドルする
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? '引き継ぎに失敗しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('引き継ぎに失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn(AuthMethod method) async {
    // インターネット接続を確認
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('インターネット接続がありません'),
            content: const Text('利用を開始するにはインターネット接続が必要です。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return; // 接続がない場合は処理を中断
    }
    // 匿名ログインの場合、警告ダイアログを表示
    if (!mounted) return;
    if (method == AuthMethod.anonymous) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('匿名ログインの注意点'),
          content: const Text(
            '匿名ログインでは、アプリを削除したり機種変更した場合にデータを引き継ぐことができません。\n\nGoogleサインインで始めると、別デバイスでも同じデータを利用できます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('匿名で続ける'),
            ),
          ],
        ),
      );
      if (confirmed != true) return; // 匿名ログインをキャンセル
      if (!mounted) return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      switch (method) {
        case AuthMethod.anonymous:
          await authService.signInAnonymously();
          break;
        case AuthMethod.google:
          await authService.signInWithGoogle();
          break;
      }
    } catch (e) {
      // Googleサインインのダイアログを閉じた場合など、ユーザー起因のキャンセルはエラー表示しない
      if (e is! GoogleSignInCanceled) {
        debugPrint("Sign-in failed: $e");
      }
    }
    // 成功時はAuthWrapperが画面遷移をハンドルするが、失敗時やキャンセル時に備えてローディングを解除
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
