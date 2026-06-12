import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/screens/firing_profile_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:glaze_manager/screens/clay_list_screen.dart';
import 'package:glaze_manager/screens/firing_atmosphere_list_screen.dart';
import 'package:glaze_manager/screens/help_screen.dart';

class SettingsScreen extends StatefulWidget {
  final PageStorageKey? pageStorageKey;
  const SettingsScreen({super.key, this.pageStorageKey});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        return ListView(
          children: [
            const _SectionHeader(title: 'アカウント'),
            const _AccountSection(),
            const Divider(),
            const _SectionHeader(title: '表示'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _GridCountSlider(
                    key: ValueKey(settings.gridCrossAxisCount),
                    initialValue: settings.gridCrossAxisCount,
                    maxValue: settings.maxGridCrossAxisCount,
                    onChanged: (newValue) {
                      settings.setGridCrossAxisCount(newValue);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('テーマ'),
                      SizedBox(
                        width: 200, // 幅を制限してバランスを取る
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            isDense: true,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ThemeMode>(
                              value: settings.themeMode,
                              isExpanded: true,
                              onChanged: (ThemeMode? newMode) {
                                if (newMode != null) {
                                  settings.setThemeMode(newMode);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text('システム設定に従う'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text('ライトモード'),
                                ),
                                DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text('ダークモード'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            const _SectionHeader(title: 'データ管理'),
            ListTile(
              title: const Text('焼成プロファイルの管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FiringProfileListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('焼成雰囲気の管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FiringAtmosphereListScreen(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('素地土名の管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ClayListScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            const _SectionHeader(title: 'サポート'),
            ListTile(
              title: const Text('ヘルプ / FAQ'),
              trailing: const Icon(Icons.help_outline),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// アカウント状態の表示と、匿名アカウントの連携・引き継ぎコード発行を行うセクション
class _AccountSection extends StatefulWidget {
  const _AccountSection();

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _isBusy = false;

  String _describeUser(User user) {
    if (user.isAnonymous) return '匿名で利用中';
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final email = user.email ?? '';
    if (providers.contains('google.com')) {
      return 'Google連携済み${email.isNotEmpty ? ' ($email)' : ''}';
    }
    if (providers.contains('password')) {
      return 'メール連携済み${email.isNotEmpty ? ' ($email)' : ''}';
    }
    return 'ログイン中';
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const SizedBox.shrink();

        final isAnonymous = user.isAnonymous;
        return Column(
          children: [
            ListTile(
              leading: Icon(
                isAnonymous ? Icons.person_outline : Icons.verified_user,
              ),
              title: Text(_describeUser(user)),
              subtitle: isAnonymous
                  ? const Text('アカウント連携をしておくと、機種変更やアプリ削除時もデータが守られます。')
                  : null,
            ),
            if (_isBusy)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (isAnonymous) ...[
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Googleアカウントと連携'),
                  subtitle: const Text('今のデータをそのままGoogleアカウントに紐付けます'),
                  onTap: _linkWithGoogle,
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('メールアドレスと連携'),
                  subtitle: const Text('今のデータをそのままメールアドレスに紐付けます'),
                  onTap: _showLinkEmailDialog,
                ),
              ],
              ListTile(
                leading: const Icon(Icons.move_down),
                title: const Text('引き継ぎコードを発行'),
                subtitle: const Text('新しい端末でこのデータを使うためのワンタイムコードを発行します'),
                onTap: _issueTransferCode,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _linkWithGoogle() async {
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      final result = await authService.linkWithGoogle();
      if (result != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Googleアカウントと連携しました。')),
        );
      }
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_linkErrorMessage(e))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('連携に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _linkErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'credential-already-in-use':
        return 'このGoogleアカウントは既に別のデータに連携されています。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています。';
      case 'weak-password':
        return 'パスワードが短すぎます (6文字以上にしてください)。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      default:
        return '連携に失敗しました: ${e.message ?? e.code}';
    }
  }

  Future<void> _showLinkEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メールアドレスと連携'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'メールアドレスを入力してください' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'パスワード (6文字以上)'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? '6文字以上で入力してください' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('連携する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      await authService.linkWithEmailAndPassword(
        emailController.text.trim(),
        passwordController.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('メールアドレスと連携しました。')),
      );
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_linkErrorMessage(e))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('連携に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _issueTransferCode() async {
    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      final code = await authService.issueTransferCode();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('引き継ぎコード'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '新しい端末のログイン画面で「引き継ぎコードでログイン」を選び、'
                'このコードを入力してください。\n\n'
                '・有効期限はありません。メモして大切に保管してください\n'
                '・1回使用するか、新しいコードを発行すると無効になります\n'
                '・他人には教えないでください',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('コピー'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('コピーしました。')));
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } on TransferCodeException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('コードの発行に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// スライダーの状態を自己管理するウィジェット
class _GridCountSlider extends StatefulWidget {
  final int initialValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const _GridCountSlider({
    super.key,
    required this.initialValue,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  State<_GridCountSlider> createState() => _GridCountSliderState();
}

class _GridCountSliderState extends State<_GridCountSlider> {
  late final ValueNotifier<int> _currentValueNotifier;

  @override
  void initState() {
    super.initState();
    _currentValueNotifier = ValueNotifier<int>(widget.initialValue);
  }

  @override
  void dispose() {
    _currentValueNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentValueNotifier,
      builder: (context, currentValue, child) {
        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('1行当たりの表示数'),
              trailing: Text(
                '$currentValue 列',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Slider(
              value: currentValue.toDouble(),
              min: 2,
              max: widget.maxValue.toDouble(),
              divisions: widget.maxValue - 2,
              label: '$currentValue 列',
              onChanged: (value) => _currentValueNotifier.value = value.toInt(),
              onChangeEnd: (value) => widget.onChanged(value.toInt()),
            ),
          ],
        );
      },
    );
  }
}
