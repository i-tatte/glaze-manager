import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  group('GlazeEditScreen Widget Tests', () {
    testWidgets('should display empty form for new glaze', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<app.Material>[]));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));

      await tester.pumpWidget(createTestableWidget(const GlazeEditScreen()));
      await tester.pumpAndSettle();

      expect(find.text('釉薬の新規作成'), findsOneWidget);
      expect(find.text('釉薬名'), findsOneWidget);
      expect(find.text('登録名（任意）'), findsOneWidget);
      expect(find.text('備考'), findsOneWidget);
    });

    testWidgets('should populate form for existing glaze', (
      WidgetTester tester,
    ) async {
      final glaze = Glaze(
        id: '1',
        name: 'Test Glaze',
        registeredName: 'Registered Name',
        description: 'Test Description',
        recipe: {'m1': 10.0},
        tags: ['tag1'],
        createdAt: Timestamp.now(),
      );

      final materials = [
        app.Material(
          id: 'm1',
          name: 'Material 1',
          order: 1,
          category: app.MaterialCategory.base,
          components: {},
        ),
      ];

      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));

      await tester.pumpWidget(
        createTestableWidget(GlazeEditScreen(glaze: glaze)),
      );
      await tester.pumpAndSettle();

      expect(find.text('釉薬の編集'), findsOneWidget);
      expect(find.text('Test Glaze'), findsOneWidget);
      expect(find.text('Registered Name'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.text('tag1'), findsOneWidget);
      // Recipe row check might be harder due to DropdownSearch, but we can check if amount is there
      expect(find.text('10.0'), findsOneWidget);
    });
  });
}
