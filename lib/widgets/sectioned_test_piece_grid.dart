import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/screens/firing_detail_screen.dart';
import 'package:glaze_manager/utils/test_piece_grouping.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';

/// グループごとにセクションヘッダ付きでテストピースを表示するグリッド。
///
/// shrinkWrap した GridView の縦積みではなく CustomScrollView + SliverGrid を
/// 使うことで、画面外のセクションもアイテム単位で遅延ビルドされる
/// (縦積みだと全アイテムが即レイアウトされ、サムネイル取得が一斉に走る)。
class SectionedTestPieceGrid extends StatelessWidget {
  final List<TestPieceGroup> groups;
  final Map<String, Glaze> glazeMap;
  final Map<String, Clay> clayMap;
  final Map<String, FiringAtmosphere> firingAtmosphereMap;
  final Map<String, FiringProfile> firingProfileMap;
  final Map<String, Firing> firingMap;
  final int crossAxisCount;
  final Future<void> Function()? onRefresh;
  final TestPieceSelection? selection;

  const SectionedTestPieceGrid({
    super.key,
    required this.groups,
    required this.glazeMap,
    required this.clayMap,
    required this.firingAtmosphereMap,
    required this.firingProfileMap,
    required this.firingMap,
    required this.crossAxisCount,
    this.onRefresh,
    this.selection,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 単一グリッド (TestPieceGrid) と同じデレゲートを使い、見た目を揃える
    final gridDelegate = TestPieceGrid.gridDelegateFor(
      screenWidth,
      crossAxisCount,
    );

    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, group)),
              SliverPadding(
                padding: const EdgeInsets.all(8.0),
                sliver: SliverGrid.builder(
                  gridDelegate: gridDelegate,
                  itemCount: group.pieces.length,
                  itemBuilder: (context, index) => TestPieceGrid.buildCard(
                    group.pieces[index],
                    glazeMap: glazeMap,
                    clayMap: clayMap,
                    firingAtmosphereMap: firingAtmosphereMap,
                    firingProfileMap: firingProfileMap,
                    firingMap: firingMap,
                    selection: selection,
                  ),
                ),
              ),
            ],
          ),
        // 最終行がFABに隠れないための余白
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );

    return onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: scrollView)
        : scrollView;
  }

  /// セクションの見出し。焼成回のグループではタップで焼成回の詳細を開く。
  Widget _buildHeader(BuildContext context, TestPieceGroup group) {
    final text = Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 16.0, 12.0, 0),
      child: Text(
        '${group.label} (${group.pieces.length})',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
    final firingId = group.firingId;
    if (firingId == null) return text;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FiringDetailScreen(firingId: firingId),
        ),
      ),
      child: text,
    );
  }
}
