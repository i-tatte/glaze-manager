import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/widgets/test_piece_card.dart';
import 'package:glaze_manager/widgets/test_piece_grid.dart';
import 'package:mockito/mockito.dart';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return createMockImageHttpClient(context);
  }
}

HttpClient createMockImageHttpClient(SecurityContext? _) {
  final client = MockHttpClient();
  final request = MockHttpClientRequest();
  final response = MockHttpClientResponse();
  final headers = MockHttpHeaders();

  when(client.getUrl(Uri())).thenAnswer((_) async => request);
  when(request.headers).thenReturn(headers);
  when(request.close()).thenAnswer((_) async => response);
  when(response.contentLength).thenReturn(_transparentImage.length);
  when(response.statusCode).thenReturn(HttpStatus.ok);
  when(response.listen(any)).thenAnswer((invocation) {
    final void Function(List<int>) onData = invocation.positionalArguments[0];
    final void Function() onDone = invocation.namedArguments[#onDone];
    final void Function(Object, [StackTrace?])? onError =
        invocation.namedArguments[#onError];
    final bool? cancelOnError = invocation.namedArguments[#cancelOnError];

    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  });

  return client;
}

class MockHttpClient extends Mock implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => super.noSuchMethod(
    Invocation.method(#getUrl, [url]),
    returnValue: Future.value(MockHttpClientRequest()),
  );
}

class MockHttpClientRequest extends Mock implements HttpClientRequest {
  @override
  HttpHeaders get headers => super.noSuchMethod(
    Invocation.getter(#headers),
    returnValue: MockHttpHeaders(),
  );
  @override
  Future<HttpClientResponse> close() => super.noSuchMethod(
    Invocation.method(#close, []),
    returnValue: Future.value(MockHttpClientResponse()),
  );
}

class MockHttpClientResponse extends Mock implements HttpClientResponse {
  @override
  int get contentLength =>
      super.noSuchMethod(Invocation.getter(#contentLength), returnValue: 0);
  @override
  int get statusCode =>
      super.noSuchMethod(Invocation.getter(#statusCode), returnValue: 200);
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => super.noSuchMethod(
    Invocation.method(
      #listen,
      [onData],
      {#onError: onError, #onDone: onDone, #cancelOnError: cancelOnError},
    ),
    returnValue: Stream<List<int>>.empty().listen(null),
  );
}

class MockHttpHeaders extends Mock implements HttpHeaders {}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = TestHttpOverrides();

  testWidgets('TestPieceGrid renders cards', (WidgetTester tester) async {
    final testPieces = [
      TestPiece(
        id: 'tp1',
        glazeId: 'g1',
        clayId: 'c1',
        createdAt: Timestamp.now(),
      ),
      TestPiece(
        id: 'tp2',
        glazeId: 'g2',
        clayId: 'c2',
        createdAt: Timestamp.now(),
      ),
    ];
    final glazeMap = {
      'g1': Glaze(
        id: 'g1',
        name: 'Glaze 1',
        createdAt: Timestamp.now(),
        recipe: {},
        tags: [],
      ),
      'g2': Glaze(
        id: 'g2',
        name: 'Glaze 2',
        createdAt: Timestamp.now(),
        recipe: {},
        tags: [],
      ),
    };
    final clayMap = {
      'c1': Clay(id: 'c1', name: 'Clay 1', order: 0),
      'c2': Clay(id: 'c2', name: 'Clay 2', order: 1),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestPieceGrid(
            testPieces: testPieces,
            glazeMap: glazeMap,
            clayMap: clayMap,
            crossAxisCount: 2,
          ),
        ),
      ),
    );

    expect(find.byType(TestPieceCard), findsNWidgets(2));
    expect(find.text('Glaze 1'), findsOneWidget);
    expect(find.text('Glaze 2'), findsOneWidget);
    expect(find.text('Clay 1'), findsOneWidget);
    expect(find.text('Clay 2'), findsOneWidget);
  });

  testWidgets('TestPieceGrid shows refresh indicator', (
    WidgetTester tester,
  ) async {
    bool refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestPieceGrid(
            testPieces: [],
            glazeMap: {},
            clayMap: {},
            crossAxisCount: 2,
            onRefresh: () async {
              refreshed = true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);

    // Trigger refresh
    await tester.fling(find.byType(GridView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, true);
  });
}
