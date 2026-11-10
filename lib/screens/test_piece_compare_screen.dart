import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/utils/date_format.dart';
import 'package:glaze_manager/utils/test_piece_display.dart';
import 'package:glaze_manager/widgets/test_piece_image.dart';
import 'package:glaze_manager/widgets/common/rating_stars.dart';
import 'package:glaze_manager/widgets/common/recipe_diff_table.dart';

/// 2〜4 枚のテストピースを並べて違いを見る画面。
///
/// 左端に項目名、その右にテストピースごとの列を並べる。値が列の間で違う行は
/// 背景を塗る。値のない項目は「—」とし、値のない列がある行は、値のある列
/// どうしが同じでも「違う」とは塗らない (同じとも読めないようにするため)。
class TestPieceCompareScreen extends ConsumerWidget {
  final List<String> testPieceIds;

  const TestPieceCompareScreen({super.key, required this.testPieceIds});

  static const double _labelWidth = 96;
  static const double _minColumnWidth = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testPiecesAsync = ref.watch(testPiecesProvider);
    final glazeMap = ref.watch(glazeMapProvider);
    final clayMap = ref.watch(clayMapProvider);
    final atmosphereMap = ref.watch(firingAtmosphereMapProvider);
    final profileMap = ref.watch(firingProfileMapProvider);
    final firingMap = ref.watch(firingMapProvider);
    final materialNames = ref.watch(materialNameMapProvider);

    final all = testPiecesAsync.valueOrNull ?? const <TestPiece>[];
    final byId = {for (final tp in all) tp.id: tp};
    // 見つからない ID は列から除く
    final pieces = [
      for (final id in testPieceIds)
        if (byId[id] case final tp?) tp,
    ];

    Widget body;
    if (pieces.isEmpty) {
      body = testPiecesAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : const Center(child: Text('比較するテストピースが見つかりません。'));
    } else {
      final glazeNames = [
        for (final tp in pieces) glazeDisplayName(tp, glazeMap),
      ];
      final resolved = [
        for (final tp in pieces)
          resolveFiring(
            tp,
            firingMap: firingMap,
            atmosphereMap: atmosphereMap,
            profileMap: profileMap,
          ),
      ];

      // 焼成回が見つからないときは、各項目を「不明」とする
      String? firingValue(ResolvedFiring r, String? value) {
        if (r.firingMissing) return '不明';
        return (value == null || value.isEmpty) ? null : value;
      }

      final rows =
          <_CompareRow>[
                _CompareRow.text('釉薬', glazeNames),
                _CompareRow(
                  label: '評価',
                  values: [for (final tp in pieces) tp.rating?.toString()],
                  cellBuilder: (index) =>
                      RatingStars(rating: pieces[index].rating),
                ),
                _CompareRow.text('番号', [for (final tp in pieces) tp.label]),
                _CompareRow.text('素地土', [
                  for (final tp in pieces) clayDisplayName(tp, clayMap),
                ]),
                _CompareRow.text('焼成日', [
                  for (final r in resolved)
                    firingValue(
                      r,
                      r.firedOn == null ? null : formatDate(r.firedOn!),
                    ),
                ]),
                _CompareRow.text('窯', [
                  for (final r in resolved) firingValue(r, r.kilnName),
                ]),
                _CompareRow.text('焼成雰囲気', [
                  for (final r in resolved) firingValue(r, r.atmosphereName),
                ]),
                _CompareRow.text('焼成プロファイル', [
                  for (final r in resolved) firingValue(r, r.profileName),
                ]),
                _CompareRow.text('追加釉薬', [
                  for (final tp in pieces)
                    tp.additionalGlazeIds.isEmpty
                        ? null
                        : tp.additionalGlazeIds
                              .map(
                                (id) => additionalGlazeDisplayName(
                                  tp,
                                  id,
                                  glazeMap,
                                ),
                              )
                              .join('、'),
                ]),
                _CompareRow.text('備考', [for (final tp in pieces) tp.note]),
              ]
              .where((row) => row.values.any((v) => v != null && v.isNotEmpty))
              .toList();

      // 調合は主たる釉薬の写し、なければ現在の釉薬から取る
      final recipes = <Map<String, double>?>[
        for (final tp in pieces)
          tp.snapshot?.glaze?.recipe ?? glazeMap[tp.glazeId]?.recipe,
      ];
      // 削除された原料の名前は写しから補う
      final snapshotMaterialNames = <String, String>{
        for (final tp in pieces)
          for (final line in tp.snapshot?.glaze?.lines ?? const [])
            line.materialId: line.name,
      };
      String materialName(String id) =>
          materialNames[id] ?? snapshotMaterialNames[id] ?? '不明な原料';

      final labels = [
        for (var i = 0; i < pieces.length; i++)
          pieces[i].label == null
              ? glazeNames[i]
              : '${pieces[i].label} ${glazeNames[i]}',
      ];

      body = LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - _labelWidth;
          final columnWidth = available / pieces.length < _minColumnWidth
              ? _minColumnWidth
              : available / pieces.length;
          final tableWidth = _labelWidth + columnWidth * pieces.length;
          final highlight = Theme.of(context).colorScheme.secondaryContainer;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _buildPhotoRow(context, pieces, columnWidth),
                        for (final row in rows)
                          _buildRow(context, row, columnWidth, highlight),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    '調合',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RecipeDiffTable(
                  columnLabels: labels,
                  recipes: recipes,
                  materialName: materialName,
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('テストピースの比較')),
      body: body,
    );
  }

  Widget _buildPhotoRow(
    BuildContext context,
    List<TestPiece> pieces,
    double columnWidth,
  ) {
    return Row(
      children: [
        const SizedBox(width: _labelWidth),
        for (final tp in pieces)
          SizedBox(
            width: columnWidth,
            height: columnWidth,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TestPieceDetailScreen(testPiece: tp),
                  ),
                ),
                child: TestPieceImage(testPiece: tp, preferThumbnail: false),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    _CompareRow row,
    double columnWidth,
    Color highlight,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: row.differs ? highlight : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _labelWidth,
              padding: const EdgeInsets.all(8),
              alignment: Alignment.topLeft,
              child: Text(
                row.label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (var i = 0; i < row.values.length; i++)
              Container(
                width: columnWidth,
                padding: const EdgeInsets.all(8),
                alignment: Alignment.topLeft,
                child: _buildCell(context, row, i),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, _CompareRow row, int index) {
    final value = row.values[index];
    if (value == null || value.isEmpty) return const Text('—');
    final builder = row.cellBuilder;
    if (builder != null) return builder(index);
    return Text(value);
  }
}

/// 比較表の 1 行。[values] は列ごとの値 (null は記録なし)。
/// [cellBuilder] があれば、値のある列のセルをそれで描く。
class _CompareRow {
  final String label;
  final List<String?> values;
  final Widget Function(int index)? cellBuilder;

  const _CompareRow({
    required this.label,
    required this.values,
    this.cellBuilder,
  });

  factory _CompareRow.text(String label, List<String?> values) =>
      _CompareRow(label: label, values: values);

  /// 値のある列の間で値が違うか。値のない列は判定から除く。
  bool get differs {
    final recorded = {
      for (final v in values)
        if (v != null && v.isNotEmpty) v,
    };
    return recorded.length > 1;
  }
}
