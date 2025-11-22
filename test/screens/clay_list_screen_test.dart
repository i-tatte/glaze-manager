import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/screens/clay_list_screen.dart';
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

  group('ClayListScreen Widget Tests', () {
    testWidgets('should display loading indicator when waiting', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(createTestableWidget(const ClayListScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty message when no clays', (
      WidgetTester tester,
    ) async {
      when(mockFirestoreService.getClays()).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createTestableWidget(const ClayListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('素地土名が登録されていません。\n右下のボタンから追加してください。'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('should display list of clays', (WidgetTester tester) async {
      final clays = [
        Clay(id: 'c1', name: 'Clay 1', order: 1),
        Clay(id: 'c2', name: 'Clay 2', order: 2),
      ];

      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));

      await tester.pumpWidget(createTestableWidget(const ClayListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Clay 1'), findsOneWidget);
      expect(find.text('Clay 2'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('should show delete confirmation dialog', (
      WidgetTester tester,
    ) async {
      final clays = [Clay(id: 'c1', name: 'Clay 1', order: 1)];

      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(mockFirestoreService.deleteClay('c1')).thenAnswer((_) async {});

      await tester.pumpWidget(createTestableWidget(const ClayListScreen()));
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('削除の確認'), findsOneWidget);
      expect(find.text('「Clay 1」を本当に削除しますか？'), findsOneWidget);

      // Tap delete in dialog
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      verify(mockFirestoreService.deleteClay('c1')).called(1);
    });
  });
}
