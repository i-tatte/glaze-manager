import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

import '../helpers/fake_upload_queue.dart';
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

  group('写真のアップロード待ち', () {
    late FakeUploadQueue fakeQueue;

    setUp(() {
      fakeQueue = FakeUploadQueue();
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
      when(
        mockStorageService.getUploadPath(
          testPieceId: anyNamed('testPieceId'),
          name: anyNamed('name'),
        ),
      ).thenAnswer(
        (invocation) =>
            'users/u/test_pieces/images/'
            '${invocation.namedArguments[#testPieceId]}/'
            '${invocation.namedArguments[#name]}',
      );
    });

    Future<void> open(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFirestoreService),
            storageServiceProvider.overrideWithValue(mockStorageService),
            authStateChangesProvider.overrideWith(
              (ref) => Stream<User?>.value(null),
            ),
            uploadQueueProvider.overrideWith((_) => fakeQueue),
          ],
          child: MaterialApp(
            home: Builder(
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
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('新しい画像を持って保存すると待ちに入れ、画面からは送らない', (tester) async {
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
          initialNewImage: (
            fileName: 'new.jpg',
            bytes: Uint8List.fromList(_onePixelPng),
          ),
        ),
      );

      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(fakeQueue.enqueued, hasLength(1));
      expect(fakeQueue.enqueued.single.testPieceId, 'tp1');
      expect(fakeQueue.enqueued.single.fileName, 'new.jpg');
      expect(
        fakeQueue.enqueued.single.storagePath,
        'users/u/test_pieces/images/tp1/new.jpg',
      );
      // 文書には待ちと同じパスを書く
      final captured =
          verify(
                mockFirestoreService.updateTestPieceFields('tp1', captureAny),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['imagePath'], 'users/u/test_pieces/images/tp1/new.jpg');
      verifyNever(
        mockStorageService.uploadTestPieceImage(
          testPieceId: anyNamed('testPieceId'),
          name: anyNamed('name'),
          bytes: anyNamed('bytes'),
          mimeType: anyNamed('mimeType'),
        ),
      );
      // 画面は閉じている
      expect(find.text('テストピースの編集'), findsNothing);
    });

    testWidgets('新しい画像がなければ待ちに入れない', (tester) async {
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ),
      );
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(fakeQueue.enqueued, isEmpty);
      // 送るものがないので、書き込みが完了しても送信は呼ばない
      expect(fakeQueue.processAllCount, 0);
    });

    testWidgets('文書の書き込みが完了したら、待たせていた写真をすぐに送り始める', (tester) async {
      // enqueue の直後の試行は、文書がまだ未送信のうちに走る。書き込みの完了で
      // 送信を呼ばないと、写真は数秒後の再試行まで送られない
      final written = Completer<void>();
      when(
        mockFirestoreService.updateTestPieceFields(any, any),
      ).thenAnswer((_) => written.future);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
          initialNewImage: (
            fileName: 'new.jpg',
            bytes: Uint8List.fromList(_onePixelPng),
          ),
        ),
      );

      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();
      // 画面は書き込みの完了を待たずに閉じている
      expect(find.text('テストピースの編集'), findsNothing);
      expect(fakeQueue.enqueued, hasLength(1));
      expect(fakeQueue.processAllCount, 0);

      written.complete();
      await tester.pumpAndSettle();
      expect(fakeQueue.processAllCount, 1);
    });

    testWidgets('文書の書き込みが失敗したら、失敗を知らせ、送信は呼ばない', (tester) async {
      final written = Completer<void>();
      when(
        mockFirestoreService.updateTestPieceFields(any, any),
      ).thenAnswer((_) => written.future);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
          initialNewImage: (
            fileName: 'new.jpg',
            bytes: Uint8List.fromList(_onePixelPng),
          ),
        ),
      );

      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      written.completeError(Exception('permission-denied'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('保存に失敗しました'), findsOneWidget);
      expect(fakeQueue.processAllCount, 0);
    });

    testWidgets('削除するとアップロード待ちも消す', (tester) async {
      when(
        mockStorageService.deleteAllTestPieceFiles(any),
      ).thenAnswer((_) async {});
      when(mockFirestoreService.deleteTestPiece(any)).thenAnswer((_) async {});
      // 削除は編集画面と詳細画面を閉じるので、間に 1 枚画面を挟む
      await open(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TestPieceEditScreen(
                    testPiece: TestPiece(
                      id: 'tp1',
                      glazeId: 'g1',
                      clayId: 'c1',
                      createdAt: Timestamp.now(),
                    ),
                  ),
                ),
              ),
              child: const Text('detail'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();

      expect(fakeQueue.removed, ['tp1']);
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

  group('入口と連続登録', () {
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
          Glaze(
            id: 'g2',
            name: 'Glaze 2',
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
      when(mockFirestoreService.createTestPieceId()).thenReturn('new1');
      when(
        mockFirestoreService.setTestPiece(any, any),
      ).thenAnswer((_) async {});
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

    testWidgets('新規作成の初期値が反映される', (tester) async {
      useTallView(tester);
      await open(
        tester,
        const TestPieceEditScreen(
          initialGlazeId: 'g1',
          initialAdditionalGlazeIds: ['g2'],
          initialClayId: 'c1',
          initialFiringAtmosphereId: 'fa1',
          initialFiringProfileId: 'fp1',
          initialLabel: '1108-03',
        ),
      );

      expect(find.text('Glaze 1'), findsOneWidget);
      expect(find.text('Glaze 2'), findsOneWidget);
      expect(find.text('Clay 1'), findsOneWidget);
      expect(find.text('酸化'), findsOneWidget);
      expect(find.text('Profile 1'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1108-03'), findsOneWidget);
      // 初期値だけでは未保存の変更として扱わない
      final popScope = tester.widget<PopScope>(
        find.byWidgetPredicate((w) => w is PopScope).last,
      );
      expect(popScope.canPop, isTrue);
    });

    testWidgets('「保存して次を登録」で保存し、条件を引き継いだ新しい編集画面を開く', (tester) async {
      useTallView(tester);
      await open(
        tester,
        const TestPieceEditScreen(
          initialGlazeId: 'g1',
          initialClayId: 'c1',
          initialFiringAtmosphereId: 'fa1',
          initialLabel: '1108-09',
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '備考\n\n\n'),
        'メモ',
      );
      await tester.tap(find.byIcon(Icons.star_border).first);
      await tester.pump();

      await tester.tap(find.text('保存して次を登録'));
      await tester.pumpAndSettle();

      final saved =
          verify(
                mockFirestoreService.setTestPiece('new1', captureAny),
              ).captured.single
              as TestPiece;
      expect(saved.glazeId, 'g1');
      expect(saved.clayId, 'c1');
      expect(saved.label, '1108-09');
      expect(saved.rating, 1);

      // 新しい編集画面が、釉薬・素地土・焼成雰囲気と番号の次の候補を引き継いで開く
      expect(find.text('テストピースの新規作成'), findsOneWidget);
      expect(find.byType(TestPieceEditScreen), findsOneWidget);
      expect(find.text('Glaze 1'), findsOneWidget);
      expect(find.text('Clay 1'), findsOneWidget);
      expect(find.text('酸化'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1108-10'), findsOneWidget);
      // 備考と評価は引き継がない
      expect(find.text('メモ'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);

      // 置き換えたので、戻ると開く前の画面に戻る
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('焼成回を選んでいれば、焼成回を引き継ぐ', (tester) async {
      useTallView(tester);
      when(mockFirestoreService.getFirings()).thenAnswer(
        (_) => Stream.value([
          Firing(
            id: 'f1',
            firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
            kilnName: '電気窯',
            createdAt: Timestamp.now(),
          ),
        ]),
      );
      await open(
        tester,
        const TestPieceEditScreen(
          initialGlazeId: 'g1',
          initialClayId: 'c1',
          initialFiringId: 'f1',
        ),
      );

      await tester.tap(find.text('保存して次を登録'));
      await tester.pumpAndSettle();

      verify(mockFirestoreService.setTestPiece('new1', any)).called(1);
      expect(find.text('テストピースの新規作成'), findsOneWidget);
      expect(find.text('2026/11/8 電気窯'), findsOneWidget);
      expect(find.text('焼成雰囲気を選択 (任意)'), findsNothing);
    });

    testWidgets('検証に通らなければ「保存して次を登録」で次へ進まない', (tester) async {
      useTallView(tester);
      await open(tester, const TestPieceEditScreen(initialGlazeId: 'g1'));

      await tester.tap(find.text('保存して次を登録'));
      await tester.pumpAndSettle();

      verifyNever(mockFirestoreService.setTestPiece(any, any));
      expect(find.text('素地土名を選択してください'), findsOneWidget);
    });

    testWidgets('既存のテストピースの編集では連続登録のボタンを出さない', (tester) async {
      useTallView(tester);
      await open(
        tester,
        TestPieceEditScreen(
          testPiece: TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ),
      );

      expect(find.text('保存して次を登録'), findsNothing);
      expect(find.text('複数の写真を選んで連続登録'), findsNothing);
    });

    testWidgets('新規作成では連続登録と一括選択のボタンを出す', (tester) async {
      useTallView(tester);
      await open(tester, const TestPieceEditScreen());

      expect(find.text('保存して次を登録'), findsOneWidget);
      expect(find.text('複数の写真を選んで連続登録'), findsOneWidget);
      expect(find.text('写真を選択'), findsOneWidget);
    });
  });
}

/// 1x1 の透明な PNG (プレビューの Image.memory が読めるもの)
const List<int> _onePixelPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
