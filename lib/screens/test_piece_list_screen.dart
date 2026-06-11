import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';
import 'package:glaze_manager/widgets/common/empty_list_placeholder.dart';
import 'package:provider/provider.dart' show WatchContext;

class TestPieceListScreen extends ConsumerStatefulWidget {
  final PageStorageKey? pageStorageKey;
  const TestPieceListScreen({super.key, this.pageStorageKey});

  @override
  ConsumerState<TestPieceListScreen> createState() =>
      TestPieceListScreenState();
}

class TestPieceListScreenState extends ConsumerState<TestPieceListScreen> {
  /// 表示中データの再購読 (F5 / プルリフレッシュから呼ばれる)
  Future<void> handleRefresh() async {
    ref.invalidate(testPiecesProvider);
    ref.invalidate(glazesProvider);
    ref.invalidate(claysProvider);
    ref.invalidate(firingAtmospheresProvider);
    ref.invalidate(firingProfilesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final testPiecesAsync = ref.watch(testPiecesProvider);
    final glazeMap = ref.watch(glazeMapProvider);
    final clayMap = ref.watch(clayMapProvider);
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);
    final profileMap = ref.watch(firingProfileMapProvider);
    final crossAxisCount = context.watch<SettingsService>().gridCrossAxisCount;

    return Scaffold(
      body: Stack(
        children: [
          testPiecesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('テストピースの読込エラー: $error')),
            data: (testPieces) {
              if (testPieces.isEmpty) {
                return const EmptyListPlaceholder(
                  message: 'テストピースが登録されていません。\n右下のボタンから追加してください。',
                );
              }
              return TestPieceGrid(
                testPieces: testPieces,
                glazeMap: glazeMap,
                clayMap: clayMap,
                firingAtmosphereMap: atmosphereMap,
                firingProfileMap: profileMap,
                crossAxisCount: crossAxisCount,
                onRefresh: handleRefresh,
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
