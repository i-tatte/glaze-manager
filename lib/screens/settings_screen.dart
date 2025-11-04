import 'package:flutter/material.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/screens/firing_profile_list_screen.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // ConsumerウィジェットでSettingsServiceの変更を監視
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        return ListView(
          children: [
            // 大項目: テストピース設定
            ExpansionTile(
              title: const Text('テストピース設定'),
              initiallyExpanded: true, // 最初から開いておく
              children: [
                // 中項目: 表示設定
                ExpansionTile(
                  title: const Text('  表示設定'), // インデントで階層を表現
                  initiallyExpanded: true,
                  children: [
                    // 設定項目: 1行当たりのテストピース表示数
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0, right: 16.0),
                      // ValueNotifierを使ってスライダー操作中のUI更新を効率化
                      child: _GridCountSlider(
                        key: ValueKey(settings.gridCrossAxisCount),
                        initialValue: settings.gridCrossAxisCount,
                        maxValue: settings.maxGridCrossAxisCount,
                        onChanged: (newValue) {
                          settings.setGridCrossAxisCount(newValue);
                        },
                      ),
                    ),
                  ],
                ),
                // 中項目: 焼成設定
                ExpansionTile(
                  title: const Text('  焼成プロファイル設定'),
                  initiallyExpanded: true,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: 32.0,
                        right: 16.0,
                      ),
                      title: const Text('焼成プロファイルの管理'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const FiringProfileListScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
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
