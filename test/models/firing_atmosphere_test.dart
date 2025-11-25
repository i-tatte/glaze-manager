import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';

void main() {
  group('FiringAtmosphere Model Test', () {
    test('toFirestore returns correct map', () {
      final atmosphere = FiringAtmosphere(name: 'Oxidation');
      final map = atmosphere.toFirestore();
      expect(map['name'], 'Oxidation');
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('atmospheres').doc('test_id').set({
        'name': 'Reduction',
      });
      final snapshot = await fakeDb
          .collection('atmospheres')
          .doc('test_id')
          .get();

      final atmosphere = FiringAtmosphere.fromFirestore(snapshot);
      expect(atmosphere.id, 'test_id');
      expect(atmosphere.name, 'Reduction');
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('atmospheres').doc('test_id').set({});
      final snapshot = await fakeDb
          .collection('atmospheres')
          .doc('test_id')
          .get();

      final atmosphere = FiringAtmosphere.fromFirestore(snapshot);
      expect(atmosphere.id, 'test_id');
      expect(atmosphere.name, '');
    });
  });
}
