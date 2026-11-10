import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/widgets/common/tag_chip.dart';
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

    testWidgets('区切り文字を入力するとタグが確定する', (WidgetTester tester) async {
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<app.Material>[]));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));

      await tester.pumpWidget(createTestableWidget(const GlazeEditScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '青磁 還元');
      await tester.pumpAndSettle();

      expect(find.byType(TagChip), findsNWidgets(2));
      expect(find.text('青磁'), findsOneWidget);
      expect(find.text('還元'), findsOneWidget);
    });

    testWidgets('delete dialog warns about referencing test pieces', (
      WidgetTester tester,
    ) async {
      final glaze = Glaze(
        id: 'g1',
        name: 'Used Glaze',
        recipe: {},
        tags: [],
        createdAt: Timestamp.now(),
      );

      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(<app.Material>[]));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(mockFirestoreService.getTestPieces()).thenAnswer(
        (_) => Stream.value([
          // メインとして2件、追加として1件参照
          TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
          TestPiece(
            id: 'tp2',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
          TestPiece(
            id: 'tp3',
            glazeId: 'other',
            additionalGlazeIds: const ['g1'],
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ]),
      );

      await tester.pumpWidget(
        createTestableWidget(GlazeEditScreen(glaze: glaze)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2件のテストピースがこの釉薬をメインとして使用しています'),
        findsOneWidget,
      );
      expect(find.textContaining('1件のテストピースが追加の釉薬として使用しています'), findsOneWidget);
    });
  });

  group('複製と、調合を変えたときの記録の扱い', () {
    final materials = [
      app.Material(
        id: 'm1',
        name: 'Material 1',
        order: 1,
        category: app.MaterialCategory.base,
        components: {},
      ),
    ];
    final glaze = Glaze(
      id: 'g1',
      name: '青磁',
      registeredName: 'SEIJI',
      description: '元の備考',
      recipe: {'m1': 10.0},
      tags: ['青'],
      createdAt: Timestamp.now(),
    );
    final referencingPiece = TestPiece(
      id: 'tp1',
      glazeId: 'g1',
      clayId: 'c1',
      createdAt: Timestamp.now(),
      snapshot: TestPieceSnapshot(
        glaze: GlazeSnapshot.capture(glaze, {
          for (final m in materials) m.id!: m,
        }),
        source: SnapshotSource.saved,
        takenAt: Timestamp.now(),
      ),
    );

    setUp(() {
      when(
        mockFirestoreService.getMaterials(),
      ).thenAnswer((_) => Stream.value(materials));
      when(
        mockFirestoreService.getTags(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value([referencingPiece]));
      when(mockFirestoreService.addTags(any)).thenAnswer((_) async {});
      when(mockFirestoreService.addGlaze(any)).thenAnswer((_) async {});
      when(mockFirestoreService.updateGlaze(any)).thenAnswer((_) async {});
      when(
        mockFirestoreService.updateTestPieceFieldsBatch(any),
      ).thenAnswer((_) async {});
    });

    /// 保存で画面を閉じられるよう、一つ前の画面から開く
    Future<void> openEditor(WidgetTester tester, GlazeEditScreen screen) async {
      await tester.pumpWidget(
        createTestableWidget(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('複製のときはフォームが複製元の値で埋まる', (tester) async {
      await openEditor(tester, GlazeEditScreen(sourceGlaze: glaze));

      expect(find.text('釉薬の複製'), findsOneWidget);
      expect(find.text('青磁'), findsOneWidget);
      expect(find.text('SEIJI'), findsNothing);
      expect(find.text('元の備考'), findsNothing);
      expect(find.text('青'), findsOneWidget);
      expect(find.text('10.0'), findsOneWidget);

      // 何も入力せずに戻ろうとしても未保存の確認が出る
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('複製を保存すると派生元と複製時点の調合を記録する', (tester) async {
      await openEditor(tester, GlazeEditScreen(sourceGlaze: glaze));

      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      final saved =
          verify(mockFirestoreService.addGlaze(captureAny)).captured.single
              as Glaze;
      expect(saved.id, isNull);
      expect(saved.parentGlazeId, 'g1');
      expect(saved.parentSnapshot!.recipe, {'m1': 10.0});
      expect(saved.parentSnapshot!.name, '青磁');
    });

    testWidgets('調合を変えて保存するとダイアログが出て、記録も直せる', (tester) async {
      await openEditor(tester, GlazeEditScreen(glaze: glaze));

      await tester.enterText(find.widgetWithText(TextFormField, '10.0'), '12');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(find.text('テストピースの記録の扱い'), findsOneWidget);
      expect(find.textContaining('テストピースが 1 件あります'), findsOneWidget);
      verifyNever(mockFirestoreService.updateGlaze(any));

      await tester.tap(find.text('記録も直す'));
      await tester.pumpAndSettle();

      verify(mockFirestoreService.updateGlaze(any)).called(1);
      final batch =
          verify(
                mockFirestoreService.updateTestPieceFieldsBatch(captureAny),
              ).captured.single
              as Map<String, Map<String, dynamic>>;
      final snapshot = TestPieceSnapshot.tryFromMap(batch['tp1']!['snapshot'])!;
      expect(snapshot.source, 'corrected');
      expect(snapshot.glaze!.recipe, {'m1': 12.0});
    });

    testWidgets('ダイアログで「記録はそのまま」なら釉薬だけを保存する', (tester) async {
      await openEditor(tester, GlazeEditScreen(glaze: glaze));

      await tester.enterText(find.widgetWithText(TextFormField, '10.0'), '12');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('記録はそのまま'));
      await tester.pumpAndSettle();

      verify(mockFirestoreService.updateGlaze(any)).called(1);
      verifyNever(mockFirestoreService.updateTestPieceFieldsBatch(any));
    });

    testWidgets('ダイアログで「キャンセル」なら保存せず編集画面に留まる', (tester) async {
      await openEditor(tester, GlazeEditScreen(glaze: glaze));

      await tester.enterText(find.widgetWithText(TextFormField, '10.0'), '12');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();

      verifyNever(mockFirestoreService.updateGlaze(any));
      expect(find.text('釉薬の編集'), findsOneWidget);
    });

    testWidgets('名前だけを変えたときはダイアログを出さない', (tester) async {
      await openEditor(tester, GlazeEditScreen(glaze: glaze));

      await tester.enterText(find.widgetWithText(TextFormField, '青磁'), '青磁2');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(find.text('テストピースの記録の扱い'), findsNothing);
      final saved =
          verify(mockFirestoreService.updateGlaze(captureAny)).captured.single
              as Glaze;
      expect(saved.name, '青磁2');
      verifyNever(mockFirestoreService.updateTestPieceFieldsBatch(any));
    });
  });
}
