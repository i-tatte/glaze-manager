import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/theme/app_colors.dart';

/// 焼成雰囲気タイプとカード背景色の対応をここで一元管理する。
/// 雰囲気による色分け表示をするウィジェットは必ずこれを参照する。
extension FiringAtmosphereCardColor on FiringAtmosphereType {
  /// カード背景色。その他 (色分けなし) の場合は null を返す。
  Color? cardColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (this) {
      case FiringAtmosphereType.oxidation:
        return isDark
            ? AppColors.oxidationCardDark
            : AppColors.oxidationCardLight;
      case FiringAtmosphereType.reduction:
        return isDark
            ? AppColors.reductionCardDark
            : AppColors.reductionCardLight;
      case FiringAtmosphereType.other:
        return null;
    }
  }
}
