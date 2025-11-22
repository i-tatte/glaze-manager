import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/screens/clay_edit_screen.dart';
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

  group('ClayEditScreen Widget Tests', () {
    testWidgets('should display empty form for new clay', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const ClayEditScreen()));

      expect(find.text('素地土の新規作成'), findsOneWidget);
      expect(find.text('素地土名'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('should populate form for existing clay', (
      WidgetTester tester,
    ) async {
      final clay = Clay(id: 'c1', name: 'Existing Clay', order: 1);

      await tester.pumpWidget(createTestableWidget(ClayEditScreen(clay: clay)));

      expect(find.text('素地土の編集'), findsOneWidget);
      expect(find.text('Existing Clay'), findsOneWidget);
    });

    testWidgets('should save new clay', (WidgetTester tester) async {
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value([])); // For order calculation
      when(mockFirestoreService.addClay(any)).thenAnswer((_) => Future.value());

      await tester.pumpWidget(createTestableWidget(const ClayEditScreen()));

      await tester.enterText(find.byType(TextFormField), 'New Clay');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump(); // Start save
      await tester.pumpAndSettle(); // Finish save and pop

      verify(mockFirestoreService.addClay(any)).called(1);
    });

    testWidgets('should update existing clay', (WidgetTester tester) async {
      final clay = Clay(id: 'c1', name: 'Old Name', order: 1);

      when(mockFirestoreService.updateClay(any)).thenAnswer((_) async {});

      await tester.pumpWidget(createTestableWidget(ClayEditScreen(clay: clay)));

      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(mockFirestoreService.updateClay(any)).called(1);
    });

    testWidgets('should show unsaved changes dialog on pop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestableWidget(const ClayEditScreen()));

      // Make changes
      await tester.enterText(find.byType(TextFormField), 'Changed');
      await tester.pump();

      // Try to pop
      // Note: tester.pageBack() might not trigger PopScope correctly in tests depending on setup,
      // but let's try standard back button simulation if available or just verify PopScope logic via a back button if present.
      // Since it's a top level scaffold in test, we might need to simulate system back.
      // However, usually we just test if the dialog appears when we try to pop.

      // Ideally we wrap in a Navigator to test pop.
      await tester.pumpWidget(
        Provider<FirestoreService>(
          create: (_) => mockFirestoreService,
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => const ClayEditScreen()),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Changed');
      await tester.pump();

      // Simulate back button
      // await tester.pageBack(); // This throws if no back stack.
      // Actually, since we are at root of MaterialApp, pageBack might not work as expected for PopScope testing without a pushed route.

      // Let's push it properly.
      await tester.pumpWidget(
        Provider<FirestoreService>(
          create: (_) => mockFirestoreService,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClayEditScreen()),
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

      await tester.enterText(find.byType(TextFormField), 'Changed');
      await tester.pump();

      await tester.tap(find.byTooltip('Back')); // AppBar back button
      await tester.pumpAndSettle();

      expect(find.text('変更を破棄しますか？'), findsOneWidget);

      await tester.tap(find.text('破棄'));
      await tester.pumpAndSettle();

      expect(find.byType(ClayEditScreen), findsNothing);
    });
  });
}
