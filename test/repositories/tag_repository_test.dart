import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/repositories/tag_repository.dart';
import 'package:mockito/mockito.dart';

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
  late TagRepository repository;
  late FakeFirebaseFirestore fakeDb;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    when(mockAuth.currentUser).thenReturn(MockUser());
    repository = TagRepository(db: fakeDb, auth: mockAuth);
  });

  group('TagRepository', () {
    test('addAll creates only missing tags (dedup + skip existing)', () async {
      await repository.add('透明');

      await repository.addAll(['透明', '青磁', '青磁', '飴']);

      final all = await repository.getAll();
      expect(all.toSet(), {'透明', '青磁', '飴'});
    });

    test('add is idempotent (tag name is the document id)', () async {
      await repository.add('透明');
      await repository.add('透明');

      expect(await repository.getAll(), ['透明']);
    });

    test('delete removes only the master entry', () async {
      await repository.addAll(['透明', '飴']);
      await repository.delete('透明');

      expect(await repository.getAll(), ['飴']);
    });

    test('getAll returns empty when not logged in', () async {
      when(mockAuth.currentUser).thenReturn(null);
      expect(await repository.getAll(), isEmpty);
    });
  });
}
