import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_profile.dart';

void main() {
  group('FiringProfile Model Test', () {
    test('toFirestore returns correct map', () {
      final profile = FiringProfile(
        name: 'Cone 6',
        curveData: '0,20\n60,100',
        isReduction: true,
        reductionStartTemp: 900,
        reductionEndTemp: 1000,
      );
      final map = profile.toFirestore();
      expect(map['name'], 'Cone 6');
      expect(map['curveData'], '0,20\n60,100');
      expect(map['isReduction'], true);
      expect(map['reductionStartTemp'], 900);
      expect(map['reductionEndTemp'], 1000);
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('profiles').doc('test_id').set({
        'name': 'Cone 10',
        'curveData': '0,20\n120,1200',
        'isReduction': false,
      });
      final snapshot = await fakeDb.collection('profiles').doc('test_id').get();

      final profile = FiringProfile.fromFirestore(snapshot);
      expect(profile.id, 'test_id');
      expect(profile.name, 'Cone 10');
      expect(profile.curveData, '0,20\n120,1200');
      expect(profile.isReduction, false);
      expect(profile.reductionStartTemp, null);
      expect(profile.reductionEndTemp, null);
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('profiles').doc('test_id').set({});
      final snapshot = await fakeDb.collection('profiles').doc('test_id').get();

      final profile = FiringProfile.fromFirestore(snapshot);
      expect(profile.id, 'test_id');
      expect(profile.name, '');
      expect(profile.curveData, '');
      expect(profile.isReduction, false);
    });
  });
}
