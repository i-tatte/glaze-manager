import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glaze_manager/screens/glaze_list_screen.dart';
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/screens/settings_screen.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:glaze_manager/screens/test_piece_list_screen.dart';
import 'package:glaze_manager/services/glaze_import_service.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  // 原料一覧画面の編集状態を管理するNotifier
  final _isMaterialsEditingNotifier = ValueNotifier<bool>(false);

  // 各リスト画面のStateにアクセスするためのGlobalKey
  final _testPieceListKey = GlobalKey<State<TestPieceListScreen>>();
  final _glazeListKey = GlobalKey<State<GlazeListScreen>>();
  final _materialsListKey = GlobalKey<State<MaterialsListScreen>>();

  // 釉薬インポート処理の状態
  bool _isImporting = false;

  // PageStorageKeyを管理するためのバケット
  final PageStorageBucket _bucket = PageStorageBucket();

  // 各タブに対応する画面ウィジェットのリスト
  // 今後タブを増減させる場合は、このリストと _bottomNavigationBarItems を修正します。
  // static const List<Widget> _widgetOptions = <Widget>[
  //   TestPieceListScreen(),
  //   GlazeListScreen(),
  //   MaterialsListScreen(),
  //   SettingsScreen(),
  // ];

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      TestPieceListScreen(
        key: _testPieceListKey,
        pageStorageKey: const PageStorageKey('testPieceList'),
      ),
      const SearchScreen(pageStorageKey: PageStorageKey('search')),
      GlazeListScreen(
        key: _glazeListKey,
        pageStorageKey: const PageStorageKey('glazeList'),
      ),
      MaterialsListScreen(
        key: _materialsListKey,
        isEditingNotifier: _isMaterialsEditingNotifier,
        pageStorageKey: const PageStorageKey('materialsList'),
      ),
      const SettingsScreen(pageStorageKey: PageStorageKey('settings')),
    ];
  }

  // 各タブのタイトル
  static const List<String> _appBarTitles = <String>[
    'テストピース一覧',
    '検索',
    '釉薬一覧',
    '原料一覧',
    '設定',
  ];

  // BottomNavigationBarItem のリスト
  static const List<BottomNavigationBarItem> _bottomNavigationBarItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.photo_library_outlined),
      activeIcon: Icon(Icons.photo_library),
      label: 'テストピース',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.search_outlined),
      activeIcon: Icon(Icons.search),
      label: '検索',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.color_lens_outlined),
      activeIcon: Icon(Icons.color_lens),
      label: '釉薬',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.science_outlined),
      activeIcon: Icon(Icons.science),
      label: '原料',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: '設定',
    ),
  ];

  void _onItemTapped(int index) {
    // 他のタブに移動したら、原料一覧の編集モードを自動的に解除する
    if (_selectedIndex == 3 && index != 3) {
      // 原料タブのインデックスが3に変わったため修正
      if (_isMaterialsEditingNotifier.value) {
        _isMaterialsEditingNotifier.value = false;
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _importGlazes() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final importer = GlazeImporter(
      firestoreService: context.read<FirestoreService>(),
    );

    await importer.importFromExcel(
      onStart: () => setState(() => _isImporting = true),
      onDone: () {
        if (mounted) setState(() => _isImporting = false);
      },
      onSuccess: (result) {
        String message = '${result.importedCount}件の釉薬をインポートしました。';
        if (result.skippedCount > 0) {
          message += '\n（${result.skippedCount}件は重複のためスキップ）';
        }
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));

        if (result.newlyAddedMaterials.isNotEmpty && mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('原料の自動登録'),
              content: Text(
                '以下の未登録原料を自動登録しました:\n\n${result.newlyAddedMaterials.join(', ')}\n\n必要であれば原料一覧画面から化学成分を登録してください。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      onError: (error) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('インポートに失敗しました: $error')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f5): const RefreshIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (RefreshIntent intent) => _handleRefresh(),
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_appBarTitles[_selectedIndex]),
            // 検索画面(index: 1)ではAppBarのactionsを非表示にする
            // 検索バーをボディに配置するため
            actions: [
              // 釉薬一覧画面(index: 2)でのみインポートボタンを表示
              if (_selectedIndex == 2)
                if (_isImporting)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: _importGlazes,
                    tooltip: 'ファイルからインポート',
                  ),

              // 原料一覧画面(index: 3)でのみ編集ボタンを表示
              if (_selectedIndex == 3)
                // isEditingNotifierの状態が変更されるたびにAppBarのボタンも再描画
                ValueListenableBuilder<bool>(
                  valueListenable: _isMaterialsEditingNotifier,
                  builder: (context, _, _) => Row(
                    children: MaterialsListScreen.buildActions(
                      context,
                      _isMaterialsEditingNotifier,
                    ),
                  ),
                ),

              // 設定画面(index: 4)でのみサインアウトボタンを表示
              if (_selectedIndex == 4)
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'サインアウト',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('サインアウト'),
                        content: const Text('本当にサインアウトしますか？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('サインアウト'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await context.read<AuthService>().signOut();
                    }
                  },
                ),
            ],
          ),
          body: PageStorage(
            bucket: _bucket,
            child: _widgetOptions[_selectedIndex],
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: _bottomNavigationBarItems,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed, // タブが4つ以上でもレイアウトを維持
          ),
        ),
      ),
    );
  }

  /// 現在表示中のタブのリストをリフレッシュする
  Future<void> _handleRefresh() async {
    // _widgetOptionsのStateに直接アクセスすることはできないため、
    // GlobalKey経由で公開されたメソッドを呼び出すなどの工夫が必要。
    // ここでは、各Stateクラスに `handleRefresh` メソッドがあると仮定する。
    switch (_selectedIndex) {
      case 0:
        (_testPieceListKey.currentState as TestPieceListScreenState)
            .handleRefresh();
        break;
      case 2:
        (_glazeListKey.currentState as GlazeListScreenState).handleRefresh();
        break;
      case 3:
        (_materialsListKey.currentState as MaterialsListScreenState)
            .handleRefresh();
        break;
      // 他のタブはリフレッシュ不要
    }
  }
}

// ショートカット用のインテント
class RefreshIntent extends Intent {
  const RefreshIntent();
}
