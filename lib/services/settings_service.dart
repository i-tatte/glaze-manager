import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリケーション全体の設定を管理するサービスクラス
class SettingsService with ChangeNotifier {
  // SharedPreferencesで使用するキー
  static const String _gridCrossAxisCountKey = 'gridCrossAxisCount';

  // デフォルト値
  static const int _defaultGridCrossAxisCount = 4;

  late SharedPreferences _prefs;

  // 設定値のプロパティ
  int _gridCrossAxisCount = _defaultGridCrossAxisCount;
  int get gridCrossAxisCount => _gridCrossAxisCount;

  /// プラットフォームに応じたグリッド列の最大数を返す
  int get maxGridCrossAxisCount {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 10; // Androidの場合は最大10列
    }
    return 20; // その他のプラットフォームでは最大20列
  }

  // コンストラクタで設定をロード
  SettingsService() {
    _loadSettings();
  }

  // テーマ設定
  static const String _themeModeKey = 'themeMode';
  static const ThemeMode _defaultThemeMode = ThemeMode.system;

  ThemeMode _themeMode = _defaultThemeMode;
  ThemeMode get themeMode => _themeMode;

  /// デバイスから設定値を非同期で読み込む
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    // グリッド列数
    final savedCount =
        _prefs.getInt(_gridCrossAxisCountKey) ?? _defaultGridCrossAxisCount;
    _gridCrossAxisCount = savedCount.clamp(2, maxGridCrossAxisCount);

    // テーマ設定
    final savedThemeModeIndex = _prefs.getInt(_themeModeKey);
    if (savedThemeModeIndex != null &&
        savedThemeModeIndex >= 0 &&
        savedThemeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[savedThemeModeIndex];
    } else {
      _themeMode = _defaultThemeMode;
    }

    notifyListeners(); // ロード完了を通知
  }

  /// テストピースのグリッド列数を設定し、永続化する
  Future<void> setGridCrossAxisCount(int count) async {
    // 値が有効な範囲内に収まるようにclamp（丸め処理）する
    _gridCrossAxisCount = count.clamp(2, maxGridCrossAxisCount);
    await _prefs.setInt(_gridCrossAxisCountKey, _gridCrossAxisCount);
    notifyListeners(); // 変更を通知
  }

  /// テーマモードを設定し、永続化する
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }
}
