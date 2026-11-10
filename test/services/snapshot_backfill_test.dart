import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/snapshot_backfill.dart';

void main() {
  final glazeMap = {
    'g1': Glaze(
      id: 'g1',
      name: '青磁',
      recipe: {'m1': 60},
      tags: const [],
      createdAt: Timestamp.now(),
    ),
    'g2': Glaze(
      id: 'g2',
      name: '鉄赤',
      recipe: {'m1': 10},
      tags: const [],
      createdAt: Timestamp.now(),
    ),
  };
  final materialMap = {
    'm1': Material(
      id: 'm1',
      name: '長石',
      order: 0,
      components: {},
      category: MaterialCategory.base,
    ),
  };
  final clayMap = {'c1': Clay(id: 'c1', name: '信楽白', order: 0)};

  TestPiece piece(
    String id,
    String glazeId, {
    List<String> additional = const [],
    TestPieceSnapshot? snapshot,
  }) => TestPiece(
    id: id,
    glazeId: glazeId,
    additionalGlazeIds: additional,
    clayId: 'c1',
    createdAt: Timestamp.now(),
    snapshot: snapshot,
  );

  Map<String, TestPieceSnapshot> plan(List<TestPiece> pieces) =>
      planSnapshotBackfill(
        pieces: pieces,
        glazeMap: glazeMap,
        materialMap: materialMap,
        clayMap: clayMap,
      );

  test('写しのないテストピースだけが対象になる', () {
    final existing = TestPieceSnapshot(
      source: SnapshotSource.saved,
      takenAt: Timestamp.now(),
    );
    final result = plan([
      piece('tp1', 'g1'),
      piece('tp2', 'g1', snapshot: existing),
    ]);
    expect(result.keys, ['tp1']);
    final snapshot = result['tp1']!;
    expect(snapshot.source, 'backfilled');
    expect(snapshot.glaze!.recipe, {'m1': 60.0});
    expect(snapshot.glaze!.lines.single.name, '長石');
    expect(snapshot.clayName, '信楽白');
  });

  test('主たる釉薬が見つからないものは対象外', () {
    expect(plan([piece('tp1', 'deleted')]), isEmpty);
  });

  test('見つからない追加釉薬は写しに含めない', () {
    final result = plan([
      piece('tp1', 'g1', additional: ['deleted', 'g2']),
    ]);
    expect(result['tp1']!.additionalGlazes.map((g) => g.glazeId), ['g2']);
  });
}
