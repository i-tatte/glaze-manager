import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => super.noSuchMethod(
    Invocation.method(#authStateChanges, []),
    returnValue: Stream<User?>.empty(),
  );

  @override
  Future<UserCredential> signInAnonymously() => super.noSuchMethod(
    Invocation.method(#signInAnonymously, []),
    returnValue: Future.value(MockUserCredential()),
  );

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String? email,
    required String? password,
  }) => super.noSuchMethod(
    Invocation.method(#createUserWithEmailAndPassword, [], {
      #email: email,
      #password: password,
    }),
    returnValue: Future.value(MockUserCredential()),
  );

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String? email,
    required String? password,
  }) => super.noSuchMethod(
    Invocation.method(#signInWithEmailAndPassword, [], {
      #email: email,
      #password: password,
    }),
    returnValue: Future.value(MockUserCredential()),
  );

  @override
  Future<void> signOut() => super.noSuchMethod(
    Invocation.method(#signOut, []),
    returnValue: Future.value(),
  );
}

class MockUserCredential extends Mock implements UserCredential {
  @override
  User? get user =>
      super.noSuchMethod(Invocation.getter(#user), returnValue: MockUser());
}

class MockUser extends Mock implements User {
  @override
  String get uid =>
      super.noSuchMethod(Invocation.getter(#uid), returnValue: 'test_uid');
}

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth);
  });

  group('AuthService Test', () {
    test('signInAnonymously returns user', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_uid');
      when(
        mockAuth.signInAnonymously(),
      ).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signInAnonymously();
      expect(user, isNotNull);
      expect(user?.uid, 'test_uid');
      verify(mockAuth.signInAnonymously()).called(1);
    });

    test('signUpWithEmailAndPassword returns user', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      when(mockUserCredential.user).thenReturn(mockUser);
      when(
        mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password',
        ),
      ).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signUpWithEmailAndPassword(
        'test@example.com',
        'password',
      );
      expect(user, isNotNull);
      verify(
        mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password',
        ),
      ).called(1);
    });

    test('signInWithEmailAndPassword returns user', () async {
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();
      when(mockUserCredential.user).thenReturn(mockUser);
      when(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password',
        ),
      ).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signInWithEmailAndPassword(
        'test@example.com',
        'password',
      );
      expect(user, isNotNull);
      verify(
        mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password',
        ),
      ).called(1);
    });

    test('signOut calls auth signOut', () async {
      when(mockAuth.signOut()).thenAnswer((_) async => {});
      await authService.signOut();
      verify(mockAuth.signOut()).called(1);
    });

    test('user stream returns auth state changes', () {
      final stream = Stream<User?>.fromIterable([null, MockUser()]);
      when(mockAuth.authStateChanges()).thenAnswer((_) => stream);

      expect(authService.user, emitsInOrder([null, isA<User>()]));
    });
  });
}
