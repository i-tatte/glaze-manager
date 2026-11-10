import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';
import 'package:glaze_manager/widgets/test_piece_image.dart';

import '../helpers/fake_upload_queue.dart';

void main() {
  TestPiece piece({
    String? imageUrl,
    String? thumbnailUrl,
    String? imagePath,
  }) => TestPiece(
    id: 'tp1',
    glazeId: 'g1',
    clayId: 'c1',
    imageUrl: imageUrl,
    thumbnailUrl: thumbnailUrl,
    imagePath: imagePath,
    createdAt: Timestamp.now(),
  );

  PendingUpload job({String? lastError}) => PendingUpload(
    uid: 'test-user',
    testPieceId: 'tp1',
    fileName: 'a.jpg',
    storagePath: 'users/test-user/test_pieces/images/tp1/a.jpg',
    localPath: '/nonexistent/pending_uploads/tp1/a.jpg',
    createdAt: DateTime(2026, 11, 10),
    lastError: lastError,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Map<String, PendingUpload> pending = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uploadQueueProvider.overrideWith(
            (_) => FakeUploadQueue(pending: pending),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
        ),
      ),
    );
  }

  testWidgets('アップロード待ちがあれば端末内の画像に印を重ねる', (tester) async {
    await pump(
      tester,
      TestPieceImage(testPiece: piece(imageUrl: 'https://example.com/old.jpg')),
      pending: {'tp1': job()},
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect(
      (image.image as FileImage).file.path,
      '/nonexistent/pending_uploads/tp1/a.jpg',
    );
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(find.byType(AppNetworkImage), findsNothing);
  });

  testWidgets('直前の送信が失敗していれば印を cloud_off にする', (tester) async {
    await pump(
      tester,
      TestPieceImage(testPiece: piece()),
      pending: {'tp1': job(lastError: 'boom')},
    );

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('印を出さない指定なら画像だけを出す', (tester) async {
    await pump(
      tester,
      TestPieceImage(testPiece: piece(), showPendingBadge: false),
      pending: {'tp1': job()},
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('待ちがなく URL があればネットワークの画像を出す', (tester) async {
    await pump(
      tester,
      TestPieceImage(
        testPiece: piece(
          imageUrl: 'https://example.com/a.jpg',
          thumbnailUrl: 'https://example.com/t.jpg',
        ),
      ),
    );
    expect(
      tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).url,
      'https://example.com/t.jpg',
    );

    await pump(
      tester,
      TestPieceImage(
        testPiece: piece(
          imageUrl: 'https://example.com/a.jpg',
          thumbnailUrl: 'https://example.com/t.jpg',
        ),
        preferThumbnail: false,
      ),
    );
    expect(
      tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).url,
      'https://example.com/a.jpg',
    );
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('待ちも URL もなく imagePath があれば処理待ちを出す', (tester) async {
    await pump(
      tester,
      TestPieceImage(
        testPiece: piece(imagePath: 'users/u/test_pieces/images/tp1/a.jpg'),
      ),
    );

    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    expect(find.byType(AppNetworkImage), findsNothing);
  });

  testWidgets('imagePath もなければ写真なしを出す', (tester) async {
    await pump(tester, TestPieceImage(testPiece: piece()));

    expect(find.byIcon(Icons.photo), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty), findsNothing);
  });

  testWidgets('差し替えなしの既定のキューでも組み立てられる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: TestPieceImage(testPiece: piece())),
        ),
      ),
    );
    expect(find.byIcon(Icons.photo), findsOneWidget);
  });
}
