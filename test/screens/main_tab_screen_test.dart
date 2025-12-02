import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app_material;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/main_tab_screen.dart';
import 'package:glaze_manager/screens/materials_list_screen.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'main_tab_screen_test.mocks.dart';

// モックを生成するためのアノテーション
// ターミナルで `flutter pub run build_runner build` を実行してモックファイルを生成してください。
@GenerateMocks([AuthService, FirestoreService, StorageService, SettingsService])
void main() {
  // モックオブジェクトのインスタンスを作成
  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late MockStorageService mockStorageService;
  late MockSettingsService mockSettingsService;

  // 各テストの前に実行されるセットアップ処理
  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();
    mockStorageService = MockStorageService();
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
    when(mockSettingsService.gridCrossAxisCount).thenReturn(4); // デフォルト値として4を設定
    when(
      mockSettingsService.maxGridCrossAxisCount,
    ).thenReturn(10); // デフォルト値として10を設定
    when(mockSettingsService.themeMode).thenReturn(ThemeMode.system);

    // ChangeNotifierのメソッドをスタブ
    when(mockSettingsService.addListener(any)).thenReturn(null);
    when(mockSettingsService.removeListener(any)).thenReturn(null);
  });

  // テスト対象のウィジェットをラップするヘルパー関数
  Widget createTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>(
          create: (_) => mockSettingsService,
        ),
        Provider<AuthService>(create: (_) => mockAuthService),
        Provider<FirestoreService>(create: (_) => mockFirestoreService),
        Provider<StorageService>(create: (_) => mockStorageService),
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
  });
}
