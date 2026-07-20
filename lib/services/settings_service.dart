import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:glaze_manager/models/test_piece_group_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリケーション全体の設定を管理するサービスクラス
class SettingsService with ChangeNotifier {
  // SharedPreferencesで使用するキー
  static const String _gridCrossAxisCountKey = 'gridCrossAxisCount';
  static const String _testPieceGroupKeyKey = 'testPieceGroupKey';

  // デフォルト値
  static const int _defaultGridCrossAxisCount = 4;

  late SharedPreferences _prefs;

  // 設定値のプロパティ
  int _gridCrossAxisCount = _defaultGridCrossAxisCount;
  int get gridCrossAxisCount => _gridCrossAxisCount;

  // テストピース一覧のグループ表示キー (デフォルトは「なし」)
  TestPieceGroupKey _testPieceGroupKey = TestPieceGroupKey.none;
  TestPieceGroupKey get testPieceGroupKey => _testPieceGroupKey;

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

    // グループ表示キー (name文字列で保存。未知の値は「なし」に落ちる)
    _testPieceGroupKey = TestPieceGroupKey.fromName(
      _prefs.getString(_testPieceGroupKeyKey),
    );

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

  /// テストピース一覧のグループ表示キーを設定し、永続化する
  Future<void> setTestPieceGroupKey(TestPieceGroupKey key) async {
    _testPieceGroupKey = key;
    await _prefs.setString(_testPieceGroupKeyKey, key.name);
    notifyListeners();
  }

  /// テーマモードを設定し、永続化する
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }
}
