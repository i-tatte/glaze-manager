import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/test_piece_edit_screen.dart';
import 'package:mockito/mockito.dart';
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
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
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

    testWidgets('既存のテストピースの備考だけ変えて保存すると、Functions が書く値は送らない', (
      WidgetTester tester,
    ) async {
      final testPiece = TestPiece(
        id: 'tp1',
        glazeId: 'g1',
        clayId: 'c1',
        imageUrl: 'https://example.com/a.jpg',
        thumbnailUrl: 'https://example.com/t.jpg',
        imagePath: 'users/u/test_pieces/tp1/a.jpg',
        colorData: [LabColor(l: 50, a: 0, b: 0, percentage: 80)],
        createdAt: Timestamp.now(),
      );
      when(mockFirestoreService.getGlazes()).thenAnswer(
        (_) => Stream.value([
          Glaze(
            id: 'g1',
            name: 'Glaze 1',
            recipe: {},
            tags: [],
            createdAt: Timestamp.now(),
          ),
        ]),
      );
      when(mockFirestoreService.getClays()).thenAnswer(
        (_) => Stream.value([Clay(id: 'c1', name: 'Clay 1', order: 1)]),
      );
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(<FiringProfile>[]));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
      when(
        mockFirestoreService.updateTestPieceFields(any, any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        createTestableWidget(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TestPieceEditScreen(testPiece: testPiece),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, '備考を直した');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      final captured =
          verify(
                mockFirestoreService.updateTestPieceFields('tp1', captureAny),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['note'], '備考を直した');
      expect(captured.containsKey('imageUrl'), isFalse);
      expect(captured.containsKey('thumbnailUrl'), isFalse);
      expect(captured.containsKey('colorData'), isFalse);
      expect(captured.containsKey('imagePath'), isFalse);
      expect(captured.containsKey('createdAt'), isFalse);
    });
  });
}
