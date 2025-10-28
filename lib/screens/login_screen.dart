import 'package:flutter/material.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

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
              'ユーザー認証機能は今後のアップデートにより追加予定です。',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        'アプリを始める',
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: _signIn, // ロジックをメソッドに分離
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// サインイン処理
  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signInAnonymously();

    // このウィジェットがまだマウントされている場合でも、
    // 認証状態の変更で画面遷移するため、isLoadingをfalseに戻す必要はありません。
    // もしサインインに失敗して画面に留まる場合は、falseに戻す処理が必要です。
  }
}