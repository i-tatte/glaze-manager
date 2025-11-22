import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/screens/firing_atmosphere_list_screen.dart';
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

  group('FiringAtmosphereListScreen Widget Tests', () {
    testWidgets('should display loading indicator when waiting', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        createTestableWidget(const FiringAtmosphereListScreen()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty message when no atmospheres', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        createTestableWidget(const FiringAtmosphereListScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('焼成雰囲気が登録されていません。\n右下のボタンから追加してください。'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('should display list of atmospheres', (
      WidgetTester tester,
    ) async {
      final atmospheres = [
        FiringAtmosphere(id: 'fa1', name: 'Atmosphere 1'),
        FiringAtmosphere(id: 'fa2', name: 'Atmosphere 2'),
      ];

      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(atmospheres));

      await tester.pumpWidget(
        createTestableWidget(const FiringAtmosphereListScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atmosphere 1'), findsOneWidget);
      expect(find.text('Atmosphere 2'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('should show delete confirmation dialog', (
      WidgetTester tester,
    ) async {
      final atmospheres = [FiringAtmosphere(id: 'fa1', name: 'Atmosphere 1')];

      when(
        mockFirestoreService.getFiringAtmospheres(),
      ).thenAnswer((_) => Stream.value(atmospheres));
      when(
        mockFirestoreService.deleteFiringAtmosphere('fa1'),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        createTestableWidget(const FiringAtmosphereListScreen()),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('削除の確認'), findsOneWidget);
      expect(find.text('「Atmosphere 1」を本当に削除しますか？'), findsOneWidget);

      // Tap delete in dialog
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      verify(mockFirestoreService.deleteFiringAtmosphere('fa1')).called(1);
    });
  });
}
