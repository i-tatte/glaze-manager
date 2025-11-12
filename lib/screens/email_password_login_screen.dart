import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:provider/provider.dart';

enum AuthFormType { login, register }

class EmailPasswordLoginScreen extends StatefulWidget {
  const EmailPasswordLoginScreen({super.key});

  @override
  State<EmailPasswordLoginScreen> createState() =>
      _EmailPasswordLoginScreenState();
}

class _EmailPasswordLoginScreenState extends State<EmailPasswordLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthFormType _formType = AuthFormType.login;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _buttonText => _formType == AuthFormType.login ? 'ログイン' : '新規登録';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    try {
      final authService = context.read<AuthService>();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_formType == AuthFormType.login) {
        await authService.signInWithEmailAndPassword(email, password);
      } else {
        await authService.signUpWithEmailAndPassword(email, password);
      }

      // ログイン/登録に成功したら、この画面を閉じる
      navigator.pop();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFriendlyErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = '予期せぬエラーが発生しました。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getFriendlyErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'このメールアドレスは登録されていません。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      case 'invalid-email':
        return '無効なメールアドレス形式です。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています。';
      case 'weak-password':
        return 'パスワードは6文字以上で設定してください。';
      case 'too-many-requests':
        return '試行回数が多すぎます。後でもう一度お試しください。';
      default:
        return 'エラーが発生しました: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_buttonText)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<AuthFormType>(
                  segments: const [
                    ButtonSegment(
                      value: AuthFormType.login,
                      label: Text('ログイン'),
                    ),
                    ButtonSegment(
                      value: AuthFormType.register,
                      label: Text('新規登録'),
                    ),
                  ],
                  selected: {_formType},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _formType = newSelection.first;
                      _errorMessage = null; // フォームタイプ変更時にエラーメッセージをクリア
                    });
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return '有効なメールアドレスを入力してください。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'パスワードを入力してください。';
                    }
                    if (_formType == AuthFormType.register &&
                        value.length < 6) {
                      return 'パスワードは6文字以上で入力してください。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        _buttonText,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
