import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';

void main() {
  final materials = {
    'm1': Material(
      id: 'm1',
      name: '長石',
      order: 0,
      components: {},
      category: MaterialCategory.base,
    ),
    'm2': Material(
      id: 'm2',
      name: '酸化鉄',
      order: 1,
      components: {},
      category: MaterialCategory.pigment,
    ),
  };
  final glaze = Glaze(
    id: 'g1',
    name: '青磁',
    registeredName: 'SEIJI',
    recipe: {'m1': 60, 'm2': 2, 'gone': 5},
    tags: const [],
    createdAt: Timestamp.now(),
  );

  group('GlazeSnapshot.capture', () {
    test('釉薬と原料の現在の値を写す', () {
      final snapshot = GlazeSnapshot.capture(glaze, materials);
      expect(snapshot.glazeId, 'g1');
      expect(snapshot.name, '青磁');
      expect(snapshot.registeredName, 'SEIJI');
      expect(snapshot.recipe, {'m1': 60.0, 'm2': 2.0, 'gone': 5.0});
      final iron = snapshot.lines.firstWhere((l) => l.materialId == 'm2');
      expect(iron.name, '酸化鉄');
      expect(iron.category, 'pigment');
    });

    test('見つからない原料は「不明な原料」と base で写す', () {
      final snapshot = GlazeSnapshot.capture(glaze, materials);
      final gone = snapshot.lines.firstWhere((l) => l.materialId == 'gone');
      expect(gone.name, '不明な原料');
      expect(gone.category, 'base');
    });
  });

  group('GlazeSnapshot の読み書き', () {
    test('toMap と fromMap で往復できる', () {
      final snapshot = GlazeSnapshot.capture(glaze, materials);
      final read = GlazeSnapshot.fromMap(snapshot.toMap());
      expect(read.glazeId, snapshot.glazeId);
      expect(read.name, snapshot.name);
      expect(read.registeredName, snapshot.registeredName);
      expect(read.recipe, snapshot.recipe);
      expect(
        read.lines.map((l) => l.name).toList(),
        snapshot.lines.map((l) => l.name).toList(),
      );
    });

    test('整数で保存された量を double として読む', () {
      final read = GlazeSnapshot.fromMap({
        'glazeId': 'g1',
        'name': '青磁',
        'lines': [
          {'materialId': 'm1', 'name': '長石', 'category': 'base', 'amount': 60},
        ],
      });
      expect(read.lines.single.amount, 60.0);
      expect(read.lines.single.amount, isA<double>());
    });

    test('欠損のあるデータを既定値で読む', () {
      final read = GlazeSnapshot.fromMap({
        'lines': [
          {'materialId': 'm1'},
          'not a map',
        ],
      });
      expect(read.glazeId, '');
      expect(read.name, '');
      expect(read.registeredName, isNull);
      expect(read.lines.single.name, '不明な原料');
      expect(read.lines.single.category, 'base');
      expect(read.lines.single.amount, 0.0);

      expect(GlazeSnapshot.fromMap({}).lines, isEmpty);
      expect(GlazeSnapshot.tryFromMap('broken'), isNull);
    });

    test('TestPieceSnapshot は欠損に耐え、Map でなければ null', () {
      expect(TestPieceSnapshot.tryFromMap(null), isNull);
      expect(TestPieceSnapshot.tryFromMap(42), isNull);

      final read = TestPieceSnapshot.tryFromMap({'glaze': 'broken'})!;
      expect(read.glaze, isNull);
      expect(read.additionalGlazes, isEmpty);
      expect(read.clayName, isNull);
      expect(read.source, 'saved');
      expect(read.takenAt, isA<Timestamp>());
    });

    test('TestPieceSnapshot は toMap と tryFromMap で往復できる', () {
      final snapshot = TestPieceSnapshot(
        glaze: GlazeSnapshot.capture(glaze, materials),
        additionalGlazes: [
          GlazeSnapshot(glazeId: 'g2', name: '鉄赤', lines: const []),
        ],
        clayName: '信楽白',
        source: SnapshotSource.backfilled,
        takenAt: Timestamp.fromMillisecondsSinceEpoch(5000),
      );
      final read = TestPieceSnapshot.tryFromMap(snapshot.toMap())!;
      expect(read.glaze!.recipe, snapshot.glaze!.recipe);
      expect(read.additionalGlazes.single.name, '鉄赤');
      expect(read.clayName, '信楽白');
      expect(read.source, 'backfilled');
      expect(read.takenAt, Timestamp.fromMillisecondsSinceEpoch(5000));
    });
  });

  group('GlazeSnapshot.hasSameRecipeAs', () {
    final snapshot = GlazeSnapshot.capture(glaze, materials);

    test('原料と量が同じなら true', () {
      expect(snapshot.hasSameRecipeAs({'m1': 60, 'm2': 2, 'gone': 5}), isTrue);
      expect(
        snapshot.hasSameRecipeAs({'m1': 60 + 1e-12, 'm2': 2, 'gone': 5}),
        isTrue,
      );
    });

    test('量が違えば false', () {
      expect(snapshot.hasSameRecipeAs({'m1': 61, 'm2': 2, 'gone': 5}), isFalse);
    });

    test('原料の集合が違えば false', () {
      expect(snapshot.hasSameRecipeAs({'m1': 60, 'm2': 2}), isFalse);
      expect(
        snapshot.hasSameRecipeAs({'m1': 60, 'm2': 2, 'other': 5}),
        isFalse,
      );
    });
  });

  group('TestPieceSnapshot.capture', () {
    final glazeMap = {
      'g1': glaze,
      'g2': Glaze(
        id: 'g2',
        name: '鉄赤',
        recipe: {'m2': 10},
        tags: const [],
        createdAt: Timestamp.now(),
      ),
    };
    final clayMap = {'c1': Clay(id: 'c1', name: '信楽白', order: 0)};

    test('主たる釉薬・追加釉薬・素地土名を写す', () {
      final snapshot = TestPieceSnapshot.capture(
        glazeId: 'g1',
        additionalGlazeIds: ['g2', 'deleted'],
        clayId: 'c1',
        glazeMap: glazeMap,
        materialMap: materials,
        clayMap: clayMap,
        source: SnapshotSource.saved,
      );
      expect(snapshot.glaze!.glazeId, 'g1');
      // 見つからない追加釉薬は含めない
      expect(snapshot.additionalGlazes.map((g) => g.glazeId), ['g2']);
      expect(snapshot.clayName, '信楽白');
      expect(snapshot.source, 'saved');
    });

    test('見つからない釉薬と素地土は以前の写しを残す', () {
      final previous = TestPieceSnapshot(
        glaze: GlazeSnapshot(glazeId: 'old', name: '旧釉', lines: const []),
        clayName: '旧土',
        source: SnapshotSource.saved,
        takenAt: Timestamp.now(),
      );
      final snapshot = TestPieceSnapshot.capture(
        glazeId: 'old',
        additionalGlazeIds: ['g2'],
        clayId: 'deleted',
        glazeMap: glazeMap,
        materialMap: materials,
        clayMap: clayMap,
        source: SnapshotSource.saved,
        previous: previous,
      );
      expect(snapshot.glaze!.name, '旧釉');
      expect(snapshot.clayName, '旧土');
    });

    test('replacingGlaze は同じ glazeId の部分だけを置き換える', () {
      final snapshot = TestPieceSnapshot(
        glaze: GlazeSnapshot(glazeId: 'g1', name: '青磁', lines: const []),
        additionalGlazes: [
          GlazeSnapshot(glazeId: 'g2', name: '鉄赤', lines: const []),
        ],
        clayName: '信楽白',
        source: SnapshotSource.backfilled,
        takenAt: Timestamp.now(),
      );
      final replaced = snapshot.replacingGlaze(
        GlazeSnapshot.capture(glazeMap['g2']!, materials),
        source: SnapshotSource.corrected,
      );
      expect(replaced.glaze!.recipe, isEmpty);
      expect(replaced.additionalGlazes.single.recipe, {'m2': 10.0});
      expect(replaced.clayName, '信楽白');
      expect(replaced.source, 'corrected');
      expect(replaced.containsGlaze('g2'), isTrue);
      expect(replaced.containsGlaze('g3'), isFalse);
    });
  });
}
