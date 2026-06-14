import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart';

void main() {
  group('Material Model Test', () {
    test('MaterialCategory.fromString returns correct enum', () {
      expect(MaterialCategory.fromString('base'), MaterialCategory.base);
      expect(MaterialCategory.fromString('pigment'), MaterialCategory.pigment);
      expect(MaterialCategory.fromString('invalid'), MaterialCategory.base);
    });

    test('toFirestore returns correct map', () {
      final material = Material(
        name: 'Kaolin',
        order: 1,
        components: {'SiO2': 45.0, 'Al2O3': 38.0},
        category: MaterialCategory.base,
      );
      final map = material.toFirestore();
      expect(map['name'], 'Kaolin');
      expect(map['order'], 1);
      expect(map['components'], {'SiO2': 45.0, 'Al2O3': 38.0});
      expect(map['category'], 'base');
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('materials').doc('test_id').set({
        'name': 'Silica',
        'order': 2,
        'components': {'SiO2': 99.0},
        'category': 'base',
      });
      final snapshot = await fakeDb
          .collection('materials')
          .doc('test_id')
          .get();

      final material = Material.fromFirestore(snapshot);
      expect(material.id, 'test_id');
      expect(material.name, 'Silica');
      expect(material.order, 2);
      expect(material.components, {'SiO2': 99.0});
      expect(material.category, MaterialCategory.base);
    });

    test(
      'fromFirestore restores integer component values as double (R-6)',
      () async {
        final fakeDb = FakeFirebaseFirestore();
        await fakeDb.collection('materials').doc('test_id').set({
          'name': 'Silica',
          'order': 1,
          // 整数で保存された成分値でも復元できること
          'components': {'SiO2': 99, 'Al2O3': 1},
          'category': 'base',
        });
        final snapshot = await fakeDb
            .collection('materials')
            .doc('test_id')
            .get();

        final material = Material.fromFirestore(snapshot);
        expect(material.components['SiO2'], 99.0);
        expect(material.components['Al2O3'], 1.0);
        expect(material.components['SiO2'], isA<double>());
      },
    );

    test('constructor copies components defensively (R-7)', () {
      final components = {'SiO2': 50.0};
      final material = Material(
        name: 'M',
        order: 1,
        components: components,
        category: MaterialCategory.base,
      );

      // コンストラクタに渡したマップを後から変更してもモデルに影響しない
      components['Al2O3'] = 10.0;

      expect(material.components, {'SiO2': 50.0});
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('materials').doc('test_id').set({});
      final snapshot = await fakeDb
          .collection('materials')
          .doc('test_id')
          .get();

      final material = Material.fromFirestore(snapshot);
      expect(material.id, 'test_id');
      expect(material.name, '');
      expect(material.order, 0);
      expect(material.components, {});
      expect(material.category, MaterialCategory.base);
    });
  });
}
