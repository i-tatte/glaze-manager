import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;
  late MockSettingsService mockSettingsService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockSettingsService = MockSettingsService();

    // SettingsService stubs
    when(mockSettingsService.gridCrossAxisCount).thenReturn(2);
    when(mockSettingsService.addListener(any)).thenReturn(null);
    when(mockSettingsService.removeListener(any)).thenReturn(null);
  });

  Widget createTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => mockFirestoreService),
        ChangeNotifierProvider<SettingsService>.value(
          value: mockSettingsService,
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('SearchScreen Widget Tests', () {
    testWidgets('should display recent test pieces on load', (
      WidgetTester tester,
    ) async {
      // Mock data
      final glazes = [
        Glaze(
          id: 'g1',
          name: 'Glaze 1',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
      ];
      final clays = [Clay(id: 'c1', name: 'Clay 1', order: 1)];
      final testPieces = [
        TestPiece(
          id: 'tp1',
          glazeId: 'g1',
          clayId: 'c1',
          firingProfileId: 'fp1',
          createdAt: Timestamp.now(),
        ),
      ];

      // Mock Firestore responses
      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(glazes));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value(testPieces));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(<FiringProfile>[]));
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(
        mockFirestoreService.getRecentTestPieceIds(),
      ).thenAnswer((_) => Stream.value(['tp1']));

      await tester.pumpWidget(createTestableWidget(const SearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('最近見たテストピース'), findsOneWidget);
      expect(find.text('Glaze 1'), findsOneWidget);
    });

    testWidgets('should perform text search', (WidgetTester tester) async {
      // Mock data
      final glazes = [
        Glaze(
          id: 'g1',
          name: 'Target Glaze',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
        Glaze(
          id: 'g2',
          name: 'Other Glaze',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
      ];
      final clays = [Clay(id: 'c1', name: 'Clay 1', order: 1)];
      final testPieces = [
        TestPiece(
          id: 'tp1',
          glazeId: 'g1',
          clayId: 'c1',
          firingProfileId: 'fp1',
          createdAt: Timestamp.now(),
        ),
        TestPiece(
          id: 'tp2',
          glazeId: 'g2',
          clayId: 'c1',
          firingProfileId: 'fp1',
          createdAt: Timestamp.now(),
        ),
      ];

      // Mock Firestore responses
      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(glazes));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value(testPieces));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(<FiringProfile>[]));
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(
        mockFirestoreService.getRecentTestPieceIds(),
      ).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createTestableWidget(const SearchScreen()));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Target');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('検索結果'), findsOneWidget);
      expect(find.text('Target Glaze'), findsOneWidget);
      expect(find.text('Other Glaze'), findsNothing);
    });
  });
}
