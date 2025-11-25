import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/tag_data.dart';

void main() {
  group('TagData Model Test', () {
    test('toFirestore returns correct map', () {
      final now = Timestamp.now();
      final tagData = TagData(id: 'Tag A', createdAt: now);
      final map = tagData.toFirestore();
      expect(map['createdAt'], now);
    });

    test('fromFirestore creates correct instance', () async {
      final fakeDb = FakeFirebaseFirestore();
      final now = Timestamp.now();
      await fakeDb.collection('tags').doc('Tag B').set({'createdAt': now});
      final snapshot = await fakeDb.collection('tags').doc('Tag B').get();

      final tagData = TagData.fromFirestore(snapshot);
      expect(tagData.id, 'Tag B');
      expect(tagData.createdAt, now);
    });

    test('fromFirestore handles missing data with defaults', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('tags').doc('Tag C').set({});
      final snapshot = await fakeDb.collection('tags').doc('Tag C').get();

      final tagData = TagData.fromFirestore(snapshot);
      expect(tagData.id, 'Tag C');
      expect(tagData.createdAt, isA<Timestamp>());
    });
  });
}
