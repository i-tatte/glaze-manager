import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockStorageService = MockStorageService();
  });

  Widget createTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => mockFirestoreService),
        Provider<StorageService>(create: (_) => mockStorageService),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('TestPieceEditScreen Widget Tests', () {
    testWidgets('should display empty form for new test piece', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(<Glaze>[]));
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(<Clay>[]));
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(<FiringProfile>[]));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));

      await tester.pumpWidget(
        createTestableWidget(const TestPieceEditScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('テストピースの新規作成'), findsOneWidget);
      expect(find.text('釉薬名 (メイン)'), findsOneWidget);
      expect(find.text('素地土名'), findsOneWidget);
    });

    testWidgets('should populate form for existing test piece', (
      WidgetTester tester,
    ) async {
      final testPiece = TestPiece(
        id: 'tp1',
        glazeId: 'g1',
        clayId: 'c1',
        firingProfileId: 'fp1',
        createdAt: Timestamp.now(),
      );

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
      final profiles = [FiringProfile(id: 'fp1', name: 'Profile 1')];

      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(glazes));
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(profiles));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));

      await tester.pumpWidget(
        createTestableWidget(TestPieceEditScreen(testPiece: testPiece)),
      );
      await tester.pumpAndSettle();

      expect(find.text('テストピースの編集'), findsOneWidget);
      expect(find.text('Glaze 1'), findsOneWidget);
      expect(find.text('Clay 1'), findsOneWidget);
      expect(find.text('Profile 1'), findsOneWidget);
    });
  });
}
