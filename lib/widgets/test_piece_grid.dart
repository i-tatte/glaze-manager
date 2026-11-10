import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';

/// 比較のためにテストピースを選ぶ状態。
///
/// グリッドに渡すと、カードの長押しで選択を切り替え、選択中はタップでも
/// 切り替える。選択がなければタップは従来通り詳細画面を開く。
class TestPieceSelection {
  /// 一度に比較できる最大枚数
  static const maxCount = 4;

  final Set<String> selectedIds;
  final ValueChanged<TestPiece> onToggle;

  const TestPieceSelection({required this.selectedIds, required this.onToggle});

  /// [id] の選択を切り替えた新しい集合を返す。
  /// 上限を超えるときは選択せず null を返す。
  static Set<String>? toggled(Set<String> current, String id) {
    if (current.contains(id)) return {...current}..remove(id);
    if (current.length >= maxCount) return null;
    return {...current, id};
  }

  /// 上限を超えて選ぼうとしたときの知らせ。
  static void showLimitMessage(ScaffoldMessengerState messenger) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('比較できるのは 4 枚までです')));
  }
}

class TestPieceGrid extends StatelessWidget {
  final List<TestPiece> testPieces;
  final Map<String, Glaze> glazeMap;
  final Map<String, Clay> clayMap;
  final Map<String, FiringAtmosphere> firingAtmosphereMap;
  final Map<String, FiringProfile> firingProfileMap;
  final Map<String, Firing> firingMap;
  final int crossAxisCount;
  final Future<void> Function()? onRefresh;
  final TestPieceSelection? selection;

  const TestPieceGrid({
    super.key,
    required this.testPieces,
    required this.glazeMap,
    required this.clayMap,
    required this.firingAtmosphereMap,
    required this.firingProfileMap,
    required this.firingMap,
    required this.crossAxisCount,
    this.onRefresh,
    this.selection,
  });

  /// 単一グリッドとグループ表示 (SectionedTestPieceGrid) で同一の見た目を
  /// 保証するための共有グリッドデレゲート。
  static SliverGridDelegateWithMaxCrossAxisExtent gridDelegateFor(
    double screenWidth,
    int crossAxisCount,
  ) {
    const padding = 8.0;
    const spacing = 8.0;
    // 画面の幅から、1アイテムあたりのおおよその幅を計算
    final maxCardWidth =
        (screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1))) /
        crossAxisCount;
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxCardWidth,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      // 画像を正方形にし、その下にテキストの高さを加える
      // テキスト部分のおおよその高さを80と仮定 (TestPieceCardの実装に依存、情報が増えたので高さを増やす)
      childAspectRatio: maxCardWidth / (maxCardWidth + 80),
    );
  }

  /// テストピース1件分のカードを、関連マスタを解決して生成する。
  static Widget buildCard(
    TestPiece testPiece, {
    required Map<String, Glaze> glazeMap,
    required Map<String, Clay> clayMap,
    required Map<String, FiringAtmosphere> firingAtmosphereMap,
    required Map<String, FiringProfile> firingProfileMap,
    required Map<String, Firing> firingMap,
    TestPieceSelection? selection,
  }) {
    final glazeName = glazeDisplayName(testPiece, glazeMap);
    final clayName = clayDisplayName(testPiece, clayMap);
    final resolved = resolveFiring(
      testPiece,
      firingMap: firingMap,
      atmosphereMap: firingAtmosphereMap,
      profileMap: firingProfileMap,
    );

    return TestPieceCard(
      testPiece: testPiece,
      glazeName: glazeName,
      clayName: clayName,
      firingAtmosphereName: resolved.atmosphereLabel,
      firingAtmosphereType: resolved.atmosphereType,
      firingProfileName: resolved.profileLabel,
      selected: selection?.selectedIds.contains(testPiece.id) ?? false,
      // 選択中のタップは選択の切り替え。そうでなければ詳細画面 (onTap == null)
      onTap: selection != null && selection.selectedIds.isNotEmpty
          ? () => selection.onToggle(testPiece)
          : null,
      onLongPress: selection == null
          ? null
          : () => selection.onToggle(testPiece),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final grid = GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: gridDelegateFor(screenWidth, crossAxisCount),
      itemCount: testPieces.length,
      itemBuilder: (context, index) => buildCard(
        testPieces[index],
        glazeMap: glazeMap,
        clayMap: clayMap,
        firingAtmosphereMap: firingAtmosphereMap,
        firingProfileMap: firingProfileMap,
        firingMap: firingMap,
        selection: selection,
      ),
    );

    return onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: grid)
        : grid;
  }
}
