import 'package:flutter/material.dart';

/// テストピースの評価 (星 1〜5) の表示と入力。
///
/// どの画面でも評価は必ずこの部品で表示する。
/// [onChanged] を渡すと各星をタップでき、タップした位置の値を返す。
/// 現在の値と同じ星をタップすると null (未評価) を返す。
class RatingStars extends StatelessWidget {
  /// 評価。null は未評価
  final int? rating;

  /// null なら表示専用
  final ValueChanged<int?>? onChanged;

  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final current = rating ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var value = 1; value <= 5; value++)
          _buildStar(value, value <= current, color),
      ],
    );
  }

  Widget _buildStar(int value, bool filled, Color color) {
    final icon = Icon(
      filled ? Icons.star : Icons.star_border,
      size: size,
      color: color,
    );
    final onChanged = this.onChanged;
    if (onChanged == null) return icon;
    return InkResponse(
      onTap: () => onChanged(value == rating ? null : value),
      radius: size * 0.75,
      child: Padding(padding: const EdgeInsets.all(2), child: icon),
    );
  }
}
