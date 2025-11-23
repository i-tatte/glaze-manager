import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {
  @override
  Reference ref([String? path]) => super.noSuchMethod(
    Invocation.method(#ref, [path]),
    returnValue: FakeReference(),
  );

  @override
  Reference refFromURL(String? url) => super.noSuchMethod(
    Invocation.method(#refFromURL, [url]),
    returnValue: FakeReference(),
  );
}

class FakeReference extends Fake implements Reference {
  bool putDataCalled = false;
  bool deleteCalled = false;

  @override
  UploadTask putData(Uint8List? data, [SettableMetadata? metadata]) {
    putDataCalled = true;
    return FakeUploadTask();
  }

  @override
  Future<void> delete() {
    deleteCalled = true;
    return Future.value();
  }
}

class FakeUploadTask extends Fake implements UploadTask {
  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) {
    return Future.value(MockTaskSnapshot()).then(onValue, onError: onError);
  }
}

class MockTaskSnapshot extends Mock implements TaskSnapshot {}

class MockFullMetadata extends Mock implements FullMetadata {}

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
  late StorageService storageService;
  late MockFirebaseStorage mockStorage;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockAuth = MockFirebaseAuth();
    // Stub currentUser to return a user by default
    when(mockAuth.currentUser).thenReturn(MockUser());
    storageService = StorageService(storage: mockStorage, auth: mockAuth);
  });

  group('StorageService Test', () {
    test('uploadTestPieceImage calls putData', () async {
      final fakeRef = FakeReference();
      when(mockStorage.ref(any)).thenReturn(fakeRef);

      await storageService.uploadTestPieceImage(
        name: 'test.jpg',
        bytes: Uint8List(0),
      );

      verify(
        mockStorage.ref('users/test_uid/test_pieces/images/test.jpg'),
      ).called(1);
      expect(fakeRef.putDataCalled, true);
    });

    test('deleteTestPieceImage calls delete', () async {
      final fakeRef = FakeReference();
      when(mockStorage.refFromURL(any)).thenReturn(fakeRef);

      await storageService.deleteTestPieceImage('http://example.com/test.jpg');

      verify(mockStorage.refFromURL('http://example.com/test.jpg')).called(1);
      expect(fakeRef.deleteCalled, true);
    });
  });
}
