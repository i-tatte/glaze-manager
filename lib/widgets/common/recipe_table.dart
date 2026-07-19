import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:glaze_manager/widgets/common/striped_data_table.dart';

/// 調合レシピ表の共通ウィジェット。
///
/// 並び順 (配合量の多い順)・数値書式・行タップでの原料詳細への遷移を
/// ここで一元管理する。レシピを表示する画面は必ずこれを使う。
class RecipeTable extends StatelessWidget {
  final Map<String, double> recipe;
  final List<app.Material> materials;

  const RecipeTable({
    super.key,
    required this.recipe,
    required this.materials,
  });

  /// 整数はそのまま、小数は入力された精度のまま表示する。
  static String formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final materialById = {for (final m in materials) m.id: m};
    final sortedEntries = recipe.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return StripedDataTable(
      columnLabels: const ['原料', '配合(g)'],
      rows: sortedEntries.map((entry) {
        final material = materialById[entry.key];
        return StripedDataRow(
          [material?.name ?? '不明な原料', formatAmount(entry.value)],
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
