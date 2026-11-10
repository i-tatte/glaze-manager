import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/recipe_snapshot.dart';
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

    when(
      mockFirestoreService.getFirings(),
    ).thenAnswer((_) => Stream.value(<Firing>[]));
    mockStorageService = MockStorageService();
    // 保存時に調合の写しを作るため、編集画面は原料を購読する
    when(
      mockFirestoreService.getMaterials(),
    ).thenAnswer((_) => Stream.value(<app.Material>[]));
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

      // 備考の欄はフォームの下のほうにあり、画面外では組み立てられないので
      // 見えるところまで送ってから入力する
      final noteField = find.widgetWithText(TextFormField, '備考\n\n\n');
      await tester.scrollUntilVisible(
        noteField,
        200,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(noteField, '備考を直した');
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
      // 写しがまだないので、このとき写しを取る
      final snapshot = TestPieceSnapshot.tryFromMap(captured['snapshot'])!;
      expect(snapshot.source, 'saved');
      expect(snapshot.glaze!.name, 'Glaze 1');
      expect(snapshot.clayName, 'Clay 1');
    });

    testWidgets('写しを持つテストピースの備考だけ変えたときは写しを送らない', (WidgetTester tester) async {
      final testPiece = TestPiece(
        id: 'tp1',
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
        snapshot: TestPieceSnapshot(
          glaze: GlazeSnapshot(glazeId: 'g1', name: '記録時', lines: const []),
          clayName: '記録時の素地土',
          source: SnapshotSource.saved,
          takenAt: Timestamp.now(),
        ),
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

      // 備考の欄はフォームの下のほうにあり、画面外では組み立てられないので
      // 見えるところまで送ってから入力する
      final noteField = find.widgetWithText(TextFormField, '備考\n\n\n');
      await tester.scrollUntilVisible(
        noteField,
        200,
        scrollable: find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(noteField, '備考を直した');
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      final captured =
          verify(
                mockFirestoreService.updateTestPieceFields('tp1', captureAny),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['note'], '備考を直した');
      expect(captured.containsKey('snapshot'), isFalse);
    });
  });

  group('評価・番号・焼成回', () {
    final firing = Firing(
      id: 'f1',
      firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
      kilnName: '電気窯',
      firingAtmosphereId: 'a1',
      atmosphereName: '還元',
      profile: const FiringProfileSnapshot(name: '本焼き'),
      createdAt: Timestamp.now(),
    );

    setUp(() {
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
      when(mockFirestoreService.getFiringProfiles()).thenAnswer(
        (_) => Stream.value([FiringProfile(id: 'fp1', name: 'Profile 1')]),
      );
      when(mockFirestoreService.getFiringAtmospheres()).thenAnswer(
        (_) => Stream.value([FiringAtmosphere(id: 'fa1', name: '酸化')]),
      );
      when(
        mockFirestoreService.getFirings(),
      ).thenAnswer((_) => Stream.value([firing]));
      when(
        mockFirestoreService.updateTestPieceFields(any, any),
      ).thenAnswer((_) async {});
    });

    /// フォーム全体が画面に収まるよう縦長の画面にする
    void useTallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    /// 編集画面をボタンから開く (保存で pop できるように)
    Future<void> open(WidgetTester tester, Widget screen) async {
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

    Future<Map<String, dynamic>> saveAndCapture(WidgetTester tester) async {
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      return verify(
            mockFirestoreService.updateTestPieceFields('tp1', captureAny),
          ).captured.single
          as Map<String, dynamic>;
    }

    testWidgets('番号と評価を保存する', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            rating: 2,
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsNWidgets(2));
      await tester.enterText(
        find.widgetWithText(TextFormField, '番号'),
        ' 1108-3 ',
      );
      await tester.tap(find.byIcon(Icons.star_border).at(1)); // 4 番目の星

      final captured = await saveAndCapture(tester);
      expect(captured['label'], '1108-3');
      expect(captured['rating'], 4);
    });

    testWidgets('焼成回を選んでいると、雰囲気とプロファイルの選択を隠して焼成回の値を出す', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            firingId: 'f1',
          ),
        ),
      );

      expect(find.text('2026/11/8 電気窯'), findsOneWidget);
      expect(find.text('焼成雰囲気を選択 (任意)'), findsNothing);
      expect(find.text('還元'), findsOneWidget);
      expect(find.text('本焼き'), findsOneWidget);
    });

    testWidgets('焼成回を選んで保存すると、雰囲気とプロファイルの参照は持たない', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            firingAtmosphereId: 'fa1',
            firingProfileId: 'fp1',
            createdAt: Timestamp.now(),
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, '焼成回'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026/11/8 電気窯').last);
      await tester.pumpAndSettle();

      final captured = await saveAndCapture(tester);
      expect(captured['firingId'], 'f1');
      expect(captured['firingAtmosphereId'], isNull);
      expect(captured['firingProfileId'], isNull);
    });

    testWidgets('焼成回を「（なし）」に戻して保存すると firingId を消す', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            firingId: 'f1',
          ),
        ),
      );

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, '焼成回'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('（なし）').last);
      await tester.pumpAndSettle();

      // 従来の 2 つの選択が現れる
      expect(find.text('焼成雰囲気を選択 (任意)'), findsOneWidget);

      final captured = await saveAndCapture(tester);
      expect(captured.containsKey('firingId'), isTrue);
      expect(captured['firingId'], isNull);
    });

    testWidgets('削除済みの焼成回を参照していても開ける', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            firingId: 'f-deleted',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('不明な焼成回'), findsOneWidget);
      expect(find.text('不明'), findsNWidgets(2));
    });

    testWidgets('削除済みの雰囲気・プロファイルを参照していても開ける', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            firingAtmosphereId: 'fa-deleted',
            firingProfileId: 'fp-deleted',
            createdAt: Timestamp.now(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('不明な焼成雰囲気'), findsOneWidget);
      expect(find.text('不明な焼成プロファイル'), findsOneWidget);
    });

    testWidgets('initialFiringId を渡すと、その焼成回を選んだ状態で開く', (tester) async {
      useTallView(tester);
      await open(tester, const TestPieceEditScreen(initialFiringId: 'f1'));

      expect(find.text('2026/11/8 電気窯'), findsOneWidget);
      expect(find.text('焼成雰囲気を選択 (任意)'), findsNothing);
    });
  });
}
