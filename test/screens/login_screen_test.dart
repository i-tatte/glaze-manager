import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/screens/login_screen.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// main_tab_screen_test.dartで生成されたモックを再利用します
import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;

  // 各テストの前にモックを初期化
  setUp(() {
    mockAuthService = MockAuthService();
  });

  // テスト対象のウィジェットをラップするヘルパー関数
  Widget createTestableWidget(Widget child) {
    return Provider<AuthService>(
      create: (_) => mockAuthService,
      child: MaterialApp(home: child),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('should display initial UI correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // 各ボタンが表示されていることを確認
      expect(find.widgetWithText(SizedBox, '匿名で始める'), findsOneWidget);
      expect(find.widgetWithText(SizedBox, 'Googleでサインイン'), findsOneWidget);
      // ローディングインジケーターが表示されていないことを確認
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'should show confirmation dialog for anonymous sign-in and handle cancel',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestableWidget(const LoginScreen()));

        // 「匿名で始める」ボタンをタップ
        await tester.tap(find.widgetWithText(SizedBox, '匿名で始める'));
        await tester.pumpAndSettle();

        // 確認ダイアログが表示されていることを確認
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('匿名ログインの注意点'), findsOneWidget);

        // 「キャンセル」をタップ
        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();

        // ダイアログが閉じていることを確認
        expect(find.byType(AlertDialog), findsNothing);
        // ログイン処理が呼ばれていないことを確認
        verifyNever(mockAuthService.signInAnonymously());
      },
    );

    testWidgets('should call signInAnonymously when confirmed', (
      WidgetTester tester,
    ) async {
      // signInAnonymouslyが完了しないようにFutureを返す
      when(
        mockAuthService.signInAnonymously(),
      ).thenAnswer((_) => Future.value());

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // 「匿名で始める」ボタンをタップ
      await tester.tap(find.widgetWithText(SizedBox, '匿名で始める'));
      await tester.pumpAndSettle();

      // 「匿名で続ける」をタップ
      await tester.tap(find.text('匿名で続ける'));
      await tester.pump(); // ローディング表示のためにpump

      // ログイン処理が1回呼ばれたことを確認
      verify(mockAuthService.signInAnonymously()).called(1);

      // 処理完了を待つ
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should call signInWithGoogle when Google sign-in button is tapped',
      (WidgetTester tester) async {
        // signInWithGoogleが完了しないようにFutureを返す
        when(
          mockAuthService.signInWithGoogle(),
        ).thenAnswer((_) => Future.value());

        await tester.pumpWidget(createTestableWidget(const LoginScreen()));

        // 「Googleでサインイン」ボタンをタップ
        await tester.tap(find.widgetWithText(SizedBox, 'Googleでサインイン'));
        await tester.pump(); // ローディング表示のためにpump

        // ログイン処理が1回呼ばれたことを確認
        verify(mockAuthService.signInWithGoogle()).called(1);

        // 処理完了を待つ
        await tester.pumpAndSettle();
      },
    );
  });
}
