import 'package:flutter/material.dart';
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
                      DropdownButton<ThemeMode>(
                        value: settings.themeMode,
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
