import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';

void main() {
  group('Glaze Model Test', () {
    test('toFirestore returns correct map', () {
      final now = Timestamp.now();
      final glaze = Glaze(
        name: 'Blue Glaze',
        recipe: {'kaolin': 50, 'silica': 50},
        tags: ['blue', 'glossy'],
        createdAt: now,
        description: 'A nice blue glaze',
      );
      final map = glaze.toFirestore();
      expect(map['name'], 'Blue Glaze');
      expect(map['recipe'], {'kaolin': 50, 'silica': 50});
      expect(map['tags'], ['blue', 'glossy']);
      expect(map['createdAt'], now);
      expect(map['description'], 'A nice blue glaze');
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      final now = Timestamp.now();
      await fakeDb.collection('glazes').doc('test_id').set({
        'name': 'Red Glaze',
        'recipe': {'feldspar': 100.0},
        'tags': ['red'],
        'createdAt': now,
        'description': 'A red glaze',
      });
      final snapshot = await fakeDb.collection('glazes').doc('test_id').get();

      final glaze = Glaze.fromFirestore(snapshot);
      expect(glaze.id, 'test_id');
      expect(glaze.name, 'Red Glaze');
      expect(glaze.recipe, {'feldspar': 100.0});
      expect(glaze.tags, ['red']);
      expect(glaze.createdAt, now);
      expect(glaze.description, 'A red glaze');
    });

    test(
      'fromFirestore restores integer recipe amounts as double (R-6)',
      () async {
        final fakeDb = FakeFirebaseFirestore();
        await fakeDb.collection('glazes').doc('test_id').set({
          'name': 'Int Glaze',
          // 整数で保存された配合量 (手作業・外部ツール由来) でも復元できること
          'recipe': {'feldspar': 100, 'silica': 50},
          'tags': ['x'],
          'createdAt': Timestamp.now(),
        });
        final snapshot = await fakeDb.collection('glazes').doc('test_id').get();

        final glaze = Glaze.fromFirestore(snapshot);
        expect(glaze.recipe['feldspar'], 100.0);
        expect(glaze.recipe['silica'], 50.0);
        expect(glaze.recipe['feldspar'], isA<double>());
      },
    );

    test('constructor copies collections defensively (R-7)', () {
      final recipe = {'kaolin': 50.0};
      final tags = ['blue'];
      final glaze = Glaze(
        name: 'G',
        recipe: recipe,
        tags: tags,
        createdAt: Timestamp.now(),
      );

      // コンストラクタに渡したコレクションを後から変更してもモデルに影響しない
      recipe['silica'] = 10.0;
      tags.add('glossy');

      expect(glaze.recipe, {'kaolin': 50.0});
      expect(glaze.tags, ['blue']);
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('glazes').doc('test_id').set({});
      final snapshot = await fakeDb.collection('glazes').doc('test_id').get();

      final glaze = Glaze.fromFirestore(snapshot);
      expect(glaze.id, 'test_id');
      expect(glaze.name, '');
      expect(glaze.recipe, {});
      expect(glaze.tags, []);
      expect(glaze.description, null);
      // createdAt defaults to now() in model if missing? Let's check model logic or assume it handles null.
      // Actually model usually requires it or defaults.
      // If model logic is: createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now()
      expect(glaze.createdAt, isA<Timestamp>());
      expect(glaze.parentGlazeId, isNull);
      expect(glaze.parentSnapshot, isNull);
    });

    test('派生元のフィールドを往復できる', () async {
      final fakeDb = FakeFirebaseFirestore();
      final glaze = Glaze(
        name: '青磁 改',
        recipe: {'m1': 62},
        tags: const [],
        createdAt: Timestamp.now(),
        parentGlazeId: 'g1',
        parentSnapshot: GlazeSnapshot(
          glazeId: 'g1',
          name: '青磁',
          lines: const [
            RecipeLine(
              materialId: 'm1',
              name: '長石',
              category: 'base',
              amount: 60,
            ),
          ],
        ),
      );
      await fakeDb.collection('glazes').doc('g2').set(glaze.toFirestore());
      final doc = await fakeDb.collection('glazes').doc('g2').get();

      final read = Glaze.fromFirestore(doc);
      expect(read.parentGlazeId, 'g1');
      expect(read.parentSnapshot!.name, '青磁');
      expect(read.parentSnapshot!.recipe, {'m1': 60.0});
    });

    test('派生元がなければフィールドを出力しない', () {
      final map = Glaze(
        name: '青磁',
        recipe: {},
        tags: const [],
        createdAt: Timestamp.now(),
      ).toFirestore();
      expect(map.containsKey('parentGlazeId'), isFalse);
      expect(map.containsKey('parentSnapshot'), isFalse);
    });

    test('派生元の写しが壊れていれば null として読む', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('glazes').doc('g2').set({
        'parentGlazeId': 'g1',
        'parentSnapshot': 'broken',
      });
      final doc = await fakeDb.collection('glazes').doc('g2').get();
      final read = Glaze.fromFirestore(doc);
      expect(read.parentGlazeId, 'g1');
      expect(read.parentSnapshot, isNull);
    });
  });
}
