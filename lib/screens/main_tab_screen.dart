import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final materialNamesInHeader = headerRow
          .skip(2) // 1, 2列目は無視
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .where((name) => name.isNotEmpty && name != '顔料' && name != '備考')
          .toList();

      final newlyAddedMaterials = await firestoreService.findOrCreateMaterials(
        materialNamesInHeader,
      );
      List<String> newlyAddedPigments = [];

      // 3. 既存の釉薬名リストと、全原料の名前->IDマップを作成
      final existingGlazes = await firestoreService.getGlazes().first;
      final existingGlazeNames = existingGlazes.map((g) => g.name).toSet();
      final allMaterials = await firestoreService.getMaterials().first;
      final materialIdMap = {for (var mat in allMaterials) mat.name: mat.id!};

      // 4. 釉薬データを作成
      final List<Glaze> importedGlazes = [];
      final List<String> skippedGlazes = [];

      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty || row.first == null) continue;

        final glazeName = row.first!.value.toString().trim();
        if (glazeName.isEmpty || glazeName == 'null') continue;

        // 釉薬名の重複チェック
        if (existingGlazeNames.contains(glazeName)) {
          skippedGlazes.add(glazeName);
          continue;
        }

        // エイリアスと備考の取得
        final alias = row.length > 1 && row[1] != null
            ? row[1]!.value.toString().trim()
            : '';
        final note =
            row.length > headerRow.length - 1 &&
                row[headerRow.length - 1] != null
            ? row[headerRow.length - 1]!.value.toString().trim()
            : '';
        final description = [
          alias,
          note,
        ].where((s) => s.isNotEmpty && s != 'null').join('\n');

        // レシピの作成
        final recipe = <String, double>{};
        // 3列目から顔料列の2つ手前までを原料として処理
        for (int j = 2; j < headerRow.length - 3; j++) {
          if (j >= headerRow.length) continue;
          final materialName = headerRow[j]?.value.toString().trim() ?? '';
          final materialId = materialIdMap[materialName];
          if (materialId == null) continue;

          final amount = row.length > j
              ? double.tryParse(row[j]?.value.toString() ?? '')
              : null;

          if (amount != null && amount > 0) {
            recipe[materialId] = amount;
          }
        }

        // 顔料列の処理 (最後から2つ前の列)
        final pigmentCellIndex = headerRow.length - 3;
        if (row.length > pigmentCellIndex && row[pigmentCellIndex] != null) {
          final pigmentData = row[pigmentCellIndex]!.value.toString().trim();
          final pigmentEntries = pigmentData
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);

          for (final entry in pigmentEntries) {
            final re = RegExp(r'^(.*?)([\d.]+)$');
            final match = re.firstMatch(entry);

            if (match != null) {
              final pigmentName = match.group(1)!.trim();
              final amount = double.tryParse(match.group(2)!);

              if (pigmentName.isNotEmpty && amount != null && amount > 0) {
                var pigmentId = await firestoreService.findOrCreatePigmentID(
                  pigmentName,
                );
                recipe[pigmentId] = amount;
                newlyAddedPigments.add(pigmentName);
              }
            }
          }
        }

        if (recipe.isNotEmpty) {
          importedGlazes.add(
            Glaze(
              name: glazeName,
              recipe: recipe,
              tags: ['インポート'], // インポートされたことがわかるようにタグ付け
              description: description.isNotEmpty ? description : null,
              createdAt: Timestamp.now(),
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

      // 7. 釉薬を一括登録
      await firestoreService.addGlazesBatch(importedGlazes);

      // 8. 結果を通知
      String message = '${importedGlazes.length}件の釉薬をインポートしました。';
      if (skippedGlazes.isNotEmpty) {
        message += '\n（${skippedGlazes.length}件は重複のためスキップ）';
      }
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));

      final allNewMaterials = <String>{
        ...newlyAddedMaterials,
        ...newlyAddedPigments,
      }.toList();

      if (allNewMaterials.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('原料の自動登録'),
            content: Text(
              '以下の未登録原料を自動登録しました:\n\n${allNewMaterials.join(', ')}\n\n必要であれば原料一覧画面から化学成分を登録してください。',
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
