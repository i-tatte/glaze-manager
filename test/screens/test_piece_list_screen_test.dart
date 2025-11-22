import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/test_piece_list_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;
  late MockSettingsService mockSettingsService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockSettingsService = MockSettingsService();

    // SettingsServiceのモック設定
    when(mockSettingsService.gridCrossAxisCount).thenReturn(2);
    // ChangeNotifierのスタブ
    when(mockSettingsService.addListener(any)).thenReturn(null);
    when(mockSettingsService.removeListener(any)).thenReturn(null);
  });

  Widget createTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => mockFirestoreService),
        ChangeNotifierProvider<SettingsService>.value(
          value: mockSettingsService,
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('TestPieceListScreen Widget Tests', () {
    testWidgets('should display empty state when no test pieces', (
      WidgetTester tester,
    ) async {
      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(<Glaze>[]));
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(<Clay>[]));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value(<TestPiece>[]));

      await tester.pumpWidget(
        createTestableWidget(const TestPieceListScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('テストピースが登録されていません。\n右下のボタンから追加してください。'), findsOneWidget);
    });

    testWidgets('should display list of test pieces', (
      WidgetTester tester,
    ) async {
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
      final testPieces = [
        TestPiece(
          id: 'tp1',
          glazeId: 'g1',
          clayId: 'c1',
          firingProfileId: 'fp1',
          createdAt: Timestamp.now(),
        ),
      ];

      when(
        mockFirestoreService.getGlazes(),
      ).thenAnswer((_) => Stream.value(glazes));
      when(
        mockFirestoreService.getClays(),
      ).thenAnswer((_) => Stream.value(clays));
      when(
        mockFirestoreService.getTestPieces(),
      ).thenAnswer((_) => Stream.value(testPieces));

      await tester.pumpWidget(
        createTestableWidget(const TestPieceListScreen()),
      );
      await tester.pumpAndSettle();

      // TestPieceGrid displays glaze name and clay name
      expect(find.text('Glaze 1'), findsOneWidget);
      expect(find.text('Clay 1'), findsOneWidget);
    });
  });
}
