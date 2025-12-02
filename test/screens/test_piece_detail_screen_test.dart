import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

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
    return Provider<FirestoreService>(
      create: (_) => mockFirestoreService,
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
      expect(find.text('レシピ'), findsOneWidget); // Verify recipe header
    });
  });
}
