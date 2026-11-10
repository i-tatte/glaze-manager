import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/common/recipe_diff_table.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  Color? rowColor(WidgetTester tester, String name) {
    final table = tester.widget<DataTable>(find.byType(DataTable));
    final row = table.rows.firstWhere(
      (r) => (r.cells.first.child as Text).data == name,
    );
    return row.color?.resolve(<WidgetState>{});
  }

  Color highlightOf(WidgetTester tester) {
    final context = tester.element(find.byType(DataTable));
    return Theme.of(context).colorScheme.secondaryContainer;
  }

  // x は両列とも 40% で同じ。y と z は割合が違う
  const recipes = [
    {'x': 40.0, 'y': 40.0, 'z': 20.0},
    {'x': 40.0, 'y': 20.0, 'z': 40.0},
  ];

  testWidgets('重量と割合を表示し、ない原料は「—」にする', (tester) async {
    await pump(
      tester,
      RecipeDiffTable(
        columnLabels: const ['派生元', 'この釉薬'],
        recipes: const [
          {'a': 500, 'b': 300},
          {'a': 500, 'b': 300, 'c': 10},
        ],
        materialName: (id) => '原料$id',
      ),
    );

    expect(find.text('原料'), findsOneWidget);
    expect(find.text('派生元'), findsOneWidget);
    expect(find.text('この釉薬'), findsOneWidget);
    expect(find.text('500 (62.5%)'), findsOneWidget);
    expect(find.text('原料c'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('違いのある行だけを secondaryContainer で塗る', (tester) async {
    await pump(
      tester,
      RecipeDiffTable(
        columnLabels: const ['A', 'B'],
        recipes: recipes,
        materialName: (id) => id,
      ),
    );

    final highlight = highlightOf(tester);
    expect(rowColor(tester, 'y'), highlight);
    expect(rowColor(tester, 'z'), highlight);
    expect(rowColor(tester, 'x'), isNot(highlight));
    expect(find.text('40 (40.0%)'), findsNWidgets(4));
  });

  testWidgets('onlyDiffering なら違いのある行だけを表示する', (tester) async {
    await pump(
      tester,
      RecipeDiffTable(
        columnLabels: const ['A', 'B'],
        recipes: recipes,
        materialName: (id) => id,
        onlyDiffering: true,
      ),
    );

    expect(find.text('x'), findsNothing);
    expect(find.text('y'), findsOneWidget);
    expect(find.text('z'), findsOneWidget);
  });
}
