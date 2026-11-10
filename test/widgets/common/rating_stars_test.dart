import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/common/rating_stars.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('評価の数だけ星が塗られる', (tester) async {
    await tester.pumpWidget(wrap(const RatingStars(rating: 3)));
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('未評価は星が塗られない', (tester) async {
    await tester.pumpWidget(wrap(const RatingStars(rating: null)));
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
  });

  testWidgets('タップした位置の値を返す', (tester) async {
    int? changed = -1;
    await tester.pumpWidget(
      wrap(RatingStars(rating: 2, onChanged: (v) => changed = v)),
    );
    await tester.tap(find.byIcon(Icons.star_border).at(1)); // 4 番目の星
    expect(changed, 4);
  });

  testWidgets('現在と同じ星をタップすると評価を取り消す', (tester) async {
    int? changed = -1;
    await tester.pumpWidget(
      wrap(RatingStars(rating: 2, onChanged: (v) => changed = v)),
    );
    await tester.tap(find.byIcon(Icons.star).at(1)); // 2 番目の星
    expect(changed, isNull);
  });

  testWidgets('onChanged がなければタップできない', (tester) async {
    await tester.pumpWidget(wrap(const RatingStars(rating: 2)));
    expect(find.byType(InkResponse), findsNothing);
  });
}
