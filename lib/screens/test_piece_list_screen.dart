import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:provider/provider.dart';

class TestPieceListScreen extends StatefulWidget {
  const TestPieceListScreen({super.key});

  @override
  State<TestPieceListScreen> createState() => _TestPieceListScreenState();
}

class _TestPieceListScreenState extends State<TestPieceListScreen> {
  late Stream<List<Glaze>> _glazesStream;
  late Stream<List<TestPiece>> _testPiecesStream;

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  void _loadStreams() {
    final firestoreService = context.read<FirestoreService>();
    _glazesStream = firestoreService.getGlazes();
    _testPiecesStream = firestoreService.getTestPieces();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _loadStreams();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.f5): const RefreshIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            RefreshIntent: CallbackAction<RefreshIntent>(
              onInvoke: (RefreshIntent intent) => _handleRefresh(),
            ),
          },
          child: Stack(
            children: [
              // 1. 最初に全釉薬データを取得してマップ化する
              StreamBuilder<List<Glaze>>(
                stream: _glazesStream,
                builder: (context, glazeSnapshot) {
                  if (glazeSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (glazeSnapshot.hasError) {
                    return Center(
                      child: Text('釉薬データの読込エラー: ${glazeSnapshot.error}'),
                    );
                  }

                  // glazeIdをキー、Glazeオブジェクトを値とするマップを作成
                  final glazeMap = {
                    for (var glaze in glazeSnapshot.data ?? []) glaze.id: glaze,
                  };

                  // Consumerを使ってSettingsServiceの変更を監視し、GridViewだけを再描画する
                  return Consumer<SettingsService>(
                    builder: (context, settingsService, child) {
                      // 2. テストピース一覧を取得してグリッド表示する
                      return StreamBuilder<List<TestPiece>>(
                        stream: _testPiecesStream,
                        builder: (context, testPieceSnapshot) {
                          if (testPieceSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            // 釉薬データ取得中にインジケータを表示しているので、ここでは何も表示しないか、
                            // より小さなインジケータを表示しても良い
                            return const SizedBox.shrink();
                          }
                          if (testPieceSnapshot.hasError) {
                            return Center(
                              child: Text(
                                'テストピースの読込エラー: ${testPieceSnapshot.error}',
                              ),
                            );
                          }
                          if (!testPieceSnapshot.hasData ||
                              testPieceSnapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                'テストピースが登録されていません。\n右下のボタンから追加してください。',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          final testPieces = testPieceSnapshot.data!;

                          // 画面の幅から、1アイテムあたりのおおよその幅を計算
                          final screenWidth = MediaQuery.of(context).size.width;
                          final crossAxisCount =
                              settingsService.gridCrossAxisCount;
                          const padding = 8.0;
                          const spacing = 8.0;
                          final maxCardWidth =
                              (screenWidth -
                                  (padding * 2) -
                                  (spacing * (crossAxisCount - 1))) /
                              crossAxisCount;

                          return RefreshIndicator(
                            onRefresh: _handleRefresh,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(padding),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent:
                                        maxCardWidth, // 各アイテムの最大幅
                                    mainAxisSpacing: spacing, // アイテム間の垂直方向のスペース
                                    crossAxisSpacing:
                                        spacing, // アイテム間の水平方向のスペース
                                    // 画像を正方形にし、その下にテキストの高さを加える
                                    // テキスト部分のおおよその高さを60と仮定
                                    childAspectRatio:
                                        maxCardWidth / (maxCardWidth + 60),
                                  ),
                              itemCount: testPieces.length,
                              itemBuilder: (context, index) {
                                final testPiece = testPieces[index];
                                // マップから釉薬名を取得（見つからなければ '不明な釉薬' とする）
                                final glazeName =
                                    glazeMap[testPiece.glazeId]?.name ??
                                    '不明な釉薬';
                                return TestPieceCard(
                                  glazeName: glazeName,
                                  testPiece: testPiece,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              Positioned(
                bottom: 16.0,
                right: 16.0,
                child: FloatingActionButton(
                  heroTag: 'testPieceListFab', // ユニークなタグを追加
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
        ),
      ),
    );
  }
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}
