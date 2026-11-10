import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';

// Manual mock
class ManualMockFirestoreService implements FirestoreService {
  final StreamController<TestPiece> testPieceController =
      StreamController<TestPiece>.broadcast();

  Glaze? glazeToReturn;
  Clay? clayToReturn;
  FiringProfile? firingProfileToReturn;
  FiringAtmosphere? firingAtmosphereToReturn;
  List<m.Material>? materialsToReturn;

  @override
  Stream<TestPiece> getTestPieceStream(String id) => testPieceController.stream;

  @override
  Stream<Glaze> getGlazeStream(String id) {
    if (glazeToReturn != null) return Stream.value(glazeToReturn!);
    return const Stream.empty();
  }

  @override
  Stream<Clay> getClayStream(String id) {
    if (clayToReturn != null) return Stream.value(clayToReturn!);
    return const Stream.empty();
  }

  @override
  Stream<FiringProfile> getFiringProfileStream(String id) {
    if (firingProfileToReturn != null) {
      return Stream.value(firingProfileToReturn!);
    }
    return const Stream.empty();
  }

  @override
  Stream<FiringAtmosphere> getFiringAtmosphereStream(String id) {
    if (firingAtmosphereToReturn != null) {
      return Stream.value(firingAtmosphereToReturn!);
    }
    return const Stream.empty();
  }

  @override
  Stream<List<m.Material>> getMaterials() {
    if (materialsToReturn != null) {
      return Stream.value(materialsToReturn!);
    }
    return Stream.value(<m.Material>[]);
  }

  // データプロバイダ経由で参照されるリスト系メソッド
  @override
  Stream<List<Glaze>> getGlazes() =>
      Stream.value([if (glazeToReturn != null) glazeToReturn!]);

  @override
  Stream<List<Clay>> getClays() =>
      Stream.value([if (clayToReturn != null) clayToReturn!]);

  @override
  Stream<List<FiringProfile>> getFiringProfiles() =>
      Stream.value([if (firingProfileToReturn != null) firingProfileToReturn!]);

  @override
  Stream<List<FiringAtmosphere>> getFiringAtmospheres() => Stream.value([
    if (firingAtmosphereToReturn != null) firingAtmosphereToReturn!,
  ]);

  @override
  Stream<List<String>> getTags() => Stream.value(<String>[]);

  @override
  Stream<List<TestPiece>> getTestPieces() => Stream.value(<TestPiece>[]);

  @override
  Future<void> updateViewHistory(String id) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void dispose() {
    testPieceController.close();
  }
}

