import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;
  late ValueNotifier<bool> isEditingNotifier;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    isEditingNotifier = ValueNotifier<bool>(false);
  });

  Widget createTestableWidget(Widget child) {
    return Provider<FirestoreService>(
      create: (_) => mockFirestoreService,
      child: MaterialApp(home: child),
    );
  }

  group('MaterialsListScreen Widget Tests', () {
    testWidgets('should display empty state when no materials', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<app.Material>[]));

      await tester.pumpWidget(
        createTestableWidget(
          MaterialsListScreen(isEditingNotifier: isEditingNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('原料が登録されていません。\n右下のボタンから追加してください。'), findsOneWidget);
    });

    testWidgets('should display list of materials', (
      WidgetTester tester,
    ) async {
      final materials = [
        app.Material(
          id: '1',
          name: 'Test Material 1',
          order: 1,
          category: app.MaterialCategory.base,
          components: {'SiO2': 50.0},
        ),
        app.Material(
          id: '2',
          name: 'Test Material 2',
          order: 2,
          category: app.MaterialCategory.pigment,
          components: {'CoO': 10.0},
        ),
      ];

      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));

      await tester.pumpWidget(
        createTestableWidget(
          MaterialsListScreen(isEditingNotifier: isEditingNotifier),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Material 1'), findsOneWidget);
      expect(find.text('Test Material 2'), findsOneWidget);
    });

    testWidgets('should toggle edit mode', (WidgetTester tester) async {
      final materials = [
        app.Material(
          id: '1',
          name: 'Test Material 1',
          order: 1,
          category: app.MaterialCategory.base,
          components: {'SiO2': 50.0},
        ),
      ];

      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));

      await tester.pumpWidget(
        createTestableWidget(
          MaterialsListScreen(isEditingNotifier: isEditingNotifier),
        ),
      );
      await tester.pumpAndSettle();

      // 初期状態は通常モード
      expect(find.byIcon(Icons.remove_circle), findsNothing);

      // 編集モードにする
      isEditingNotifier.value = true;
      await tester.pumpAndSettle();

      // 削除アイコンが表示されることを確認
      expect(find.byIcon(Icons.remove_circle), findsOneWidget);
    });
  });
}
