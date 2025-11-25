import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/glaze_detail_screen.dart';
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

  group('GlazeDetailScreen Widget Tests', () {
    testWidgets('should display glaze details', (WidgetTester tester) async {
      final glaze = Glaze(
        id: 'g1',
        name: 'Test Glaze',
        registeredName: 'Registered Name',
        description: 'Test Description',
        recipe: {'m1': 50.0},
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

      final testPieces = [
        TestPiece(
          id: 'tp1',
          glazeId: 'g1',
          clayId: 'c1',
          firingProfileId: 'fp1',
          createdAt: Timestamp.now(),
        ),
      ];

      when(
        mockFirestoreService.getGlazeStream('g1'),
      ).thenAnswer((_) => Stream.value(glaze));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));
      when(
        mockFirestoreService.getTestPiecesForGlaze('g1'),
      ).thenAnswer((_) => Stream.value(testPieces));

      // Set screen size
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestableWidget(GlazeDetailScreen(glaze: glaze)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Glaze'), findsOneWidget);
      expect(find.text('Registered Name'), findsNWidgets(2));
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.text('tag1'), findsOneWidget);
      expect(find.text('Material 1'), findsOneWidget);
      expect(find.text('50.0'), findsOneWidget);
      expect(find.text('テストピース'), findsOneWidget);
    });
  });
}
