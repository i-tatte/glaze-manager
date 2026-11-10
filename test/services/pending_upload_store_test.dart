import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late PendingUploadStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pending_upload_store_');
    store = PendingUploadStore(baseDirectory: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Directory jobDir(String testPieceId) =>
      Directory(p.join(tempDir.path, 'pending_uploads', testPieceId));

  Future<PendingUpload> save(
    String testPieceId,
    String fileName, {
    String uid = 'u1',
    List<int> bytes = const [1, 2, 3],
  }) => store.save(
    uid: uid,
    testPieceId: testPieceId,
    fileName: fileName,
    storagePath: 'users/$uid/test_pieces/images/$testPieceId/$fileName',
    bytes: Uint8List.fromList(bytes),
  );

  test('保存先がなければ空', () async {
    expect(await store.loadAll(), isEmpty);
  });

  test('保存した待ちと画像を読み込める', () async {
    final job = await save('tp1', 'a.jpg', bytes: [9, 8, 7]);

    expect(job.localPath, p.join(jobDir('tp1').path, 'a.jpg'));
    expect(await File(job.localPath).readAsBytes(), [9, 8, 7]);

    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
    final got = loaded.single;
    expect(got.uid, 'u1');
    expect(got.testPieceId, 'tp1');
    expect(got.fileName, 'a.jpg');
    expect(got.storagePath, 'users/u1/test_pieces/images/tp1/a.jpg');
    expect(got.localPath, job.localPath);
    expect(got.attempts, 0);
    expect(got.lastError, isNull);
  });

  test('同じテストピースに保存し直すと、古い待ちと画像を置き換える', () async {
    final a = await save('tp1', 'a.jpg');
    final b = await save('tp1', 'b.jpg', bytes: [4, 5]);

    expect(await File(a.localPath).exists(), isFalse);
    expect(await File(b.localPath).readAsBytes(), [4, 5]);
    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.fileName, 'b.jpg');
    // ディレクトリには新しい画像と job.json だけが残る
    final names = jobDir(
      'tp1',
    ).listSync().map((e) => p.basename(e.path)).toSet();
    expect(names, {'b.jpg', 'job.json'});
  });

  test('テストピースごとに別の待ちを持つ', () async {
    await save('tp1', 'a.jpg');
    await save('tp2', 'b.jpg', uid: 'u2');

    final loaded = await store.loadAll();
    expect(loaded.map((j) => j.testPieceId).toSet(), {'tp1', 'tp2'});
  });

  test('remove は無条件に消す', () async {
    await save('tp1', 'a.jpg');
    await store.remove('tp1');

    expect(await jobDir('tp1').exists(), isFalse);
    expect(await store.loadAll(), isEmpty);
  });

  test('removeIfCurrent は storagePath が一致するときだけ消す', () async {
    final a = await save('tp1', 'a.jpg');
    final b = await save('tp1', 'b.jpg');

    // 置き換え前の A の完了では B を消さない
    expect(await store.removeIfCurrent('tp1', a.storagePath), isFalse);
    expect(await File(b.localPath).exists(), isTrue);
    expect((await store.loadAll()).single.fileName, 'b.jpg');

    expect(await store.removeIfCurrent('tp1', b.storagePath), isTrue);
    expect(await jobDir('tp1').exists(), isFalse);
  });

  test('recordFailure は storagePath が一致するときだけ記録する', () async {
    final a = await save('tp1', 'a.jpg');
    final b = await save('tp1', 'b.jpg');

    expect(await store.recordFailure('tp1', a.storagePath, 'old'), isNull);
    expect((await store.loadAll()).single.attempts, 0);

    final updated = await store.recordFailure('tp1', b.storagePath, 'boom');
    expect(updated!.attempts, 1);
    expect(updated.lastError, 'boom');
    final loaded = (await store.loadAll()).single;
    expect(loaded.attempts, 1);
    expect(loaded.lastError, 'boom');
    expect(loaded.hasFailed, isTrue);

    final again = await store.recordFailure('tp1', b.storagePath, 'boom2');
    expect(again!.attempts, 2);
    expect(again.lastError, 'boom2');
  });

  test('待ちがないテストピースへの操作は何もしない', () async {
    expect(await store.removeIfCurrent('none', 'x'), isFalse);
    expect(await store.recordFailure('none', 'x', 'e'), isNull);
    await store.remove('none');
  });

  test('壊れた job.json は読み飛ばす', () async {
    await save('tp1', 'a.jpg');
    final broken = jobDir('tp2');
    await broken.create(recursive: true);
    await File(p.join(broken.path, 'job.json')).writeAsString('{not json');

    final loaded = await store.loadAll();
    expect(loaded.map((j) => j.testPieceId), ['tp1']);
  });

  test('並行して呼んでも置き換えと削除が交錯しない', () async {
    final a = await save('tp1', 'a.jpg');
    // A の完了の記録と B への置き換えを同時に始める
    final results = await Future.wait([
      store.removeIfCurrent('tp1', a.storagePath),
      save('tp1', 'b.jpg'),
      store.removeIfCurrent('tp1', a.storagePath),
    ]);

    expect(results.first, isTrue);
    final loaded = await store.loadAll();
    expect(loaded.single.fileName, 'b.jpg');
    expect(await File(loaded.single.localPath).exists(), isTrue);
  });
}
