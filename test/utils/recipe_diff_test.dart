import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/utils/recipe_diff.dart';

void main() {
  RecipeDiffRow rowOf(List<RecipeDiffRow> rows, String id) =>
      rows.firstWhere((r) => r.materialId == id);

  test('重量と合計に対する割合を列ごとに並べる', () {
    final rows = diffRecipes([
      {'a': 500, 'b': 300},
    ]);
    expect(rowOf(rows, 'a').amounts, [500.0]);
    expect(rowOf(rows, 'a').percentages, [62.5]);
    expect(rowOf(rows, 'b').percentages, [37.5]);
    // 列が 1 つなら違いはない
    expect(rows.any((r) => r.differs), isFalse);
  });

  test('割合で判定する: 合計が違っても割合が同じなら同じ', () {
    final rows = diffRecipes([
      {'a': 50, 'b': 50},
      {'a': 500, 'b': 500},
    ]);
    expect(rows.any((r) => r.differs), isFalse);
  });

  test('割合の差が許容値以上なら違う', () {
    final rows = diffRecipes([
      {'a': 50, 'b': 50},
      {'a': 51, 'b': 49},
    ]);
    expect(rowOf(rows, 'a').differs, isTrue);
    expect(rowOf(rows, 'b').differs, isTrue);

    // 許容値未満の差は同じとみなす
    final near = diffRecipes([
      {'a': 50, 'b': 50},
      {'a': 50.01, 'b': 50},
    ]);
    expect(near.any((r) => r.differs), isFalse);
  });

  test('片方にしかない原料は違う', () {
    final rows = diffRecipes([
      {'a': 100},
      {'a': 100, 'b': 0.0},
    ]);
    final b = rowOf(rows, 'b');
    expect(b.amounts, [null, 0.0]);
    expect(b.percentages.first, isNull);
    expect(b.differs, isTrue);
  });

  test('null の列は調合の記録なしとして違いの判定から除く', () {
    final rows = diffRecipes([
      {'a': 60, 'b': 40},
      null,
      {'a': 60, 'b': 40},
    ]);
    expect(rows.any((r) => r.differs), isFalse);
    expect(rowOf(rows, 'a').amounts, [60.0, null, 60.0]);
    expect(rowOf(rows, 'a').percentages[1], isNull);

    // 記録のある列が 1 つだけなら違いはない
    final single = diffRecipes([
      {'a': 1},
      null,
    ]);
    expect(single.single.differs, isFalse);
  });

  test('先頭の列の重量の多い順に並べ、先頭の列にない原料は後ろに置く', () {
    final rows = diffRecipes([
      {'small': 10, 'large': 80, 'mid': 30},
      {'large': 80, 'extraSmall': 1, 'extraLarge': 90},
    ]);
    expect(rows.map((r) => r.materialId), [
      'large',
      'mid',
      'small',
      'extraLarge',
      'extraSmall',
    ]);
  });

  test('先頭の列が null なら次の列の順に並べる', () {
    final rows = diffRecipes([
      null,
      {'a': 1, 'b': 5},
    ]);
    expect(rows.map((r) => r.materialId), ['b', 'a']);
  });
}
