import 'package:flutter/material.dart';
import 'package:glaze_manager/utils/recipe_diff.dart';
import 'package:glaze_manager/widgets/common/recipe_table.dart';
import 'package:glaze_manager/widgets/common/striped_data_table.dart';

/// 複数の調合を原料ごとに並べて差を示す表。
///
/// セルには「500 (62.5%)」のように重量と合計に対する割合を表示し、
/// その列にない原料は「—」とする。違いのある行は背景を塗る。
/// 見た目は [StripedDataTable] に揃える。
class RecipeDiffTable extends StatelessWidget {
  /// 調合の列の見出し (原料名の列は含めない)
  final List<String> columnLabels;

  /// 列ごとの調合 (原料 ID → 重量)。null は「調合の記録なし」
  final List<Map<String, double>?> recipes;

  /// 原料 ID から表示名を引く
  final String Function(String materialId) materialName;

  /// 違いのある行だけを表示する
  final bool onlyDiffering;

  const RecipeDiffTable({
    super.key,
    required this.columnLabels,
    required this.recipes,
    required this.materialName,
    this.onlyDiffering = false,
  }) : assert(columnLabels.length == recipes.length);

  /// セルの表示。「500 (62.5%)」、その列にない原料は「—」。
  static String formatCell(double? amount, double? percentage) {
    if (amount == null) return '—';
    final amountText = RecipeTable.formatAmount(amount);
    if (percentage == null) return amountText;
    return '$amountText (${percentage.toStringAsFixed(1)}%)';
  }

  @override
  Widget build(BuildContext context) {
    var rows = diffRecipes(recipes);
    if (onlyDiffering) {
      rows = rows.where((r) => r.differs).toList();
    }

    // 列が増えると狭い画面に収まらないので、横にスクロールできるようにする
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: StripedDataTable(
        columnLabels: ['原料', ...columnLabels],
        numericLastColumn: false,
        rows: [
          for (final row in rows)
            StripedDataRow([
              materialName(row.materialId),
              for (var i = 0; i < row.amounts.length; i++)
                formatCell(row.amounts[i], row.percentages[i]),
            ], highlighted: row.differs),
        ],
      ),
    );
  }
}
