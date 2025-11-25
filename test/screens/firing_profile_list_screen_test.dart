import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/screens/firing_profile_list_screen.dart';
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

  group('FiringProfileListScreen Widget Tests', () {
    testWidgets('should display loading indicator when waiting', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        createTestableWidget(const FiringProfileListScreen()),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display empty message when no profiles', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        createTestableWidget(const FiringProfileListScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('焼成プロファイルが登録されていません。\n右下のボタンから追加してください。'),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('should display list of profiles', (WidgetTester tester) async {
      final profiles = [
        FiringProfile(id: 'fp1', name: 'Profile 1'),
        FiringProfile(id: 'fp2', name: 'Profile 2'),
      ];

      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(profiles));

      await tester.pumpWidget(
        createTestableWidget(const FiringProfileListScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile 1'), findsOneWidget);
      expect(find.text('Profile 2'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('should show delete confirmation dialog', (
      WidgetTester tester,
    ) async {
      final profiles = [FiringProfile(id: 'fp1', name: 'Profile 1')];

      when(
        mockFirestoreService.getFiringProfiles(),
      ).thenAnswer((_) => Stream.value(profiles));
      when(
        mockFirestoreService.deleteFiringProfile('fp1'),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        createTestableWidget(const FiringProfileListScreen()),
      );
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.text('削除の確認'), findsOneWidget);
      expect(find.text('「Profile 1」を本当に削除しますか？'), findsOneWidget);

      // Tap delete in dialog
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      verify(mockFirestoreService.deleteFiringProfile('fp1')).called(1);
    });
  });
}
