import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:mockito/mockito.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
  });

  Widget createTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
      ],
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

    testWidgets('new material save uses the selected category (R-1)', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.addMaterial(any),
      ).thenAnswer((_) => Future.value());

      await tester.pumpWidget(createTestableWidget(const MaterialEditScreen()));
      await tester.pumpAndSettle();

      // 原料名を入力（バリデーション通過のため必須）
      await tester.enterText(find.byType(TextFormField), '弁柄');

      // カテゴリで「顔料」を選択する
      await tester.tap(find.text('顔料'));
      await tester.pumpAndSettle();

      // 保存
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pumpAndSettle();

      // addMaterial に渡った Material のカテゴリが pigment であること
      final captured = verify(
        mockFirestoreService.addMaterial(captureAny),
      ).captured;
      expect(captured, hasLength(1));
      final saved = captured.single as app.Material;
      expect(saved.category, app.MaterialCategory.pigment);
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
