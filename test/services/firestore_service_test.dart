import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:mockito/mockito.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser => super.noSuchMethod(
    Invocation.getter(#currentUser),
    returnValue: MockUser(),
  );
}

class MockUser extends Mock implements User {
  @override
  String get uid => 'test_uid';
}

void main() {
  late FirestoreService firestoreService;
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    // Stub currentUser to return a user by default
    when(mockAuth.currentUser).thenReturn(MockUser());
    firestoreService = FirestoreService(db: fakeDb, auth: mockAuth);
  });

  group('FirestoreService Test', () {
    test('addMaterial adds document to correct collection', () async {
      final material = Material(
        name: 'Test Material',
        order: 1,
        components: {},
        category: MaterialCategory.base,
      );

      await firestoreService.addMaterial(material);

      final snapshot = await fakeDb
          .collection('users')
          .doc('test_uid')
          .collection('materials')
          .get();

      expect(snapshot.docs.length, 1);
      final doc = snapshot.docs.first;
      expect(doc.data()['name'], 'Test Material');
      expect(doc.data()['category'], 'base');
    });

    test('addMaterial throws if user not logged in', () async {
      final material = Material(
        name: 'Test Material',
        order: 1,
        components: {},
        category: MaterialCategory.base,
      );

      when(mockAuth.currentUser).thenReturn(null);

      expect(() => firestoreService.addMaterial(material), throwsException);
    });
  });
}
