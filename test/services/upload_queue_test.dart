import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';
import 'package:glaze_manager/services/upload_queue.dart';

void main() {
  late Directory tempDir;
  late PendingUploadStore store;
  late String? uid;

  /// storagePath → 文書の状態
  late Map<String, UploadDocState> docStates;
  late List<String> checked;
  late List<({String storagePath, List<int> bytes})> uploaded;
  late Future<void> Function(PendingUpload job, Uint8List bytes) onUpload;
  late List<String> failures;
  late UploadQueue queue;

  String pathOf(String testPieceId, String fileName, {String user = 'me'}) =>
      'users/$user/test_pieces/images/$testPieceId/$fileName';

  UploadQueue newQueue({Duration retryDelay = const Duration(hours: 1)}) =>
      UploadQueue(
        store: store,
        currentUid: () => uid,
        checkDocument: (job) async {
          checked.add(job.storagePath);
          final state = docStates[job.storagePath];
          if (state == null) throw StateError('unexpected check');
          return state;
        },
        upload: (job, bytes) => onUpload(job, bytes),
        onFailure: failures.add,
        retryDelay: retryDelay,
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_queue_');
    store = PendingUploadStore(baseDirectory: () async => tempDir);
    uid = 'me';
    docStates = {};
    checked = [];
    uploaded = [];
    failures = [];
    onUpload = (job, bytes) async {
      uploaded.add((storagePath: job.storagePath, bytes: bytes.toList()));
    };
    queue = newQueue();
  });

  tearDown(() async {
    queue.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// 端末内に待ちを作り、キューに読み込ませる (enqueue の自動送信を避ける)
  Future<PendingUpload> seed(
    String testPieceId,
    String fileName, {
    String user = 'me',
    List<int> bytes = const [1, 2, 3],
  }) async {
    final job = await store.save(
      uid: user,
      testPieceId: testPieceId,
      fileName: fileName,
      storagePath: pathOf(testPieceId, fileName, user: user),
      bytes: Uint8List.fromList(bytes),
    );
    await queue.load();
    return job;
  }

  group('classifyTestPieceDocument', () {
    UploadDocState classify({
      bool exists = true,
      bool hasPendingWrites = false,
      Object? imagePath = 'p',
    }) => classifyTestPieceDocument(
      exists: exists,
      hasPendingWrites: hasPendingWrites,
      imagePath: imagePath,
      storagePath: 'p',
    );

    test('文書がなければ削除済み', () {
      expect(classify(exists: false), UploadDocState.deleted);
    });

    test('未送信の書き込みがあれば、imagePath が一致していても同期待ち', () {
      expect(classify(hasPendingWrites: true), UploadDocState.pendingWrite);
      expect(
        classify(hasPendingWrites: true, imagePath: 'other'),
        UploadDocState.pendingWrite,
      );
    });

    test('imagePath が違えば古い', () {
      expect(classify(imagePath: 'other'), UploadDocState.stale);
      expect(classify(imagePath: null), UploadDocState.stale);
    });

    test('imagePath が一致し、未送信の書き込みもなければ送信可', () {
      expect(classify(), UploadDocState.ready);
    });
  });

  group('processAll の 5 つの分岐', () {
    test('1. 読み取りに失敗したら、そこで処理全体を打ち切る', () async {
      final a = await seed('tp1', 'a.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = await seed('tp2', 'b.jpg');
      docStates[a.storagePath] = UploadDocState.unreachable;
      docStates[b.storagePath] = UploadDocState.ready;

      await queue.processAll();

      expect(checked, [a.storagePath]);
      expect(uploaded, isEmpty);
      expect(queue.pending.keys, unorderedEquals(['tp1', 'tp2']));
      expect(await File(a.localPath).exists(), isTrue);
    });

    test('checkDocument が例外を投げたら通信不可として打ち切る', () async {
      final a = await seed('tp1', 'a.jpg');
      // docStates に登録がないので例外になる
      await queue.processAll();

      expect(checked, [a.storagePath]);
      expect(queue.pending.keys, ['tp1']);
      expect(failures, isEmpty);
    });

    test('2. 文書が存在しなければ待ちを捨てる', () async {
      final a = await seed('tp1', 'a.jpg');
      docStates[a.storagePath] = UploadDocState.deleted;

      await queue.processAll();

      expect(uploaded, isEmpty);
      expect(queue.pending, isEmpty);
      expect(await File(a.localPath).exists(), isFalse);
      expect(await store.loadAll(), isEmpty);
    });

    test('3. 書き込みがサーバーに届いていなければ送らずに残し、あとで再試行する', () async {
      queue.dispose();
      queue = newQueue(retryDelay: const Duration(milliseconds: 50));
      final a = await seed('tp1', 'a.jpg');
      docStates[a.storagePath] = UploadDocState.pendingWrite;

      await queue.processAll();

      expect(uploaded, isEmpty);
      expect(queue.pending.keys, ['tp1']);
      expect(await File(a.localPath).exists(), isTrue);

      // 書き込みが届いたら、再試行で送られる
      docStates[a.storagePath] = UploadDocState.ready;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(checked, [a.storagePath, a.storagePath]);
      expect(uploaded.map((u) => u.storagePath), [a.storagePath]);
      expect(queue.pending, isEmpty);
    });

    test('4. imagePath が違えば待ちを捨てる', () async {
      final a = await seed('tp1', 'a.jpg');
      docStates[a.storagePath] = UploadDocState.stale;

      await queue.processAll();

      expect(uploaded, isEmpty);
      expect(queue.pending, isEmpty);
      expect(await File(a.localPath).exists(), isFalse);
    });

    test('5. 送信可なら端末内の画像を送り、待ちと画像を消す', () async {
      final a = await seed('tp1', 'a.jpg', bytes: [7, 7, 7]);
      docStates[a.storagePath] = UploadDocState.ready;

      await queue.processAll();

      expect(uploaded, hasLength(1));
      expect(uploaded.single.storagePath, a.storagePath);
      expect(uploaded.single.bytes, [7, 7, 7]);
      expect(queue.pending, isEmpty);
      expect(await File(a.localPath).exists(), isFalse);
      expect(await store.loadAll(), isEmpty);
    });

    test('5. 送信に失敗したら記録して残し、利用者に知らせる', () async {
      final a = await seed('tp1', 'a.jpg');
      docStates[a.storagePath] = UploadDocState.ready;
      onUpload = (_, _) async => throw StateError('server rejected');

      await queue.processAll();

      final job = queue.pending['tp1']!;
      expect(job.attempts, 1);
      expect(job.lastError, contains('server rejected'));
      expect(job.hasFailed, isTrue);
      expect((await store.loadAll()).single.attempts, 1);
      expect(await File(a.localPath).exists(), isTrue);
      expect(failures, [UploadQueue.failureMessage]);
    });

    test('5. 通信できないことによる失敗は知らせず、処理を打ち切る', () async {
      final a = await seed('tp1', 'a.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = await seed('tp2', 'b.jpg');
      docStates[a.storagePath] = UploadDocState.ready;
      docStates[b.storagePath] = UploadDocState.ready;
      onUpload = (_, _) async => throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'retry-limit-exceeded',
      );

      await queue.processAll();

      expect(checked, [a.storagePath]);
      expect(failures, isEmpty);
      expect(queue.pending['tp1']!.attempts, 1);
      expect(queue.pending['tp2']!.attempts, 0);
    });

    test('端末内の画像が消えていたら待ちを捨てる', () async {
      final a = await seed('tp1', 'a.jpg');
      docStates[a.storagePath] = UploadDocState.ready;
      await File(a.localPath).delete();

      await queue.processAll();

      expect(uploaded, isEmpty);
      expect(queue.pending, isEmpty);
      expect(await store.loadAll(), isEmpty);
    });
  });

  group('送信中の置き換え', () {
    test('A の送信中に B へ置き換わったら、A の完了で B を消さない', () async {
      final a = await seed('tp1', 'a.jpg');
      final bPath = pathOf('tp1', 'b.jpg');
      docStates[a.storagePath] = UploadDocState.ready;
      // B の文書の書き込みはまだ届いていない
      docStates[bPath] = UploadDocState.pendingWrite;
      onUpload = (job, bytes) async {
        uploaded.add((storagePath: job.storagePath, bytes: bytes.toList()));
        if (job.storagePath == a.storagePath) {
          await queue.enqueue(
            testPieceId: 'tp1',
            fileName: 'b.jpg',
            storagePath: bPath,
            bytes: Uint8List.fromList([5, 5]),
          );
        }
      };

      await queue.processAll();
      // enqueue が回した processAll の分も終わらせる
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(uploaded.map((u) => u.storagePath), [a.storagePath]);
      final job = queue.pending['tp1']!;
      expect(job.storagePath, bPath);
      expect(await File(job.localPath).readAsBytes(), [5, 5]);
      expect(await File(a.localPath).exists(), isFalse);
      final stored = (await store.loadAll()).single;
      expect(stored.storagePath, bPath);
      // B は改めて調べられ、同期待ちとして残っている
      expect(checked, contains(bPath));
    });

    test('A の送信が失敗しても、置き換わった B に失敗を記録しない', () async {
      final a = await seed('tp1', 'a.jpg');
      final bPath = pathOf('tp1', 'b.jpg');
      docStates[a.storagePath] = UploadDocState.ready;
      docStates[bPath] = UploadDocState.pendingWrite;
      onUpload = (job, bytes) async {
        await queue.enqueue(
          testPieceId: 'tp1',
          fileName: 'b.jpg',
          storagePath: bPath,
          bytes: Uint8List.fromList([5, 5]),
        );
        throw StateError('A failed');
      };

      await queue.processAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final job = queue.pending['tp1']!;
      expect(job.storagePath, bPath);
      expect(job.attempts, 0);
      expect(job.lastError, isNull);
      expect((await store.loadAll()).single.attempts, 0);
    });

    test('A の文書が古いと判定されても、置き換わった B は捨てない', () async {
      final a = await seed('tp1', 'a.jpg');
      final bPath = pathOf('tp1', 'b.jpg');
      docStates[bPath] = UploadDocState.pendingWrite;
      final gate = Completer<void>();
      // A を調べているあいだに B へ置き換わる
      queue.dispose();
      queue = UploadQueue(
        store: store,
        currentUid: () => uid,
        checkDocument: (job) async {
          checked.add(job.storagePath);
          if (job.storagePath == a.storagePath) {
            await gate.future;
            return UploadDocState.stale;
          }
          return docStates[job.storagePath]!;
        },
        upload: (job, bytes) => onUpload(job, bytes),
        onFailure: failures.add,
        retryDelay: const Duration(hours: 1),
      );
      await queue.load();

      final running = queue.processAll();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await queue.enqueue(
        testPieceId: 'tp1',
        fileName: 'b.jpg',
        storagePath: bPath,
        bytes: Uint8List.fromList([5, 5]),
      );
      gate.complete();
      await running;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(queue.pending['tp1']!.storagePath, bPath);
      expect((await store.loadAll()).single.storagePath, bPath);
      expect(await File(queue.pending['tp1']!.localPath).exists(), isTrue);
    });
  });

  group('利用者', () {
    test('別の利用者の待ちは扱わず、端末内に残す', () async {
      final mine = await seed('tp1', 'a.jpg');
      final others = await seed('tp2', 'b.jpg', user: 'other');
      docStates[mine.storagePath] = UploadDocState.ready;
      docStates[others.storagePath] = UploadDocState.ready;

      expect(queue.pending.keys, ['tp1']);

      await queue.processAll();

      expect(checked, [mine.storagePath]);
      expect(uploaded.map((u) => u.storagePath), [mine.storagePath]);
      final stored = await store.loadAll();
      expect(stored.map((j) => j.uid), ['other']);
      expect(await File(others.localPath).exists(), isTrue);

      // 前の利用者が再びサインインすれば送られる
      uid = 'other';
      expect(queue.pending.keys, ['tp2']);
      await queue.processAll();
      expect(uploaded.map((u) => u.storagePath), [
        mine.storagePath,
        others.storagePath,
      ]);
    });

    test('サインアウト中は何もしない', () async {
      await seed('tp1', 'a.jpg');
      uid = null;

      expect(queue.pending, isEmpty);
      await queue.processAll();
      expect(checked, isEmpty);
    });

    test('サインインしていなければ enqueue は失敗する', () async {
      uid = null;
      await expectLater(
        queue.enqueue(
          testPieceId: 'tp1',
          fileName: 'a.jpg',
          storagePath: 'x',
          bytes: Uint8List.fromList([1]),
        ),
        throwsStateError,
      );
      expect(await store.loadAll(), isEmpty);
    });
  });

  group('enqueue と remove', () {
    test('enqueue は端末内に保存し、送信を始める', () async {
      final path = pathOf('tp1', 'a.jpg');
      docStates[path] = UploadDocState.ready;
      var notified = 0;
      queue.addListener(() => notified++);

      await queue.enqueue(
        testPieceId: 'tp1',
        fileName: 'a.jpg',
        storagePath: path,
        bytes: Uint8List.fromList([1, 2]),
      );

      // 保存を終えた時点で待ちに入っている (送信はまだ)
      expect(queue.pending['tp1']!.storagePath, path);
      expect(uploaded, isEmpty);
      expect(notified, greaterThan(0));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(uploaded.map((u) => u.storagePath), [path]);
      expect(queue.pending, isEmpty);
    });

    test('remove は待ちと画像を消す', () async {
      final a = await seed('tp1', 'a.jpg');
      await queue.remove('tp1');

      expect(queue.pending, isEmpty);
      expect(await File(a.localPath).exists(), isFalse);
      expect(await store.loadAll(), isEmpty);
    });

    test('待ちがなければ pending は利用者の ID を調べない', () {
      var calls = 0;
      final q = UploadQueue(
        store: store,
        currentUid: () {
          calls++;
          return 'me';
        },
        checkDocument: (_) async => UploadDocState.ready,
        upload: (_, _) async {},
      );
      expect(q.pending, isEmpty);
      expect(calls, 0);
      q.dispose();
    });

    test('実行中に呼ばれた processAll は、今の処理のあとでもう一度送る', () async {
      final a = await seed('tp1', 'a.jpg');
      docStates[a.storagePath] = UploadDocState.pendingWrite;
      final first = queue.processAll();
      final second = queue.processAll();
      await Future.wait([first, second]);

      expect(checked, [a.storagePath, a.storagePath]);
    });
  });
}
