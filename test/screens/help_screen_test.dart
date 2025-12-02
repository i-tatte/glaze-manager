import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/screens/help_screen.dart';

void main() {
  testWidgets('HelpScreen renders correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));

    // Verify title
    expect(find.text('ヘルプ / FAQ'), findsOneWidget);

    // Verify sections
    expect(find.text('検索機能について'), findsOneWidget);
    expect(find.text('調合計算機について'), findsOneWidget);
    expect(find.text('データ管理について'), findsOneWidget);
  });
}
