import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/screens/firing_atmosphere_edit_screen.dart';
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

  group('FiringAtmosphereEditScreen Widget Tests', () {
    testWidgets('should display empty form for new atmosphere', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestableWidget(const FiringAtmosphereEditScreen()),
      );

      expect(find.text('雰囲気の新規作成'), findsOneWidget);
      expect(find.text('雰囲気名'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('should populate form for existing atmosphere', (
      WidgetTester tester,
    ) async {
      final atmosphere = FiringAtmosphere(
        id: 'fa1',
        name: 'Existing Atmosphere',
      );

      await tester.pumpWidget(
        createTestableWidget(
          FiringAtmosphereEditScreen(atmosphere: atmosphere),
        ),
      );

      expect(find.text('雰囲気の編集'), findsOneWidget);
      expect(find.text('Existing Atmosphere'), findsOneWidget);
    });

    testWidgets('should save new atmosphere', (WidgetTester tester) async {
      when(
        mockFirestoreService.addFiringAtmosphere(any),
      ).thenAnswer((_) => Future.value());

      await tester.pumpWidget(
        createTestableWidget(const FiringAtmosphereEditScreen()),
      );

      await tester.enterText(find.byType(TextFormField), 'New Atmosphere');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(mockFirestoreService.addFiringAtmosphere(any)).called(1);
    });

    testWidgets('should update existing atmosphere', (
      WidgetTester tester,
    ) async {
      final atmosphere = FiringAtmosphere(id: 'fa1', name: 'Old Name');

      when(
        mockFirestoreService.updateFiringAtmosphere(any),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        createTestableWidget(
          FiringAtmosphereEditScreen(atmosphere: atmosphere),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pumpAndSettle();

      verify(mockFirestoreService.updateFiringAtmosphere(any)).called(1);
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
                      builder: (_) => const FiringAtmosphereEditScreen(),
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

      await tester.enterText(find.byType(TextFormField), 'Changed');
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('変更を破棄しますか？'), findsOneWidget);

      await tester.tap(find.text('破棄'));
      await tester.pumpAndSettle();

      expect(find.byType(FiringAtmosphereEditScreen), findsNothing);
    });
  });
}
