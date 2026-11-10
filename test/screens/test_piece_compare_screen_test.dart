import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app_material;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/test_piece_compare_screen.dart';
import 'package:glaze_manager/widgets/common/rating_stars.dart';
import 'package:glaze_manager/widgets/common/recipe_diff_table.dart';
import 'package:mockito/mockito.dart';

import 'main_tab_screen_test.mocks.dart';

void main() {
  late MockFirestoreService mockFirestoreService;

  Glaze glaze(String id, String name, Map<String, double> recipe) => Glaze(
    id: id,
    name: name,
    recipe: recipe,
    tags: [],
    createdAt: Timestamp.now(),
  );

  TestPiece piece(
    String id, {
    String glazeId = 'g1',
    String clayId = 'c1',
    String? note,
    String? label,
    int? rating,
    String? firingId,
    TestPieceSnapshot? snapshot,
  }) => TestPiece(
    id: id,
    glazeId: glazeId,
    clayId: clayId,
    note: note,
    label: label,
    rating: rating,
    firingId: firingId,
    snapshot: snapshot,
    createdAt: Timestamp.now(),
  );

  void stub({
    required List<TestPiece> pieces,
    List<Glaze> glazes = const [],
    List<Firing> firings = const [],
  }) {
    when(
      mockFirestoreService.getTestPieces(),
    ).thenAnswer((_) => Stream.value(pieces));
    when(
      mockFirestoreService.getGlazes(),
    ).thenAnswer((_) => Stream.value(glazes));
    when(mockFirestoreService.getClays()).thenAnswer(
      (_) => Stream.value([
        Clay(id: 'c1', name: '白土', order: 0),
        Clay(id: 'c2', name: '赤土', order: 1),
      ]),
    );
    when(
      mockFirestoreService.getFirings(),
    ).thenAnswer((_) => Stream.value(firings));
  }

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    when(
      mockFirestoreService.getMaterials(),
    ).thenAnswer((_) => Stream.value(<app_material.Material>[]));
    when(
      mockFirestoreService.getFiringAtmospheres(),
    ).thenAnswer((_) => Stream.value(<FiringAtmosphere>[]));
    when(
      mockFirestoreService.getFiringProfiles(),
    ).thenAnswer((_) => Stream.value(<FiringProfile>[]));
  });

  Future<void> pumpScreen(WidgetTester tester, List<String> ids) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(mockFirestoreService),
          authStateChangesProvider.overrideWith(
            (ref) => Stream<User?>.value(null),
          ),
        ],
        child: MaterialApp(home: TestPieceCompareScreen(testPieceIds: ids)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// ラベル [label] の行が、行全体の背景を塗られているか
  bool isHighlighted(WidgetTester tester, String label) {
    final context = tester.element(find.byType(Scaffold).first);
    final highlight = Theme.of(context).colorScheme.secondaryContainer;
    return find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color == highlight,
          ),
        )
        .evaluate()
        .isNotEmpty;
  }

  testWidgets('値の違う行だけを塗る', (tester) async {
    stub(
      pieces: [
        piece('tp1', glazeId: 'g1', clayId: 'c1', note: '同じ備考'),
        piece('tp2', glazeId: 'g2', clayId: 'c2', note: '同じ備考'),
      ],
      glazes: [
        glaze('g1', '青磁', {'m1': 100}),
        glaze('g2', '織部', {'m1': 100}),
      ],
    );
    await pumpScreen(tester, ['tp1', 'tp2']);

    expect(find.text('青磁'), findsWidgets);
    expect(find.text('織部'), findsWidgets);
    expect(isHighlighted(tester, '釉薬'), isTrue);
    expect(isHighlighted(tester, '素地土'), isTrue);
    // 備考は両方とも同じ
    expect(find.text('同じ備考'), findsNWidgets(2));
    expect(isHighlighted(tester, '備考'), isFalse);
  });

  testWidgets('値のない項目は「—」にし、値のない列がある行は塗らない', (tester) async {
    stub(
      pieces: [
        piece('tp1', label: 'A-1', rating: 4),
        piece('tp2', label: null, rating: null),
      ],
      glazes: [
        glaze('g1', '青磁', {'m1': 100}),
      ],
    );
    await pumpScreen(tester, ['tp1', 'tp2']);

    // 番号と評価は片方にしか記録がない
    expect(find.text('A-1'), findsOneWidget);
    expect(find.byType(RatingStars), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(isHighlighted(tester, '番号'), isFalse);
    expect(isHighlighted(tester, '評価'), isFalse);
  });

  testWidgets('すべての列で値のない行は出さない', (tester) async {
    stub(
      pieces: [piece('tp1'), piece('tp2')],
      glazes: [
        glaze('g1', '青磁', {'m1': 100}),
      ],
    );
    await pumpScreen(tester, ['tp1', 'tp2']);

    for (final label in ['評価', '番号', '焼成日', '窯', '焼成雰囲気', '追加釉薬', '備考']) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('釉薬'), findsOneWidget);
    expect(find.text('素地土'), findsOneWidget);
  });

  testWidgets('焼成回の項目は焼成回から解決して並べる', (tester) async {
    stub(
      pieces: [
        piece('tp1', firingId: 'f1'),
        piece('tp2', firingId: 'f2'),
        piece('tp3'),
      ],
      glazes: [
        glaze('g1', '青磁', {'m1': 100}),
      ],
      firings: [
        Firing(
          id: 'f1',
          firedOn: Firing.noonOf(DateTime(2026, 11, 8)),
          kilnName: '電気窯',
          createdAt: Timestamp.now(),
        ),
        Firing(
          id: 'f2',
          firedOn: Firing.noonOf(DateTime(2026, 11, 9)),
          createdAt: Timestamp.now(),
        ),
      ],
    );
    await pumpScreen(tester, ['tp1', 'tp2', 'tp3']);

    expect(find.text('2026/11/8'), findsOneWidget);
    expect(find.text('2026/11/9'), findsOneWidget);
    expect(find.text('電気窯'), findsOneWidget);
    expect(isHighlighted(tester, '焼成日'), isTrue);
    // 窯は 2 列に記録がないが、記録のある列は 1 つだけなので塗らない
    expect(isHighlighted(tester, '窯'), isFalse);
  });

  testWidgets('調合は写しを優先し、釉薬が削除されていても並べる', (tester) async {
    TestPieceSnapshot snapshotOf(String name, double amount) =>
        TestPieceSnapshot(
          glaze: GlazeSnapshot(
            glazeId: 'deleted',
            name: name,
            lines: [
              RecipeLine(
                materialId: 'm1',
                name: '長石',
                category: 'base',
                amount: amount,
              ),
              RecipeLine(
                materialId: 'm2',
                name: '石灰',
                category: 'base',
                amount: 100 - amount,
              ),
            ],
          ),
          source: SnapshotSource.saved,
          takenAt: Timestamp.now(),
        );
    stub(
      pieces: [
        piece('tp1', glazeId: 'deleted', snapshot: snapshotOf('古い釉薬', 80)),
        piece('tp2', glazeId: 'g1'),
      ],
      glazes: [
        glaze('g1', '青磁', {'m1': 50, 'm2': 50}),
      ],
    );
    await pumpScreen(tester, ['tp1', 'tp2']);

    expect(find.text('調合'), findsOneWidget);
    expect(find.byType(RecipeDiffTable), findsOneWidget);
    // 原料が現存しないので写しの名前で表示する
    expect(find.text('長石'), findsOneWidget);
    expect(find.text('石灰'), findsOneWidget);
    expect(find.text('80 (80.0%)'), findsOneWidget);
    expect(find.text('50 (50.0%)'), findsNWidgets(2));
  });

  testWidgets('見つからない ID は列から除く', (tester) async {
    stub(
      pieces: [piece('tp1'), piece('tp2')],
      glazes: [
        glaze('g1', '青磁', {'m1': 100}),
      ],
    );
    await pumpScreen(tester, ['tp1', 'missing', 'tp2']);

    // 写真の行は列ごとに 1 つ
    expect(find.byIcon(Icons.photo), findsNWidgets(2));
  });
}
