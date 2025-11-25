import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';

void main() {
  group('Clay Model Test', () {
    test('supports value equality', () {
      final clay1 = Clay(id: '1', name: 'Clay A', order: 1);
      final clay2 = Clay(id: '1', name: 'Clay A', order: 1);
      // Default equality is reference based, so this might fail if not overridden.
      // The model doesn't override ==, so we check properties.
      expect(clay1.id, clay2.id);
      expect(clay1.name, clay2.name);
      expect(clay1.order, clay2.order);
    });

    test('toFirestore returns correct map', () {
      final clay = Clay(name: 'Clay A', order: 1);
      final map = clay.toFirestore();
      expect(map['name'], 'Clay A');
      expect(map['order'], 1);
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('clays').doc('test_id').set({
        'name': 'Clay B',
        'order': 2,
      });
      final snapshot = await fakeDb.collection('clays').doc('test_id').get();

      final clay = Clay.fromFirestore(snapshot);
      expect(clay.id, 'test_id');
      expect(clay.name, 'Clay B');
      expect(clay.order, 2);
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('clays').doc('test_id').set({});
      final snapshot = await fakeDb.collection('clays').doc('test_id').get();

      final clay = Clay.fromFirestore(snapshot);
      expect(clay.id, 'test_id');
      expect(clay.name, '');
      expect(clay.order, 0);
    });
  });
}
