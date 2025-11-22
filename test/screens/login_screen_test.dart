import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/screens/login_screen.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();

    // Mock MethodChannel for checkConnectivity
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'check') {
              return ['wifi'];
            }
            return null;
          },
        );
  });

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

      expect(find.widgetWithText(SizedBox, '匿名で始める'), findsOneWidget);
      expect(find.widgetWithText(SizedBox, 'Googleでサインイン'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'should show confirmation dialog for anonymous sign-in and handle cancel',
      (WidgetTester tester) async {
        await tester.pumpWidget(createTestableWidget(const LoginScreen()));

        await tester.tap(find.text('匿名で始める'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('匿名ログインの注意点'), findsOneWidget);

        await tester.tap(find.text('キャンセル'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(mockAuthService.signInAnonymously());
      },
    );

    testWidgets('should call signInAnonymously when confirmed', (
      WidgetTester tester,
    ) async {
      when(
        mockAuthService.signInAnonymously(),
      ).thenAnswer((_) => Future.value());

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      await tester.tap(find.text('匿名で始める'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('匿名で続ける'));
      await tester.pump();

      verify(mockAuthService.signInAnonymously()).called(1);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'should call signInWithGoogle when Google sign-in button is tapped',
      (WidgetTester tester) async {
        when(
          mockAuthService.signInWithGoogle(),
        ).thenAnswer((_) => Future.value());

        await tester.pumpWidget(createTestableWidget(const LoginScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Googleでサインイン'));
        await tester.pump();

        verify(mockAuthService.signInWithGoogle()).called(1);
        await tester.pumpAndSettle();
      },
    );
  });
}
