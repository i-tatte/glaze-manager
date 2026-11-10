import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/glaze_detail_screen.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
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
      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value([glaze]));

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
      // RecipeTable は整数値を小数点なしで表示する
      expect(find.text('50'), findsOneWidget);
      expect(find.text('テストピース'), findsOneWidget);
      expect(find.byTooltip('複製して新規作成'), findsOneWidget);
      expect(find.text('派生元'), findsNothing);
      expect(find.text('派生した釉薬'), findsNothing);
    });

    group('派生', () {
      final materials = [
        app.Material(
          id: 'm1',
          name: '長石',
          order: 1,
          category: app.MaterialCategory.base,
          components: {},
        ),
        app.Material(
          id: 'm2',
          name: '酸化鉄',
          order: 2,
          category: app.MaterialCategory.pigment,
          components: {},
        ),
      ];
      final parent = Glaze(
        id: 'g0',
        name: '元の青磁',
        recipe: {'m1': 100, 'm2': 1},
        tags: [],
        createdAt: Timestamp.now(),
      );
      Glaze child({required Map<String, double> recipe}) => Glaze(
        id: 'g1',
        name: '青磁 改',
        recipe: recipe,
        tags: [],
        createdAt: Timestamp.now(),
        parentGlazeId: 'g0',
        parentSnapshot: GlazeSnapshot(
          glazeId: 'g0',
          name: '複製時の名前',
          lines: const [
            RecipeLine(
              materialId: 'm1',
              name: '長石',
              category: 'base',
              amount: 100,
            ),
            RecipeLine(
              materialId: 'm2',
              name: '酸化鉄',
              category: 'pigment',
              amount: 1,
            ),
          ],
        ),
      );
      final grandChild = Glaze(
        id: 'g2',
        name: '青磁 改々',
        recipe: {'m1': 100},
        tags: [],
        createdAt: Timestamp.now(),
        parentGlazeId: 'g1',
      );

      Future<void> pumpDetail(
        WidgetTester tester,
        Glaze glaze,
        List<Glaze> all,
      ) async {
        when(
          mockFirestoreService.getGlazeStream(glaze.id),
        ).thenAnswer((_) => Stream.value(glaze));
        when(
          mockFirestoreService.getGlazes(),
        ).thenAnswer((_) => Stream.value(all));
        when(
          mockFirestoreService.getMaterials(),
        ).thenAnswer((_) => Stream.value(materials));
        when(
          mockFirestoreService.getTestPiecesForGlaze(glaze.id),
        ).thenAnswer((_) => Stream.value(<TestPiece>[]));
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestableWidget(GlazeDetailScreen(glaze: glaze)),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('派生元、派生元からの変更、派生した釉薬を表示する', (tester) async {
        final glaze = child(recipe: {'m1': 100, 'm2': 3});
        await pumpDetail(tester, glaze, [parent, glaze, grandChild]);

        // 「派生元」は InfoTile のラベルと差の表の列見出しの 2 か所に出る
        expect(find.widgetWithText(InfoTile, '派生元'), findsOneWidget);
        // 派生元が現存すれば現在の名前
        expect(find.widgetWithText(InfoTile, '元の青磁'), findsOneWidget);
        expect(find.text('派生元からの変更'), findsOneWidget);
        expect(find.text('派生元と同じ調合です。'), findsNothing);
        expect(find.text('派生した釉薬'), findsOneWidget);
        expect(find.text('青磁 改々'), findsOneWidget);
      });

      testWidgets('派生元が削除されていれば写しの名前を出し、同じ調合ならそう表示する', (tester) async {
        // 量は倍だが割合は同じ
        final glaze = child(recipe: {'m1': 200, 'm2': 2});
        await pumpDetail(tester, glaze, [glaze]);

        expect(find.text('複製時の名前'), findsOneWidget);
        expect(find.text('派生元と同じ調合です。'), findsOneWidget);
        expect(find.text('派生した釉薬'), findsNothing);
      });
    });
  });
}
