import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';

class TestPieceGrid extends StatelessWidget {
  final List<TestPiece> testPieces;
  final Map<String, Glaze> glazeMap;
  final Map<String, Clay> clayMap;
  final Map<String, FiringAtmosphere> firingAtmosphereMap;
  final Map<String, FiringProfile> firingProfileMap;
  final int crossAxisCount;
  final Future<void> Function()? onRefresh;

  const TestPieceGrid({
    super.key,
    required this.testPieces,
    required this.glazeMap,
    required this.clayMap,
    required this.firingAtmosphereMap,
    required this.firingProfileMap,
    required this.crossAxisCount,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // 画面の幅から、1アイテムあたりのおおよその幅を計算
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 8.0;
    const spacing = 8.0;
    final maxCardWidth =
        (screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1))) /
        crossAxisCount;

    final grid = GridView.builder(
      padding: const EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCardWidth,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        // 画像を正方形にし、その下にテキストの高さを加える
        // テキスト部分のおおよその高さを80と仮定 (TestPieceCardの実装に依存、情報が増えたので高さを増やす)
        childAspectRatio: maxCardWidth / (maxCardWidth + 80),
      ),
      itemCount: testPieces.length,
      itemBuilder: (context, index) {
        final testPiece = testPieces[index];
        final glazeName = glazeMap[testPiece.glazeId]?.name ?? '不明な釉薬';
        final clayName = clayMap[testPiece.clayId]?.name ?? '不明な素地';
        final firingAtmosphere =
            firingAtmosphereMap[testPiece.firingAtmosphereId];
        final firingAtmosphereName = firingAtmosphere?.name ?? '不明な雰囲気';
        final firingAtmosphereType =
            firingAtmosphere?.type ?? FiringAtmosphereType.other;
        final firingProfileName =
            firingProfileMap[testPiece.firingProfileId]?.name ?? '不明なプロファイル';

        return TestPieceCard(
          testPiece: testPiece,
          glazeName: glazeName,
          clayName: clayName,
          firingAtmosphereName: firingAtmosphereName,
          firingAtmosphereType: firingAtmosphereType,
          firingProfileName: firingProfileName,
        );
      },
    );

    return onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: grid)
        : grid;
  }
}