void main() {
  late ManualMockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = ManualMockFirestoreService();
  });

  tearDown(() {
    mockFirestoreService.dispose();
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

  group('TestPieceDetailScreen Widget Tests', () {
    testWidgets('should display test piece details', (
      WidgetTester tester,
    ) async {
      final testPiece = TestPiece(
        id: 'tp1',
        glazeId: 'g1',
        clayId: 'c1',
        firingProfileId: 'fp1',
        firingAtmosphereId: 'fa1',
        createdAt: Timestamp.now(),
        note: 'Test Note',
      );

      final glaze = Glaze(
        id: 'g1',
        name: 'Test Glaze',
        recipe: {'m1': 50.0, 'm2': 50.0},
        tags: [],
        createdAt: Timestamp.now(),
      );

      final clay = Clay(id: 'c1', name: 'Test Clay', order: 1);

      final firingProfile = FiringProfile(id: 'fp1', name: 'Test Profile');

      final firingAtmosphere = FiringAtmosphere(
        id: 'fa1',
        name: 'Test Atmosphere',
      );

      // Set screen size
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Setup mock data
      mockFirestoreService.glazeToReturn = glaze;
      mockFirestoreService.clayToReturn = clay;
      mockFirestoreService.firingProfileToReturn = firingProfile;
      mockFirestoreService.firingAtmosphereToReturn = firingAtmosphere;
      mockFirestoreService.materialsToReturn = [
        m.Material(
          id: 'm1',
          name: 'Material 1',
          order: 1,
          components: {},
          category: m.MaterialCategory.base,
        ),
        m.Material(
          id: 'm2',
          name: 'Material 2',
          order: 2,
          components: {},
          category: m.MaterialCategory.base,
        ),
      ];

      await tester.pumpWidget(
        createTestableWidget(TestPieceDetailScreen(testPiece: testPiece)),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Emit data
      mockFirestoreService.testPieceController.add(testPiece);

      await tester.pumpAndSettle();

      // Verify details
      expect(find.text('テストピース詳細'), findsOneWidget);
      expect(find.text('Test Glaze'), findsOneWidget);
      expect(find.text('Test Clay'), findsOneWidget);
      expect(find.text('Test Profile'), findsOneWidget);
      expect(find.text('Test Atmosphere'), findsOneWidget);
      expect(find.text('Test Note'), findsOneWidget);
      expect(find.text('調合'), findsOneWidget); // Verify recipe header
    });

    group('調合の写し', () {
      final materials = [
        m.Material(
          id: 'm1',
          name: '長石',
          order: 1,
          components: {},
          category: m.MaterialCategory.base,
        ),
      ];

      TestPiece pieceWithSnapshot({
        String source = SnapshotSource.saved,
        String glazeId = 'g1',
      }) => TestPiece(
        id: 'tp1',
        glazeId: glazeId,
        additionalGlazeIds: const ['g2'],
        clayId: 'c-deleted',
        createdAt: Timestamp.now(),
        snapshot: TestPieceSnapshot(
          glaze: GlazeSnapshot(
            glazeId: glazeId,
            name: '記録時の釉薬名',
            lines: const [
              RecipeLine(
                materialId: 'm1',
                name: '長石',
                category: 'base',
                amount: 70,
              ),
              RecipeLine(
                materialId: 'm-deleted',
                name: '消えた原料',
                category: 'base',
                amount: 30,
              ),
            ],
          ),
          additionalGlazes: [
            GlazeSnapshot(glazeId: 'g2', name: '記録時の追加釉薬', lines: const []),
          ],
          clayName: '記録時の素地土',
          source: source,
          takenAt: Timestamp.now(),
        ),
      );

      Future<void> pumpDetail(WidgetTester tester, TestPiece piece) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        mockFirestoreService.materialsToReturn = materials;

        await tester.pumpWidget(
          createTestableWidget(TestPieceDetailScreen(testPiece: piece)),
        );
        mockFirestoreService.testPieceController.add(piece);
        await tester.pumpAndSettle();
      }

      testWidgets('写しの調合を表示する', (tester) async {
        mockFirestoreService.glazeToReturn = Glaze(
          id: 'g1',
          name: '現在の釉薬名',
          recipe: {'m1': 70, 'm-deleted': 30},
          tags: [],
          createdAt: Timestamp.now(),
        );
        await pumpDetail(tester, pieceWithSnapshot());

        // 量は写しの値、名前は現存すれば現在の名前・なければ写しの名前
        expect(find.text('70'), findsOneWidget);
        expect(find.text('長石'), findsOneWidget);
        expect(find.text('消えた原料'), findsOneWidget);
        expect(find.text('現在の釉薬名'), findsOneWidget);
        expect(find.text('釉薬の現在の調合とは異なります。'), findsNothing);
        expect(find.text('移行時に、その時点の釉薬の調合から埋めた記録です。'), findsNothing);
      });

      testWidgets('現在の調合と違うときに注記を出す', (tester) async {
        mockFirestoreService.glazeToReturn = Glaze(
          id: 'g1',
          name: '現在の釉薬名',
          recipe: {'m1': 80},
          tags: [],
          createdAt: Timestamp.now(),
        );
        await pumpDetail(
          tester,
          pieceWithSnapshot(source: SnapshotSource.backfilled),
        );

        expect(find.text('釉薬の現在の調合とは異なります。'), findsOneWidget);
        expect(find.text('現在の調合に更新'), findsOneWidget);
        // 表示は写しの量のまま
        expect(find.text('70'), findsOneWidget);
        expect(find.text('80'), findsNothing);
        expect(find.text('移行時に、その時点の釉薬の調合から埋めた記録です。'), findsOneWidget);
      });

      testWidgets('釉薬が削除されていても画面を表示する', (tester) async {
        mockFirestoreService.glazeToReturn = null;
        await pumpDetail(tester, pieceWithSnapshot(glazeId: 'g-deleted'));

        expect(find.text('関連する釉薬データが見つかりません。'), findsNothing);
        expect(find.text('記録時の釉薬名'), findsOneWidget);
        expect(find.text('記録時の追加釉薬'), findsOneWidget);
        expect(find.text('記録時の素地土'), findsOneWidget);
        expect(find.text('70'), findsOneWidget);
      });

      testWidgets('釉薬も写しもなければ「不明な釉薬」と表示する', (tester) async {
        mockFirestoreService.glazeToReturn = null;
        await pumpDetail(
          tester,
          TestPiece(
            id: 'tp1',
            glazeId: 'g-deleted',
            additionalGlazeIds: const ['g-deleted-2'],
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        );

        expect(find.text('不明な釉薬'), findsNWidgets(2));
        expect(find.text('調合'), findsNothing);
      });
    });
  });
}
