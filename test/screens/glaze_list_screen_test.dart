import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/glaze_list_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:mockito/mockito.dart';
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

  group('GlazeListScreen Widget Tests', () {
    testWidgets('should display empty state when no glazes', (
      WidgetTester tester,
    ) async {
      // 空のリストを返すようにモック
      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(<Glaze>[]));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<app.Material>[]));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));

      await tester.pumpWidget(createTestableWidget(const GlazeListScreen()));
      await tester.pumpAndSettle();

      // EmptyListPlaceholderが表示されていることを確認
      // メッセージの内容は実装依存だが、EmptyListPlaceholder型で探す
      expect(find.text('釉薬が登録されていません。\n右下のボタンから追加してください。'), findsOneWidget);
    });

    testWidgets('should display list of glazes', (WidgetTester tester) async {
      final glazes = [
        Glaze(
          id: '1',
          name: 'Test Glaze 1',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
        Glaze(
          id: '2',
          name: 'Test Glaze 2',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
      ];

      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(glazes));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<app.Material>[]));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));

      await tester.pumpWidget(createTestableWidget(const GlazeListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Test Glaze 1'), findsOneWidget);
      expect(find.text('Test Glaze 2'), findsOneWidget);
    });
  });
}
