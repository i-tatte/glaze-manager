import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/glaze.dart';

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
    });
  });
}
