import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/screens/glaze_list_screen.dart';
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/screens/settings_screen.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:glaze_manager/screens/test_piece_list_screen.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

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

  // 釉薬インポート処理の状態
  bool _isImporting = false;

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
      const TestPieceListScreen(),
      const SearchScreen(),
      const GlazeListScreen(),
      MaterialsListScreen(isEditingNotifier: _isMaterialsEditingNotifier),
      const SettingsScreen(),
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
    setState(() => _isImporting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. ファイルを選択
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'], // xlsxのみサポート
    );

    if (result == null || result.files.single.path == null) {
      setState(() => _isImporting = false);
      return;
    }

    try {
      final firestoreService = context.read<FirestoreService>();
      final bytes = await File(result.files.single.path!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.keys.isEmpty) {
        throw Exception('ファイルにシートが含まれていません。');
      }

      final sheet = excel.tables[excel.tables.keys.first]!;
      if (sheet.maxRows < 2) {
        throw Exception('ファイルにデータが含まれていません。');
      }

      // 2. ヘッダーから原料リストを抽出し、未登録なら自動作成
      final headerRow = sheet.row(0);
      final materialNames = headerRow
          .skip(1) // 1列目は無視
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final newlyAddedMaterials = await firestoreService.findOrCreateMaterials(
        materialNames,
      );

      // 3. 全原料データを取得し、名前とIDのマップを作成
      final allMaterials = await firestoreService.getMaterials().first;
      final materialIdMap = {for (var mat in allMaterials) mat.name: mat.id!};

      // 4. 釉薬データを作成
      final List<Glaze> importedGlazes = [];
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty || row.first == null) continue;

        final glazeName = row.first!.value.toString().trim();
        if (glazeName.isEmpty) continue;

        final recipe = <String, double>{};
        for (int j = 1; j < row.length && j - 1 < materialNames.length; j++) {
          final materialName = materialNames[j - 1];
          final materialId = materialIdMap[materialName];
          if (materialId == null) continue;

          final cell = row[j];
          final amount = (cell?.value != null)
              ? double.tryParse(cell!.value.toString())
              : null;

          if (amount != null && amount > 0) {
            recipe[materialId] = amount;
          }
        }

        if (recipe.isNotEmpty) {
          importedGlazes.add(
            Glaze(
              name: glazeName,
              recipe: recipe,
              tags: ['インポート'], // インポートされたことがわかるようにタグ付け
            ),
          );
        }
      }

      if (importedGlazes.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('インポートするデータが見つかりませんでした。')),
        );
        setState(() => _isImporting = false);
        return;
      }

      // 5. 釉薬を一括登録
      await firestoreService.addGlazesBatch(importedGlazes);

      // 6. 結果を通知
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('${importedGlazes.length}件の釉薬をインポートしました。')),
      );

      if (newlyAddedMaterials.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('原料の自動登録'),
            content: Text(
              '以下の未登録原料を自動登録しました:\n\n${newlyAddedMaterials.join(', ')}\n\n必要であれば原料一覧画面から化学成分を登録してください。',
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
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('インポートに失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              builder: (context, _, __) => Row(
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
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: _bottomNavigationBarItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // タブが4つ以上でもレイアウトを維持
      ),
    );
  }
}
