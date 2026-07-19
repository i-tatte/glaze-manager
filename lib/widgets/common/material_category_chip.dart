import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;

/// 原料カテゴリ表示の共通Chip。
///
/// カテゴリと色の対応はここで一元管理する。
/// カテゴリを表示する画面 (原料一覧・原料詳細など) は必ずこれを使う。
class MaterialCategoryChip extends StatelessWidget {
  final app.MaterialCategory category;

  const MaterialCategoryChip({super.key, required this.category});

  /// カテゴリごとの表示色。
  static Color colorOf(app.MaterialCategory category) {
    switch (category) {
      case app.MaterialCategory.pigment:
        return Colors.pink;
      case app.MaterialCategory.additive:
        return Colors.blue;
      case app.MaterialCategory.base:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        category.displayName,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: colorOf(category),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
    );
  }
}
