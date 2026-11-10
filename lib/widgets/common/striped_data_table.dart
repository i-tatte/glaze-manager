import 'package:flutter/material.dart';

/// 表形式データの1行分。[onTap] を渡すと行タップで遷移などができる。
/// [highlighted] の行は背景をテーマの secondaryContainer で塗る。
class StripedDataRow {
  final List<String> cells;
  final VoidCallback? onTap;
  final bool highlighted;

  const StripedDataRow(this.cells, {this.onTap, this.highlighted = false});
}

/// 表形式データ表示の共通ウィジェット。
///
/// 縞模様 (奇数行に薄いグレー) や列見出しのスタイルをここで一元管理する。
/// レシピ表・化学成分表など、アプリ内の表はすべてこれを使う。
class StripedDataTable extends StatelessWidget {
  final List<String> columnLabels;
  final List<StripedDataRow> rows;

  /// 最終列を数値列として右寄せするかどうか。
  final bool numericLastColumn;

  const StripedDataTable({
    super.key,
    required this.columnLabels,
    required this.rows,
    this.numericLastColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(context).colorScheme.secondaryContainer;
    return DataTable(
      showCheckboxColumn: false,
      columns: [
        for (var i = 0; i < columnLabels.length; i++)
          DataColumn(
            label: Text(columnLabels[i]),
            numeric: numericLastColumn && i == columnLabels.length - 1,
          ),
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          DataRow(
            color: WidgetStateProperty.resolveWith<Color?>(
              (states) => rows[i].highlighted
                  ? highlightColor
                  : (i.isOdd ? Colors.grey.withValues(alpha: 0.1) : null),
            ),
            onSelectChanged: rows[i].onTap == null
                ? null
                : (_) => rows[i].onTap!(),
            cells: [for (final cell in rows[i].cells) DataCell(Text(cell))],
          ),
      ],
    );
  }
}
