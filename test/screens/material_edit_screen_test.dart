import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
  });

  Widget createTestableWidget(Widget child) {
    return Provider<FirestoreService>(
      create: (_) => mockFirestoreService,
      child: MaterialApp(home: child),
    );
  }

  group('MaterialEditScreen Widget Tests', () {
    testWidgets('should display empty form for new material', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const MaterialEditScreen()));
      await tester.pumpAndSettle();

      expect(find.text('原料の新規作成'), findsOneWidget);
      expect(find.text('原料名'), findsOneWidget);
      expect(find.text('化学成分'), findsOneWidget);
    });

    testWidgets('should populate form for existing material', (
      WidgetTester tester,
    ) async {
      final material = app.Material(
        id: '1',
        name: 'Test Material',
        order: 1,
        category: app.MaterialCategory.base,
        components: {'SiO2': 50.0},
      );

      await tester.pumpWidget(
        createTestableWidget(MaterialEditScreen(material: material)),
      );
      await tester.pumpAndSettle();

      expect(find.text('原料の編集'), findsOneWidget);
      expect(find.text('Test Material'), findsOneWidget);
      expect(find.text('SiO2'), findsOneWidget);
      expect(find.text('50.0'), findsOneWidget);
    });

    testWidgets('should add component row', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const MaterialEditScreen()));
      await tester.pumpAndSettle();

      // 初期状態では成分行はないはず（または空の行があるか確認）
      // コードを見ると初期状態は空
      expect(find.byType(TextFormField), findsNWidgets(1)); // 原料名のみ

      // 成分を追加ボタンを押す
      await tester.tap(find.text('成分を追加'));
      await tester.pumpAndSettle();

      // 成分名と量のフィールドが増えているはず
      expect(find.text('成分名 (例: SiO2)'), findsOneWidget);
      expect(find.text('量 (%)'), findsOneWidget);
    });
  });
}
