import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app_material;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/models/test_piece_group_key.dart';
import 'package:glaze_manager/screens/main_tab_screen.dart';
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'main_tab_screen_test.mocks.dart';

// モックを生成するためのアノテーション
// ターミナルで `flutter pub run build_runner build` を実行してモックファイルを生成してください。
@GenerateMocks([AuthService, FirestoreService, StorageService, SettingsService])
void main() {
  // モックオブジェクトのインスタンスを作成
  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late MockSettingsService mockSettingsService;

  // 各テストの前に実行されるセットアップ処理
  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();

    when(
      mockFirestoreService.getFirings(),
    ).thenAnswer((_) => Stream.value(<Firing>[]));
    mockSettingsService = MockSettingsService();

    // モックのデフォルトの振る舞いを設定
    // getGlazes()などがStreamを返すため、空のStreamを返すように設定
    when(
      mockFirestoreService.getTestPieces(),
    ).thenAnswer((_) => Stream.value(<TestPiece>[]));
    when(
      mockFirestoreService.getGlazes(),
    ).thenAnswer((_) => Stream.value(<Glaze>[]));
    when(
      mockFirestoreService.getMaterials(),
    ).thenAnswer((_) => Stream.value(<app_material.Material>[]));
    when(
      mockFirestoreService.getTags(),
    ).thenAnswer((_) => Stream.value(<String>[]));
    when(
      mockFirestoreService.getClays(),
    ).thenAnswer((_) => Stream.value(<Clay>[]));
    when(
      mockFirestoreService.getFiringAtmospheres(),
    ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
    when(
      mockFirestoreService.getFiringProfiles(),
    ).thenAnswer((_) => Stream.value(<FiringProfile>[]));

    // SettingsServiceのgetterをスタブ
    when(mockSettingsService.gridCrossAxisCount).thenReturn(4);
    when(mockSettingsService.maxGridCrossAxisCount).thenReturn(10);
    when(
      mockSettingsService.testPieceGroupKey,
    ).thenReturn(TestPieceGroupKey.none);
    when(mockSettingsService.themeMode).thenReturn(ThemeMode.system);

    // ChangeNotifierのメソッドをスタブ
    when(mockSettingsService.addListener(any)).thenReturn(null);
    when(mockSettingsService.removeListener(any)).thenReturn(null);

    // 設定タブのアカウントセクションが参照する認証状態 (未ログイン扱い)
    when(mockAuthService.user).thenAnswer((_) => Stream<User?>.value(null));
  });

  // テスト対象のウィジェットをラップするヘルパー関数
  Widget createTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
        settingsServiceProvider.overrideWith((_) => mockSettingsService),
        authServiceProvider.overrideWithValue(mockAuthService),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('MainTabScreen Widget Tests', () {
    testWidgets('should display initial screen (TestPieceListScreen)', (
      WidgetTester tester,
    ) async {
      // MainTabScreenをビルド
      await tester.pumpWidget(createTestableWidget(const MainTabScreen()));

      // 初期状態で「テストピース一覧」のタイトルが表示されていることを確認
      expect(find.text('テストピース一覧'), findsOneWidget);
      expect(find.text('釉薬一覧'), findsNothing);
      expect(find.text('原料一覧'), findsNothing);
      // '設定'はBottomNavigationBarのラベルとして表示されるため、ここではチェックしない

      // 初期状態で「テストピース」タブが選択されていることを確認
      final selectedIcon = find.byIcon(Icons.photo_library);
      expect(selectedIcon, findsOneWidget);
    });

    testWidgets('should switch tabs and update AppBar title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const MainTabScreen()));

      // --- 1. 「釉薬」タブをタップ ---
      await tester.tap(find.byIcon(Icons.color_lens_outlined));
      await tester.pumpAndSettle(); // アニメーションの完了を待つ

      // AppBarのタイトルが「釉薬一覧」に変わったことを確認
      expect(find.text('釉薬一覧'), findsOneWidget);
      // 選択中のアイコンが変わったことを確認
      expect(find.byIcon(Icons.color_lens), findsOneWidget);
      // 他のタブのタイトルが表示されていないことを確認
      expect(find.text('テストピース一覧'), findsNothing);

      // --- 2. 「原料」タブをタップ ---
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();

      // AppBarのタイトルが「原料一覧」に変わったことを確認
      expect(find.text('原料一覧'), findsOneWidget);
      expect(find.byIcon(Icons.science), findsOneWidget);

      // --- 3. 「設定」タブをタップ ---
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // AppBarのタイトルが「設定」に変わったことを確認
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('設定')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('should show action buttons only on specific tabs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const MainTabScreen()));

      // 初期状態（テストピース一覧）ではアクションボタンがないことを確認
      expect(find.widgetWithText(TextButton, '編集'), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);

      // 「釉薬一覧」タブに移動
      await tester.tap(find.byIcon(Icons.color_lens_outlined));
      await tester.pumpAndSettle();
      if (tester.takeException() != null) {
        debugPrint('Exception after tap Glaze tab: ${tester.takeException()}');
      }

      // アクションボタンがないことを確認
      expect(find.widgetWithText(TextButton, '編集'), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);

      // 「原料一覧」タブに移動
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      if (tester.takeException() != null) {
        debugPrint(
          'Exception after tap Materials tab: ${tester.takeException()}',
        );
      }

      // 原料一覧画面が表示されていることを確認
      expect(find.byType(MaterialsListScreen), findsOneWidget);

      // 「編集」ボタンが表示されることを確認
      expect(find.widgetWithText(TextButton, '編集'), findsOneWidget);

      // サインアウトボタンがないことを確認
      expect(find.byIcon(Icons.logout), findsNothing);

      // 「設定」タブに移動
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      if (tester.takeException() != null) {
        debugPrint(
          'Exception after tap Settings tab: ${tester.takeException()}',
        );
      }

      // 「編集」ボタンがないことを確認
      expect(find.widgetWithText(TextButton, '編集'), findsNothing);
      // サインアウトボタンが表示されることを確認
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    group('テストピースの比較の選択', () {
      List<TestPiece> pieces(int n) => [
        for (var i = 1; i <= n; i++)
          TestPiece(
            id: 'tp$i',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
      ];

      IconButton compareButton(WidgetTester tester) =>
          tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.compare_arrows),
          );

      testWidgets('長押しで選択すると AppBar が選択用に切り替わる', (tester) async {
        when(
          mockFirestoreService.getTestPieces(),
        ).thenAnswer((_) => Stream.value(pieces(3)));
        await tester.pumpWidget(createTestableWidget(const MainTabScreen()));
        await tester.pumpAndSettle();

        // 通常のアクション
        expect(
          find.byIcon(Icons.local_fire_department_outlined),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.workspaces_outlined), findsOneWidget);
        expect(find.byIcon(Icons.compare_arrows), findsNothing);

        await tester.longPress(find.byType(TestPieceCard).first);
        await tester.pumpAndSettle();

        expect(find.text('1 件選択'), findsOneWidget);
        expect(find.text('テストピース一覧'), findsNothing);
        expect(find.byIcon(Icons.local_fire_department_outlined), findsNothing);
        expect(find.byIcon(Icons.workspaces_outlined), findsNothing);
        // 1 枚では比較できない
        expect(compareButton(tester).onPressed, isNull);

        // 選択中はタップで追加される
        await tester.tap(find.byType(TestPieceCard).at(1));
        await tester.pumpAndSettle();
        expect(find.text('2 件選択'), findsOneWidget);
        expect(compareButton(tester).onPressed, isNotNull);

        // 解除で元に戻る
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text('テストピース一覧'), findsOneWidget);
        expect(find.byIcon(Icons.compare_arrows), findsNothing);
        expect(
          find.byIcon(Icons.local_fire_department_outlined),
          findsOneWidget,
        );
      });

      testWidgets('5 枚目は選択せず、4 枚までと知らせる', (tester) async {
        when(mockSettingsService.gridCrossAxisCount).thenReturn(5);
        when(
          mockFirestoreService.getTestPieces(),
        ).thenAnswer((_) => Stream.value(pieces(5)));
        await tester.pumpWidget(createTestableWidget(const MainTabScreen()));
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(TestPieceCard).at(0));
        await tester.pumpAndSettle();
        for (var i = 1; i < 4; i++) {
          await tester.tap(find.byType(TestPieceCard).at(i));
          await tester.pumpAndSettle();
        }
        expect(find.text('4 件選択'), findsOneWidget);

        await tester.tap(find.byType(TestPieceCard).at(4));
        await tester.pump();

        expect(find.text('比較できるのは 4 枚までです'), findsOneWidget);
        expect(find.text('4 件選択'), findsOneWidget);
      });

      testWidgets('戻る操作は、選択中なら選択の解除だけを行う', (tester) async {
        when(
          mockFirestoreService.getTestPieces(),
        ).thenAnswer((_) => Stream.value(pieces(2)));
        await tester.pumpWidget(createTestableWidget(const MainTabScreen()));
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(TestPieceCard).first);
        await tester.pumpAndSettle();
        expect(find.text('1 件選択'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('テストピース一覧'), findsOneWidget);
        // 終了の案内は出ない
        expect(find.text('もう一度戻るとアプリを終了します'), findsNothing);
      });

      testWidgets('タブを離れると選択を解除する', (tester) async {
        when(
          mockFirestoreService.getTestPieces(),
        ).thenAnswer((_) => Stream.value(pieces(2)));
        await tester.pumpWidget(createTestableWidget(const MainTabScreen()));
        await tester.pumpAndSettle();

        await tester.longPress(find.byType(TestPieceCard).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.color_lens_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.photo_library_outlined));
        await tester.pumpAndSettle();

        expect(find.text('テストピース一覧'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNothing);
      });
    });

    testWidgets('写しを持たない既存のテストピースに一度だけ写しを埋める', (WidgetTester tester) async {
      when(mockFirestoreService.getTestPieces()).thenAnswer(
        (_) => Stream.value([
          TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
          // 主たる釉薬が見つからないものは対象外
          TestPiece(
            id: 'tp2',
            glazeId: 'deleted',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ]),
      );
      when(mockFirestoreService.getGlazes()).thenAnswer(
        (_) => Stream.value([
          Glaze(
            id: 'g1',
            name: '青磁',
            recipe: {'m1': 60},
            tags: [],
            createdAt: Timestamp.now(),
          ),
        ]),
      );
      when(
        mockFirestoreService.updateTestPieceFieldsBatch(any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createTestableWidget(const MainTabScreen()));
      await tester.pumpAndSettle();

      final batch =
          verify(
                mockFirestoreService.updateTestPieceFieldsBatch(captureAny),
              ).captured.single
              as Map<String, Map<String, dynamic>>;
      expect(batch.keys, ['tp1']);
      expect(
        (batch['tp1']!['snapshot'] as Map<String, dynamic>)['source'],
        'backfilled',
      );
    });
  });
}
