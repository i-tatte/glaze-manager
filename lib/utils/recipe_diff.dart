/// 調合の差の 1 行 (原料 1 つ分)。
class RecipeDiffRow {
  final String materialId;

  /// 列ごとの重量。その列の調合に無ければ null
  final List<double?> amounts;

  /// 列ごとの、合計に対する百分率。その列の調合に無ければ null
  final List<double?> percentages;

  /// 列の間で割合が違う
  final bool differs;

  const RecipeDiffRow({
    required this.materialId,
    required this.amounts,
    required this.percentages,
    required this.differs,
  });
}

/// 複数の調合を原料ごとに並べる。
/// recipes の要素が null の列は「調合の記録なし」として扱い、違いの判定から除く。
///
/// 違いの判定は重量ではなく合計に対する割合で行う。割合の差が
/// [tolerancePercent] 以上なら違うとする。ある列にその原料がなく、
/// 別の列にあれば違うとする。
/// 行は先頭の列の重量の多い順に並べ、先頭の列にない原料はその後ろに置く
/// (その原料が最初に現れる列の重量の多い順)。
List<RecipeDiffRow> diffRecipes(
  List<Map<String, double>?> recipes, {
  double tolerancePercent = 0.05,
}) {
  final totals = [
    for (final recipe in recipes)
      recipe?.values.fold<double>(0, (sum, v) => sum + v),
  ];

  // 原料ごとに、最初に現れる列と、その列での重量を控える (並び順に使う)
  final firstColumn = <String, int>{};
  for (var i = 0; i < recipes.length; i++) {
    final recipe = recipes[i];
    if (recipe == null) continue;
    for (final id in recipe.keys) {
      firstColumn.putIfAbsent(id, () => i);
    }
  }

  final ids = firstColumn.keys.toList()
    ..sort((a, b) {
      final ca = firstColumn[a]!;
      final cb = firstColumn[b]!;
      if (ca != cb) return ca.compareTo(cb);
      return recipes[cb]![b]!.compareTo(recipes[ca]![a]!);
    });

  return [
    for (final id in ids) _buildRow(id, recipes, totals, tolerancePercent),
  ];
}

RecipeDiffRow _buildRow(
  String materialId,
  List<Map<String, double>?> recipes,
  List<double?> totals,
  double tolerancePercent,
) {
  final amounts = <double?>[];
  final percentages = <double?>[];
  for (var i = 0; i < recipes.length; i++) {
    final amount = recipes[i]?[materialId];
    final total = totals[i];
    amounts.add(amount);
    percentages.add(
      amount == null || total == null
          ? null
          : (total > 0 ? amount / total * 100 : 0),
    );
  }

  // 調合の記録がある列だけで違いを判定する
  final recorded = [
    for (var i = 0; i < recipes.length; i++)
      if (recipes[i] != null) percentages[i],
  ];
  var differs = false;
  if (recorded.length >= 2) {
    if (recorded.any((p) => p == null)) {
      differs = true; // ある列にだけ原料がない
    } else {
      final values = recorded.cast<double>();
      final max = values.reduce((a, b) => a > b ? a : b);
      final min = values.reduce((a, b) => a < b ? a : b);
      differs = max - min >= tolerancePercent;
    }
  }

  return RecipeDiffRow(
    materialId: materialId,
    amounts: amounts,
    percentages: percentages,
    differs: differs,
  );
}
