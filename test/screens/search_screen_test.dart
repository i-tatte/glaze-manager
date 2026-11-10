import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/lab_color.dart' as cs;
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as m;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/search_screen.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;
  late MockSettingsService mockSettingsService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();

    when(
      mockFirestoreService.getFirings(),
    ).thenAnswer((_) => Stream.value(<Firing>[]));
    mockSettingsService = MockSettingsService();

    // SettingsService stubs
    when(mockSettingsService.gridCrossAxisCount).thenReturn(2);
    when(mockSettingsService.themeMode).thenReturn(ThemeMode.system);
    when(mockSettingsService.addListener(any)).thenReturn(null);
    when(mockSettingsService.removeListener(any)).thenReturn(null);
  });

  Widget createTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
        settingsServiceProvider.overrideWith((_) => mockSettingsService),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('SearchScreen Widget Tests', () {
    testWidgets('should display recent test pieces on load', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      when(mockFirestoreService.getFiringAtmospheres()).thenAnswer(
        (_) => Stream.value([FiringAtmosphere(id: 'fa1', name: 'Oxidation')]),
      );
      when(mockFirestoreService.getFiringProfiles()).thenAnswer(
        (_) => Stream.value([FiringProfile(id: 'fp1', name: 'Profile 1')]),
      );
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<m.Material>[]));
      when(
        mockFirestoreService.getRecentTestPieceIds(),
      ).thenAnswer((_) => Stream.value(['tp1']));

      await tester.pumpWidget(createTestableWidget(const SearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('最近見たテストピース'), findsOneWidget);
      expect(find.text('Glaze 1'), findsOneWidget);
    });

    testWidgets('should perform text search', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      when(mockFirestoreService.getFiringAtmospheres()).thenAnswer(
        (_) => Stream.value([FiringAtmosphere(id: 'fa1', name: 'Oxidation')]),
      );
      when(mockFirestoreService.getFiringProfiles()).thenAnswer(
        (_) => Stream.value([FiringProfile(id: 'fp1', name: 'Profile 1')]),
      );
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<m.Material>[]));
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

    testWidgets('should search by material name', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final glazes = [
        Glaze(
          id: 'g1',
          name: 'Glaze 1',
          recipe: {'m1': 50},
          tags: [],
          createdAt: Timestamp.now(),
        ),
      ];
      final materials = [
        m.Material(
          id: 'm1',
          name: 'Kaolin',
          order: 1,
          components: {},
          category: m.MaterialCategory.base,
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
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(glazes));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value(testPieces));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value([]));
      when(mockFirestoreService.getClays()).thenAnswer((_) => Stream.value([]));
      when(mockFirestoreService.getTags()).thenAnswer((_) => Stream.value([]));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));
      when(
        mockFirestoreService.getRecentTestPieceIds(),
      ).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createTestableWidget(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kaolin');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Glaze 1'), findsOneWidget);
    });

    testWidgets('should show suggestions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final materials = [
        m.Material(
          id: 'm1',
          name: 'Kaolin',
          order: 1,
          components: {},
          category: m.MaterialCategory.base,
        ),
      ];

      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value([]));
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value([]));
      when(mockFirestoreService.getClays()).thenAnswer((_) => Stream.value([]));
      when(mockFirestoreService.getTags()).thenAnswer((_) => Stream.value([]));
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));
      when(
        mockFirestoreService.getRecentTestPieceIds(),
      ).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(createTestableWidget(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Kao');
      await tester.pump(); // Trigger listener
      await tester.pumpAndSettle(); // Wait for rebuild

      expect(find.text('Kaolin'), findsOneWidget);
    });

    testWidgets(
      'initialColor auto-applies the color search after navigation (R-2)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const targetColor = Color(0xFFFF0000);
        // 検索色とまったく同じ Lab を持つスウォッチ → ΔE=0 で必ずマッチする
        final swatch = cs.LabColor.fromColor(targetColor);

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
            colorData: [swatch],
            createdAt: Timestamp.now(),
          ),
        ];

        when(
          mockFirestoreService.getGlazes(),
        ).thenAnswer((_) => Stream.value(glazes));
        when(
          mockFirestoreService.getTestPieces(),
        ).thenAnswer((_) => Stream.value(testPieces));
        when(mockFirestoreService.getFiringAtmospheres()).thenAnswer(
          (_) => Stream.value([FiringAtmosphere(id: 'fa1', name: 'Oxidation')]),
        );
        when(mockFirestoreService.getFiringProfiles()).thenAnswer(
          (_) => Stream.value([FiringProfile(id: 'fp1', name: 'Profile 1')]),
        );
        when(
          mockFirestoreService.getClays(),
        ).thenAnswer((_) => Stream.value(clays));
        when(
          mockFirestoreService.getTags(),
        ).thenAnswer((_) => Stream.value(<String>[]));
        when(
          mockFirestoreService.getMaterials(),
        ).thenAnswer((_) => Stream.value(<m.Material>[]));
        when(
          mockFirestoreService.getRecentTestPieceIds(),
        ).thenAnswer((_) => Stream.value(<String>[]));

        // 実機を模す: testPiecesProvider を先に購読して値を持たせ、
        // SearchScreen をあとから push する。こうすると SearchScreen の build 時点で
        // provider は既に値を持っており、ref.listen は発火しない。
        await tester.pumpWidget(
          createTestableWidget(
            Consumer(
              builder: (context, ref, _) {
                ref.watch(testPiecesProvider);
                return Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const SearchScreen(initialColor: targetColor),
                          ),
                        ),
                        child: const Text('検索へ'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('検索へ'));
        await tester.pumpAndSettle();

        // 初期色検索が自動実行されていれば検索結果ビューが表示される
        expect(find.text('検索結果'), findsOneWidget);
        expect(find.text('Glaze 1'), findsOneWidget);
      },
    );
  });

  testWidgets('評価だけで絞り込んでも結果を表示し、チップから解除できる', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    when(mockFirestoreService.getGlazes()).thenAnswer(
      (_) => Stream.value([
        Glaze(
          id: 'g1',
          name: 'Glaze 1',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
        Glaze(
          id: 'g2',
          name: 'Glaze 2',
          recipe: {},
          tags: [],
          createdAt: Timestamp.now(),
        ),
      ]),
    );
    when(mockFirestoreService.getTestPieces()).thenAnswer(
      (_) => Stream.value([
        TestPiece(
          id: 'tp1',
          glazeId: 'g1',
          clayId: 'c1',
          createdAt: Timestamp.now(),
          rating: 4,
        ),
        TestPiece(
          id: 'tp2',
          glazeId: 'g2',
          clayId: 'c1',
          createdAt: Timestamp.now(),
          rating: 2,
        ),
      ]),
    );
    when(
      mockFirestoreService.getFiringAtmospheres(),
    ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
    when(
      mockFirestoreService.getFiringProfiles(),
    ).thenAnswer((_) => Stream.value(<FiringProfile>[]));
    when(
      mockFirestoreService.getClays(),
    ).thenAnswer((_) => Stream.value(<Clay>[]));
    when(mockFirestoreService.getTags()).thenAnswer((_) => Stream.value([]));
    when(
      mockFirestoreService.getMaterials(),
    ).thenAnswer((_) => Stream.value(<m.Material>[]));
    when(
      mockFirestoreService.getRecentTestPieceIds(),
    ).thenAnswer((_) => Stream.value([]));

    await tester.pumpWidget(createTestableWidget(const SearchScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('評価で絞り込み'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('★3 以上'));
    await tester.pumpAndSettle();

    expect(find.text('検索結果'), findsOneWidget);
    expect(find.text('Glaze 1'), findsOneWidget);
    expect(find.text('Glaze 2'), findsNothing);

    // チップを消すと条件が空になり、検索をやめる
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(Chip, '★3 以上'),
        matching: find.byIcon(Icons.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('検索結果'), findsNothing);
  });
}
