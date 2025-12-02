import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';
import 'package:provider/provider.dart';
import 'package:glaze_manager/widgets/common/empty_list_placeholder.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';

class TestPieceListScreen extends StatefulWidget {
  final PageStorageKey? pageStorageKey;
  const TestPieceListScreen({super.key, this.pageStorageKey});

  @override
  State<TestPieceListScreen> createState() => TestPieceListScreenState();
}

class TestPieceListScreenState extends State<TestPieceListScreen> {
  late Stream<List<Glaze>> _glazesStream;
  late Stream<List<TestPiece>> _testPiecesStream;
  late Stream<List<Clay>> _claysStream;
  late Stream<List<FiringAtmosphere>> _firingAtmospheresStream;
  late Stream<List<FiringProfile>> _firingProfilesStream;

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  void _loadStreams() {
    final firestoreService = context.read<FirestoreService>();
    _glazesStream = firestoreService.getGlazes();
    _testPiecesStream = firestoreService.getTestPieces();
    _claysStream = firestoreService.getClays();
    _firingAtmospheresStream = firestoreService.getFiringAtmospheres();
    _firingProfilesStream = firestoreService.getFiringProfiles();
  }

  Future<void> handleRefresh() async {
    setState(() {
      _loadStreams();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 全釉薬データ
          StreamBuilder<List<Glaze>>(
            stream: _glazesStream,
            builder: (context, glazeSnapshot) {
              if (glazeSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (glazeSnapshot.hasError) {
                return Center(
                  child: Text('釉薬データの読込エラー: ${glazeSnapshot.error}'),
                );
              }
              final Map<String, Glaze> glazeMap = {
                for (var glaze in glazeSnapshot.data ?? []) glaze.id: glaze,
              };

              // 2. 全素地土データ
              return StreamBuilder<List<Clay>>(
                stream: _claysStream,
                builder: (context, claySnapshot) {
                  if (claySnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (claySnapshot.hasError) {
                    return Center(
                      child: Text('素地土データの読込エラー: ${claySnapshot.error}'),
                    );
                  }
                  final Map<String, Clay> clayMap = {
                    for (var clay in claySnapshot.data ?? []) clay.id: clay,
                  };

                  // 3. 全焼成雰囲気データ
                  return StreamBuilder<List<FiringAtmosphere>>(
                    stream: _firingAtmospheresStream,
                    builder: (context, atmosphereSnapshot) {
                      if (atmosphereSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      if (atmosphereSnapshot.hasError) {
                        return Center(
                          child: Text(
                            '焼成雰囲気データの読込エラー: ${atmosphereSnapshot.error}',
                          ),
                        );
                      }
                      final Map<String, FiringAtmosphere> atmosphereMap = {
                        for (var item in atmosphereSnapshot.data ?? [])
                          item.id: item,
                      };

                      // 4. 全焼成プロファイルデータ
                      return StreamBuilder<List<FiringProfile>>(
                        stream: _firingProfilesStream,
                        builder: (context, profileSnapshot) {
                          if (profileSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }
                          if (profileSnapshot.hasError) {
                            return Center(
                              child: Text(
                                '焼成プロファイルデータの読込エラー: ${profileSnapshot.error}',
                              ),
                            );
                          }
                          final Map<String, FiringProfile> profileMap = {
                            for (var item in profileSnapshot.data ?? [])
                              item.id: item,
                          };

                          // Consumerを使ってSettingsServiceの変更を監視
                          return Consumer<SettingsService>(
                            builder: (context, settingsService, child) {
                              // 5. テストピース一覧
                              return StreamBuilder<List<TestPiece>>(
                                stream: _testPiecesStream,
                                builder: (context, testPieceSnapshot) {
                                  if (testPieceSnapshot.connectionState ==
                                      ConnectionState.waiting) {
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
                                    return const EmptyListPlaceholder(
                                      message:
                                          'テストピースが登録されていません。\n右下のボタンから追加してください。',
                                    );
                                  }

                                  final testPieces = testPieceSnapshot.data!;

                                  return TestPieceGrid(
                                    testPieces: testPieces,
                                    glazeMap: glazeMap,
                                    clayMap: clayMap,
                                    firingAtmosphereMap: atmosphereMap,
                                    firingProfileMap: profileMap,
                                    crossAxisCount:
                                        settingsService.gridCrossAxisCount,
                                    onRefresh: handleRefresh,
                                  );
                                },
                              );
                            },
                          );
                        },
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
