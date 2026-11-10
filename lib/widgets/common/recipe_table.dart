import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:glaze_manager/widgets/common/striped_data_table.dart';

/// 調合表の 1 行分 (表示名・量・タップで開く原料)。
class _RecipeTableLine {
  final String name;
  final double amount;
  final app.Material? material;

  const _RecipeTableLine({
    required this.name,
    required this.amount,
    required this.material,
  });
}

/// 調合レシピ表の共通ウィジェット。
///
/// 並び順 (配合量の多い順)・数値書式・行タップでの原料詳細への遷移を
/// ここで一元管理する。レシピを表示する画面は必ずこれを使う。
class RecipeTable extends StatelessWidget {
  final Map<String, double>? recipe;
  final GlazeSnapshot? snapshot;
  final List<app.Material> materials;

  const RecipeTable({
    super.key,
    required Map<String, double> this.recipe,
    required this.materials,
  }) : snapshot = null;

  /// 写しから調合表を作る。原料が現存すれば現在の名前を、
  /// 削除されていれば写しの名前を表示する。
  const RecipeTable.fromSnapshot({
    super.key,
    required GlazeSnapshot this.snapshot,
    required this.materials,
  }) : recipe = null;

  /// 整数はそのまま、小数は入力された精度のまま表示する。
  static String formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  List<_RecipeTableLine> _buildLines() {
    final materialById = {for (final m in materials) m.id: m};
    final snapshot = this.snapshot;
    if (snapshot != null) {
      return [
        for (final line in snapshot.lines)
          _RecipeTableLine(
            name: materialById[line.materialId]?.name ?? line.name,
            amount: line.amount,
            material: materialById[line.materialId],
          ),
      ];
    }
    return [
      for (final entry in recipe!.entries)
        _RecipeTableLine(
          name: materialById[entry.key]?.name ?? '不明な原料',
          amount: entry.value,
          material: materialById[entry.key],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lines = _buildLines()..sort((a, b) => b.amount.compareTo(a.amount));

    return StripedDataTable(
      columnLabels: const ['原料', '配合量 (g)'],
      rows: lines.map((line) {
        final material = line.material;
        return StripedDataRow(
          [line.name, formatAmount(line.amount)],
          onTap: material == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          MaterialDetailScreen(material: material),
                    ),
                  );
                },
        );
      }).toList(),
    );
  }
}
