import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glaze_manager/screens/glaze_list_screen.dart';
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/screens/settings_screen.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:glaze_manager/screens/test_piece_list_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/services/glaze_import_service.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:provider/provider.dart' show ReadContext;

/// タブの識別子。位置 (インデックス) ではなくこの値で分岐することで、
/// タブの追加・並び替えに強くする。
enum _MainTab { testPieces, search, glazes, materials, settings }

/// 1タブ分の定義。タブの増減・並び替えは [_MainTabScreenState._tabs] の
/// リストを編集するだけで完結する。
class _TabDefinition {
  final _MainTab tab;
  final String title;
  final BottomNavigationBarItem navItem;
  final Widget screen;

  const _TabDefinition({
    required this.tab,
    required this.title,
    required this.navItem,
    required this.screen,
  });
}

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _selectedIndex = 0;
  late final List<_TabDefinition> _tabs;

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

  _MainTab get _selectedTab => _tabs[_selectedIndex].tab;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _TabDefinition(
        tab: _MainTab.testPieces,
        title: 'テストピース一覧',
        navItem: const BottomNavigationBarItem(
          icon: Icon(Icons.photo_library_outlined),
          activeIcon: Icon(Icons.photo_library),
          label: 'テストピース',
        ),
        screen: TestPieceListScreen(
          key: _testPieceListKey,
          pageStorageKey: const PageStorageKey('testPieceList'),
        ),
      ),
      const _TabDefinition(
        tab: _MainTab.search,
        title: '検索',
        navItem: BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: '検索',
        ),
        screen: SearchScreen(pageStorageKey: PageStorageKey('search')),
      ),
      _TabDefinition(
        tab: _MainTab.glazes,
        title: '釉薬一覧',
        navItem: const BottomNavigationBarItem(
          icon: Icon(Icons.color_lens_outlined),
          activeIcon: Icon(Icons.color_lens),
          label: '釉薬',
        ),
        screen: GlazeListScreen(
          key: _glazeListKey,
          pageStorageKey: const PageStorageKey('glazeList'),
        ),
      ),
      _TabDefinition(
        tab: _MainTab.materials,
        title: '原料一覧',
        navItem: const BottomNavigationBarItem(
          icon: Icon(Icons.science_outlined),
          activeIcon: Icon(Icons.science),
          label: '原料',
        ),
        screen: MaterialsListScreen(
          key: _materialsListKey,
          isEditingNotifier: _isMaterialsEditingNotifier,
          pageStorageKey: const PageStorageKey('materialsList'),
        ),
      ),
      const _TabDefinition(
        tab: _MainTab.settings,
        title: '設定',
        navItem: BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: '設定',
        ),
        screen: SettingsScreen(pageStorageKey: PageStorageKey('settings')),
      ),
    ];
  }

  void _onItemTapped(int index) {
    // 原料タブから離れたら、編集モードを自動的に解除する
    if (_selectedTab == _MainTab.materials &&
        _tabs[index].tab != _MainTab.materials) {
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
      firestoreService: ref.read(firestoreServiceProvider),
    );

    setState(() => _isImporting = true);
    try {
      // 1. ファイル選択 → パース (この時点では何も書き込まれない)
      final preview = await importer.pickAndParse();
      if (preview == null) return; // ファイル選択キャンセル
      if (!mounted) return;

      // 2. 取り込み内容のプレビューを表示して確認を取る
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('インポート内容の確認'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('インポートする釉薬: ${preview.importCount}件'),
                if (preview.rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      preview.rows.map((r) => r.name).take(10).join(', ') +
                          (preview.importCount > 10 ? ' …' : ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (preview.skippedGlazes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('スキップ (名前が重複): ${preview.skippedGlazes.length}件'),
                  Text(
                    preview.skippedGlazes.take(10).join(', ') +
                        (preview.skippedGlazes.length > 10 ? ' …' : ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (preview.newMaterialNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('新規作成される原料: ${preview.newMaterialNames.length}件'),
                  Text(
                    preview.newMaterialNames.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (preview.newPigmentNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('新規作成される顔料: ${preview.newPigmentNames.length}件'),
                  Text(
                    preview.newPigmentNames.join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('インポート実行'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      // 3. 確定 (Firestoreへ書き込み)
      final result = await importer.commit(preview);

      String message = '${result.importedCount}件の釉薬をインポートしました。';
      if (result.skippedCount > 0) {
        message += '\n（${result.skippedCount}件は重複のためスキップ）';
      }
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));

      if (result.newlyAddedMaterials.isNotEmpty && mounted) {
        await showDialog(
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
    } on FormatException catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('インポートに失敗しました: ${e.message}')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('インポートに失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 選択中のタブに応じたAppBarアクションを返す
  List<Widget> _buildAppBarActions() {
    switch (_selectedTab) {
      case _MainTab.glazes:
        return [
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
        ];
      case _MainTab.materials:
        return [
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
        ];
      case _MainTab.settings:
        return [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'サインアウト',
            onPressed: _confirmSignOut,
          ),
        ];
      case _MainTab.testPieces:
      case _MainTab.search:
        return const [];
    }
  }

  Future<void> _confirmSignOut() async {
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
    if (confirmed == true && mounted) {
      await context.read<AuthService>().signOut();
    }
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
            title: Text(_tabs[_selectedIndex].title),
            actions: _buildAppBarActions(),
          ),
          body: PageStorage(
            bucket: _bucket,
            child: _tabs[_selectedIndex].screen,
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: _tabs.map((t) => t.navItem).toList(),
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed, // タブが4つ以上でもレイアウトを維持
          ),
        ),
      ),
    );
  }

  /// 現在表示中のタブのリストをリフレッシュする (F5)
  Future<void> _handleRefresh() async {
    switch (_selectedTab) {
      case _MainTab.testPieces:
        (_testPieceListKey.currentState as TestPieceListScreenState?)
            ?.handleRefresh();
        break;
      case _MainTab.glazes:
        (_glazeListKey.currentState as GlazeListScreenState?)?.handleRefresh();
        break;
      case _MainTab.materials:
        (_materialsListKey.currentState as MaterialsListScreenState?)
            ?.handleRefresh();
        break;
      case _MainTab.search:
      case _MainTab.settings:
        // リフレッシュ不要
        break;
    }
  }
}

// ショートカット用のインテント
class RefreshIntent extends Intent {
  const RefreshIntent();
}
