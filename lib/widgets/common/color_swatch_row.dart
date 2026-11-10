import 'package:flutter/material.dart';
import 'package:glaze_manager/models/lab_color.dart';

/// テストピースの色見本 (CIELAB スウォッチ) を丸チップで並べる共通ウィジェット。
///
/// テストピース詳細画面と共有プレビュー画面で同じ見た目を共有する。
/// 表示する色は [significantColors] で決める (手動登録の色は常に表示、自動解析の色は構成比 5% 超のみ)。
class ColorSwatchRow extends StatelessWidget {
  final List<LabColor> colorData;

  /// スウォッチタップ時のコールバック。null なら非インタラクティブ表示
  final ValueChanged<Color>? onTapSwatch;

  const ColorSwatchRow({super.key, required this.colorData, this.onTapSwatch});

  @override
  Widget build(BuildContext context) {
    final shownColors = significantColors(colorData);

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: shownColors.map((swatch) {
        final color = swatch.toColor();
        final circle = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black54, width: 1.0),
          ),
        );
        final onTap = onTapSwatch;
        if (onTap == null) return circle;
        return InkWell(onTap: () => onTap(color), child: circle);
      }).toList(),
    );
  }
}
