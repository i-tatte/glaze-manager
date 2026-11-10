import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/firing_list_screen.dart';
import 'package:mockito/mockito.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    when(
      mockFirestoreService.getTestPieces(),
    ).thenAnswer((_) => Stream.value(<TestPiece>[]));
    when(
      mockFirestoreService.getFiringAtmospheres(),
    ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
  });

  Widget createTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockFirestoreService),
        authStateChangesProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('FiringListScreen Widget Tests', () {
    testWidgets('読み込み中はインジケータを出す', (tester) async {
      when(
        mockFirestoreService.getFirings(),
      ).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(createTestableWidget(const FiringListScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('焼成回がなければ案内を出す', (tester) async {
      when(
        mockFirestoreService.getFirings(),
      ).thenAnswer((_) => Stream.value(<Firing>[]));

      await tester.pumpWidget(createTestableWidget(const FiringListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('焼成回が登録されていません。\n右下のボタンから追加してください。'), findsOneWidget);
    });

    testWidgets('題に表示名、副題に雰囲気名と枚数、写真待ちの枚数を出す', (tester) async {
      final firing = Firing(
        id: 'f1',
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        kilnName: '電気窯',
        firingAtmosphereId: 'a1',
        atmosphereName: '還元 (写し)',
        createdAt: Timestamp.now(),
      );
      when(
        mockFirestoreService.getFirings(),
      ).thenAnswer((_) => Stream.value([firing]));
      when(mockFirestoreService.getFiringAtmospheres()).thenAnswer(
        (_) => Stream.value([FiringAtmosphere(id: 'a1', name: '還元')]),
      );
      when(mockFirestoreService.getTestPieces()).thenAnswer(
        (_) => Stream.value([
          TestPiece(
            id: 'tp1',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            firingId: 'f1',
            imageUrl: 'http://example.com/a.png',
          ),
          TestPiece(
            id: 'tp2',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
            firingId: 'f1',
          ),
          TestPiece(
            id: 'tp3',
            glazeId: 'g1',
            clayId: 'c1',
            createdAt: Timestamp.now(),
          ),
        ]),
      );

      await tester.pumpWidget(createTestableWidget(const FiringListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('2026/11/8 電気窯'), findsOneWidget);
      expect(find.text('還元 ・ 2 枚（写真待ち 1 枚）'), findsOneWidget);
    });

    testWidgets('写真待ちがなければ枚数だけを出す', (tester) async {
      final firing = Firing(
        id: 'f1',
        firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
        createdAt: Timestamp.now(),
      );
      when(
        mockFirestoreService.getFirings(),
      ).thenAnswer((_) => Stream.value([firing]));

      await tester.pumpWidget(createTestableWidget(const FiringListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('未設定 ・ 0 枚'), findsOneWidget);
    });
  });
}
