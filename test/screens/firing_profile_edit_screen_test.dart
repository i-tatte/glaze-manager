import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/screens/firing_profile_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
  });

  Widget createTestableWidget(Widget child) {
    return Provider<FirestoreService>(
      create: (_) => mockFirestoreService,
      child: MaterialApp(home: child),
    );
  }

  group('FiringProfileEditScreen Widget Tests', () {
    testWidgets('should display empty form for new profile', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestableWidget(const FiringProfileEditScreen()),
      );

      expect(find.text('プロファイルの新規作成'), findsOneWidget);
      expect(find.text('プロファイル名'), findsOneWidget);
      expect(
        find.text('焼成データ (焼成開始からの経過時間(分),温度(℃)をカンマ区切りで入力)'),
        findsOneWidget,
      );
      expect(find.text('火入れ還元'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('should populate form for existing profile', (
      WidgetTester tester,
    ) async {
      final profile = FiringProfile(
        id: 'fp1',
        name: 'Existing Profile',
        curveData: '30,100\n60,200',
        isReduction: true,
        reductionStartTemp: 900,
        reductionEndTemp: 1000,
      );

      await tester.pumpWidget(
        createTestableWidget(FiringProfileEditScreen(profile: profile)),
      );

      expect(find.text('プロファイルの編集'), findsOneWidget);
      expect(find.text('Existing Profile'), findsOneWidget);
      expect(find.text('30,100\n60,200'), findsOneWidget);
      expect(find.text('火入れ開始温度 (°C)'), findsOneWidget);
      expect(find.text('900'), findsOneWidget);
    });

    testWidgets('should show reduction fields when checkbox is checked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestableWidget(const FiringProfileEditScreen()),
      );

      expect(find.text('火入れ開始温度 (°C)'), findsNothing);

      await tester.tap(find.text('火入れ還元'));
      await tester.pump();

      expect(find.text('火入れ開始温度 (°C)'), findsOneWidget);
      expect(find.text('火入れ終了温度 (°C)'), findsOneWidget);
    });

    testWidgets('should validate curve data format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestableWidget(const FiringProfileEditScreen()),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Name');
      await tester.enterText(find.byType(TextFormField).at(1), 'invalid');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(find.text('1行目の形式が正しくありません (例: 30,100)'), findsOneWidget);
    });

    testWidgets('should save new profile', (WidgetTester tester) async {
      when(
        mockFirestoreService.addFiringProfile(any),
      ).thenAnswer((_) => Future.value());

      await tester.pumpWidget(
        createTestableWidget(const FiringProfileEditScreen()),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'New Profile');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(mockFirestoreService.addFiringProfile(any)).called(1);
    });

    testWidgets('should update existing profile', (WidgetTester tester) async {
      final profile = FiringProfile(id: 'fp1', name: 'Old Name');

      when(
        mockFirestoreService.updateFiringProfile(any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        createTestableWidget(FiringProfileEditScreen(profile: profile)),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(mockFirestoreService.updateFiringProfile(any)).called(1);
    });

    testWidgets('should show unsaved changes dialog on pop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        Provider<FirestoreService>(
          create: (_) => mockFirestoreService,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FiringProfileEditScreen(),
                    ),
                  ),
                  child: const Text('Push'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Changed');
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('変更を破棄しますか？'), findsOneWidget);

      await tester.tap(find.text('破棄'));
      await tester.pumpAndSettle();

      expect(find.byType(FiringProfileEditScreen), findsNothing);
    });
  });
}
