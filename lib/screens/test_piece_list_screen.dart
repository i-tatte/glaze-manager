import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/test_piece_group_key.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/firing_list_screen.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/utils/test_piece_grouping.dart';
import 'package:glaze_manager/widgets/sectioned_test_piece_grid.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';
import 'package:glaze_manager/widgets/common/empty_list_placeholder.dart';

class TestPieceListScreen extends ConsumerStatefulWidget {
  final PageStorageKey? pageStorageKey;

  /// 比較のために選んだテストピースの ID。AppBar を持つ MainTabScreen と共有する。
  /// null なら選択機能は無効。
  final ValueNotifier<Set<String>>? selectionNotifier;

  const TestPieceListScreen({
    super.key,
    this.pageStorageKey,
    this.selectionNotifier,
  });

  // AppBarに表示するグループ表示切替ボタンを生成する静的メソッド
  // MainTabScreenから呼び出される (MaterialsListScreen.buildActions と同じ流儀)
  static Widget buildGroupKeySelector(WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final current = settings.testPieceGroupKey;
    return PopupMenuButton<TestPieceGroupKey>(
      icon: const Icon(Icons.workspaces_outlined),
      tooltip: 'グループ表示',
      onSelected: settings.setTestPieceGroupKey,
      itemBuilder: (context) => [
        for (final key in TestPieceGroupKey.values)
          CheckedPopupMenuItem(
            value: key,
            checked: key == current,
            child: Text(key.label),
          ),
      ],
    );
  }

  // AppBarに表示する焼成回の一覧を開くボタン (グループ表示切替と同じ流儀)
  static Widget buildFiringListButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.local_fire_department_outlined),
      tooltip: '焼成回',
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const FiringListScreen())),
    );
  }

  @override
  ConsumerState<TestPieceListScreen> createState() =>
      TestPieceListScreenState();
}

class TestPieceListScreenState extends ConsumerState<TestPieceListScreen> {
  @override
  void initState() {
    super.initState();
    widget.selectionNotifier?.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(TestPieceListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionNotifier != widget.selectionNotifier) {
      oldWidget.selectionNotifier?.removeListener(_onSelectionChanged);
      widget.selectionNotifier?.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.selectionNotifier?.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSelection(TestPiece testPiece) {
    final notifier = widget.selectionNotifier;
    final id = testPiece.id;
    if (notifier == null || id == null) return;
    final next = TestPieceSelection.toggled(notifier.value, id);
    if (next == null) {
      TestPieceSelection.showLimitMessage(ScaffoldMessenger.of(context));
      return;
    }
    notifier.value = next;
  }

  /// 表示中データの再購読 (F5 / プルリフレッシュから呼ばれる)
  Future<void> handleRefresh() async {
    ref.invalidate(testPiecesProvider);
    ref.invalidate(glazesProvider);
    ref.invalidate(claysProvider);
    ref.invalidate(firingAtmospheresProvider);
    ref.invalidate(firingProfilesProvider);
    ref.invalidate(firingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final testPiecesAsync = ref.watch(testPiecesProvider);
    final glazeMap = ref.watch(glazeMapProvider);
    final clayMap = ref.watch(clayMapProvider);
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);
    final profileMap = ref.watch(firingProfileMapProvider);
    final firingMap = ref.watch(firingMapProvider);
    final settings = ref.watch(settingsServiceProvider);
    final crossAxisCount = settings.gridCrossAxisCount;
    final groupKey = settings.testPieceGroupKey;
    final selectionNotifier = widget.selectionNotifier;
    final selection = selectionNotifier == null
        ? null
        : TestPieceSelection(
            selectedIds: selectionNotifier.value,
            onToggle: _toggleSelection,
          );

    return Scaffold(
      body: Stack(
        children: [
          testPiecesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('テストピースの読込エラー: $error')),
            data: (testPieces) {
              if (testPieces.isEmpty) {
                return const EmptyListPlaceholder(
                  message: 'テストピースが登録されていません。\n右下のボタンから追加してください。',
                );
              }
              if (groupKey == TestPieceGroupKey.none) {
                return TestPieceGrid(
                  testPieces: testPieces,
                  glazeMap: glazeMap,
                  clayMap: clayMap,
                  firingAtmosphereMap: atmosphereMap,
                  firingProfileMap: profileMap,
                  firingMap: firingMap,
                  crossAxisCount: crossAxisCount,
                  onRefresh: handleRefresh,
                  selection: selection,
                );
              }
              // グループ化は高々数百件のO(n)処理なので build 内の同期呼び出しで足りる
              final groups = groupTestPieces(
                pieces: testPieces,
                key: groupKey,
                clayMap: clayMap,
                atmosphereMap: atmosphereMap,
                profileMap: profileMap,
                firingMap: firingMap,
              );
              return SectionedTestPieceGrid(
                groups: groups,
                glazeMap: glazeMap,
                clayMap: clayMap,
                firingAtmosphereMap: atmosphereMap,
                firingProfileMap: profileMap,
                firingMap: firingMap,
                crossAxisCount: crossAxisCount,
                onRefresh: handleRefresh,
                selection: selection,
              );
            },
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'testPieceListFab',
              tooltip: 'テストピースを追加',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TestPieceEditScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
