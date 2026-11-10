import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef, AsyncValueX;
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/firing_edit_screen.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/utils/date_format.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';

/// 焼成回の詳細。焼成の情報と、この焼成回のテストピースを並べる。
class FiringDetailScreen extends ConsumerWidget {
  final String firingId;

  const FiringDetailScreen({super.key, required this.firingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firingsAsync = ref.watch(firingsProvider);
    final firing = ref.watch(firingMapProvider)[firingId];

    if (firing == null) {
      if (firingsAsync.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('焼成回が見つかりません。')),
      );
    }

    final testPieces = (ref.watch(testPiecesProvider).valueOrNull ?? [])
        .where((tp) => tp.firingId == firingId)
        .toList();
    final awaiting = testPieces.where(isAwaitingPhoto).toList();
    final glazeMap = ref.watch(glazeMapProvider);
    final clayMap = ref.watch(clayMapProvider);
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);
    final profileMap = ref.watch(firingProfileMapProvider);
    final firingMap = ref.watch(firingMapProvider);
    final crossAxisCount = ref
        .watch(settingsServiceProvider)
        .gridCrossAxisCount;
    final screenWidth = MediaQuery.of(context).size.width;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text(firing.displayLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FiringEditScreen(firing: firing),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'firingDetailFab',
        tooltip: 'テストピースを追加',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                TestPieceEditScreen(initialFiringId: firing.id),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildInfo(firing, atmosphereMap),
                  ..._buildProfile(context, firing, profileMap),
                ],
              ),
            ),
          ),
          if (awaiting.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                child: Text('写真待ち (${awaiting.length})', style: titleStyle),
              ),
            ),
            SliverList.builder(
              itemCount: awaiting.length,
              itemBuilder: (context, index) => _buildAwaitingTile(
                context,
                awaiting[index],
                glazeMap,
                clayMap,
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
              child: Text('テストピース (${testPieces.length})', style: titleStyle),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: SliverGrid.builder(
              gridDelegate: TestPieceGrid.gridDelegateFor(
                screenWidth,
                crossAxisCount,
              ),
              itemCount: testPieces.length,
              itemBuilder: (context, index) => TestPieceGrid.buildCard(
                testPieces[index],
                glazeMap: glazeMap,
                clayMap: clayMap,
                firingAtmosphereMap: atmosphereMap,
                firingProfileMap: profileMap,
                firingMap: firingMap,
              ),
            ),
          ),
          // 最終行が FAB に隠れないための余白
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// 焼成の情報。値のない項目は出さない。
  List<Widget> _buildInfo(
    Firing firing,
    Map<String, FiringAtmosphere> atmosphereMap,
  ) {
    final atmosphereName =
        atmosphereMap[firing.firingAtmosphereId]?.name ?? firing.atmosphereName;
    return [
      InfoTile(label: '焼成日', value: formatDate(firing.firedOn.toDate())),
      if (firing.kilnName != null)
        InfoTile(label: '窯', value: firing.kilnName!),
      if (atmosphereName != null)
        InfoTile(label: '焼成雰囲気', value: atmosphereName),
      if (firing.peakTemp != null)
        InfoTile(label: '最高温度', value: '${firing.peakTemp} ℃'),
      if (firing.cone != null) InfoTile(label: 'コーン', value: firing.cone!),
      if (firing.note != null) InfoTile(label: '所感', value: firing.note!),
    ];
  }

  /// 焼成プロファイルの名前とチャート (焼成回の写しから描く)。
  List<Widget> _buildProfile(
    BuildContext context,
    Firing firing,
    Map<String, FiringProfile> profileMap,
  ) {
    final snapshot = firing.profile;
    if (snapshot == null) return const [];
    final name = profileMap[firing.firingProfileId]?.name ?? snapshot.name;
    final curveData = snapshot.curveData;
    return [
      const Divider(height: 32),
      Text('焼成プロファイル', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(name, style: Theme.of(context).textTheme.bodyLarge),
      if (curveData != null && curveData.isNotEmpty) ...[
        const SizedBox(height: 16),
        FiringChart(
          curveData: curveData,
          isReduction: snapshot.isReduction,
          reductionStartTemp: snapshot.reductionStartTemp,
          reductionEndTemp: snapshot.reductionEndTemp,
        ),
      ],
    ];
  }

  /// 写真待ちのテストピース。題に番号と釉薬名、副題に素地土名。
  /// タップでそのテストピースの編集画面を開く。
  Widget _buildAwaitingTile(
    BuildContext context,
    TestPiece testPiece,
    Map<String, Glaze> glazeMap,
    Map<String, Clay> clayMap,
  ) {
    final glazeName = glazeDisplayName(testPiece, glazeMap);
    final label = testPiece.label;
    return ListTile(
      title: Text(label == null ? glazeName : '$label $glazeName'),
      subtitle: Text(clayDisplayName(testPiece, clayMap)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TestPieceEditScreen(testPiece: testPiece),
        ),
      ),
    );
  }
}
