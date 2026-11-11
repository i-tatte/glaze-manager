// 実機 (Windows など) の Firebase SDK が、アップロード待ちの仕組みが前提と
// している通りに動くかを確かめる。Firebase エミュレータを起動してから実行する。
//
//   flutter test integration_test/sdk_semantics_test.dart -d windows
//
// GM_MODE で確かめる内容を切り替える。
//   online        (既定) サーバーに届く状態での読み書きの順序と、型の往復
//   offline_write  Firestore に届かない状態で書き込み、そのまま終了する
//                  (GM_FIRESTORE_PORT に誰も待ち受けていないポートを渡す)
//   after_restart  offline_write のあとで起動し直し、書き込みが残っていて
//                  サーバーに届くことを確かめる
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'support/emulator_env.dart';

const _mode = String.fromEnvironment('GM_MODE', defaultValue: 'online');
const _server = GetOptions(source: Source.server);
const _cache = GetOptions(source: Source.cache);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SDK semantics ($_mode)', (tester) async {
    await initFirebaseForEmulators();
    final report = Report('sdk_semantics_$_mode');
    try {
      switch (_mode) {
        case 'online':
          await _online(report);
        case 'offline_write':
          await _offlineWrite(report);
        case 'after_restart':
          await _afterRestart(report);
        default:
          fail('unknown GM_MODE: $_mode');
      }
    } finally {
      await report.flush();
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

CollectionReference<Map<String, dynamic>> _testPieces(String uid) =>
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('test_pieces');

Future<void> _online(Report report) async {
  // --- 保存先のディレクトリ ---
  final support = await getApplicationSupportDirectory();
  report.add('appSupportDir', support.path);
  final probeDir = Directory(p.join(support.path, 'integration_test_probe'));
  final probe = File(p.join(probeDir.path, 'probe.txt'));
  await probe.create(recursive: true);
  await probe.writeAsString('ok', flush: true);
  expect(await probe.readAsString(), 'ok');
  await probeDir.delete(recursive: true);

  final user = await signUpFreshUser();
  final uid = user.uid;
  report.add('uid', uid);
  final col = _testPieces(uid);

  // アプリと同じく、一覧の購読を張ったままにする (監視のストリームが開いた状態)
  final subscription = col.snapshots().listen((_) {});

  // --- 書き込みの直後にサーバーから読むと、未送信として見えるか ---
  Future<Map<String, Object?>> raceOnce(String label) async {
    final ref = col.doc();
    final watch = Stopwatch()..start();
    int? ackMs;
    final write = ref.set({'imagePath': 'p-$label', 'n': 1});
    unawaited(write.then((_) => ackMs = watch.elapsedMilliseconds));
    final snap = await ref.get(_server);
    final checkMs = watch.elapsedMilliseconds;
    expect(snap.exists, isTrue, reason: '未送信の書き込みは重ねて返る');
    final pendingAtCheck = snap.metadata.hasPendingWrites;
    final ackedBeforeCheck = ackMs != null;
    await write;
    final after = await ref.get(_server);
    expect(after.exists, isTrue);
    expect(
      after.metadata.hasPendingWrites,
      isFalse,
      reason: '書き込みの完了後は未送信に見えてはならない',
    );
    return {
      'label': label,
      'pendingAtFirstCheck': pendingAtCheck,
      'ackedBeforeCheckReturned': ackedBeforeCheck,
      'checkMs': checkMs,
      'ackMs': ackMs,
    };
  }

  final warm = <Map<String, Object?>>[];
  for (var i = 0; i < 20; i++) {
    warm.add(await raceOnce('warm$i'));
  }
  report.add(
    'race_warm_pendingAtFirstCheck',
    '${warm.where((r) => r['pendingAtFirstCheck'] == true).length}/20',
  );
  report.add('race_warm_samples', warm.take(5).toList());

  // 書き込みのストリームは 60 秒使われないと閉じる。入力に 1 分以上かけてから
  // 保存する、という普通の使い方に当たる
  await Future<void>.delayed(const Duration(seconds: 75));
  final idle = await raceOnce('idle');
  report.add('race_afterIdle', idle);

  // --- 既存の文書の更新 (画像の差し替え) の直後 ---
  final existing = col.doc();
  await existing.set({'imagePath': 'old', 'imageUrl': 'url-old'});
  final update = existing.update({'imagePath': 'new'});
  final duringUpdate = await existing.get(_server);
  report.add('update_valueAtFirstCheck', duringUpdate.data()?['imagePath']);
  report.add(
    'update_pendingAtFirstCheck',
    duringUpdate.metadata.hasPendingWrites,
  );
  // 新しい imagePath が見えているのに未送信でない、という組み合わせは
  // 「届いた」と判断してよい。古い値のまま未送信でない、は起きてはならない
  if (!duringUpdate.metadata.hasPendingWrites) {
    expect(duringUpdate.data()?['imagePath'], 'new');
  }
  await update;
  final afterUpdate = await existing.get(_server);
  expect(afterUpdate.data()?['imagePath'], 'new');
  expect(afterUpdate.metadata.hasPendingWrites, isFalse);

  // --- 存在しない文書 ---
  final missing = await col.doc('does-not-exist').get(_server);
  expect(missing.exists, isFalse);
  expect(missing.metadata.hasPendingWrites, isFalse);

  // --- 通信を止めたとき ---
  await FirebaseFirestore.instance.disableNetwork();
  final offlineWatch = Stopwatch()..start();
  Object? offlineError;
  try {
    await existing.get(_server);
  } catch (e) {
    offlineError = e;
  }
  report.add('disableNetwork_serverGet_ms', offlineWatch.elapsedMilliseconds);
  report.add(
    'disableNetwork_serverGet_error',
    offlineError == null ? 'no error' : describeError(offlineError),
  );
  expect(offlineError, isNotNull, reason: '通信できなければ失敗するはず');

  final offlineRef = col.doc();
  final offlineWrite = offlineRef.set({'imagePath': 'offline'});
  final cached = await offlineRef.get(_cache);
  expect(cached.exists, isTrue);
  expect(cached.metadata.hasPendingWrites, isTrue);
  await FirebaseFirestore.instance.enableNetwork();
  await offlineWrite.timeout(const Duration(seconds: 30));
  final afterOnline = await offlineRef.get(_server);
  expect(afterOnline.metadata.hasPendingWrites, isFalse);

  // --- モデルの型の往復 (実機の SDK は入れ子の Map の型が偽物と違いうる) ---
  final snapshot = TestPieceSnapshot(
    glaze: GlazeSnapshot(
      glazeId: 'g1',
      name: '青磁',
      registeredName: null,
      lines: const [
        RecipeLine(materialId: 'm1', name: '長石', category: 'base', amount: 60),
        RecipeLine(
          materialId: 'm2',
          name: '酸化鉄',
          category: 'pigment',
          amount: 1.5,
        ),
      ],
    ),
    additionalGlazes: [
      GlazeSnapshot(
        glazeId: 'g2',
        name: '白萩',
        lines: const [
          RecipeLine(
            materialId: 'm3',
            name: '藁灰',
            category: 'base',
            amount: 30,
          ),
        ],
      ),
    ],
    clayName: '信楽白',
    source: SnapshotSource.saved,
    takenAt: Timestamp.fromMillisecondsSinceEpoch(1790000000000),
  );
  final piece = TestPiece(
    glazeId: 'g1',
    additionalGlazeIds: const ['g2'],
    clayId: 'c1',
    imagePath: 'users/$uid/test_pieces/images/x/y.jpg',
    colorData: [LabColor(l: 50, a: 1.5, b: -2, percentage: 100)],
    note: 'メモ',
    createdAt: Timestamp.fromMillisecondsSinceEpoch(1790000000000),
    snapshot: snapshot,
    rating: 4,
    label: '20261111-01',
    firingId: 'f1',
  );
  final roundTripRef = col.doc();
  await roundTripRef.set(piece.toFirestore());
  final read = TestPiece.fromFirestore(await roundTripRef.get(_server));
  expect(read.glazeId, 'g1');
  expect(read.additionalGlazeIds, ['g2']);
  expect(read.rating, 4);
  expect(read.label, '20261111-01');
  expect(read.firingId, 'f1');
  expect(read.colorData!.single.b, -2);
  expect(read.snapshot!.source, SnapshotSource.saved);
  expect(read.snapshot!.clayName, '信楽白');
  expect(read.snapshot!.takenAt, snapshot.takenAt);
  expect(read.snapshot!.glaze!.lines.map((l) => l.amount), [60, 1.5]);
  expect(read.snapshot!.glaze!.lines.last.category, 'pigment');
  expect(read.snapshot!.additionalGlazes.single.name, '白萩');

  // 部分更新 (null で欄を空にする、写しを置き換える)
  final batch = FirebaseFirestore.instance.batch();
  batch.update(roundTripRef, {
    'snapshot': snapshot
        .replacingGlaze(
          GlazeSnapshot(
            glazeId: 'g1',
            name: '青磁',
            lines: const [
              RecipeLine(
                materialId: 'm1',
                name: '長石',
                category: 'base',
                amount: 55,
              ),
            ],
          ),
          source: SnapshotSource.corrected,
        )
        .toMap(),
  });
  await batch.commit();
  await roundTripRef.update(
    TestPiece(
      glazeId: 'g1',
      clayId: 'c1',
      createdAt: piece.createdAt,
      rating: null,
      label: null,
      firingId: null,
    ).toUpdateFields(
      includeImagePath: false,
      includeColorData: false,
      includeSnapshot: false,
    ),
  );
  final updated = TestPiece.fromFirestore(await roundTripRef.get(_server));
  expect(updated.snapshot!.source, SnapshotSource.corrected);
  expect(updated.snapshot!.glaze!.lines.single.amount, 55);
  expect(updated.snapshot!.additionalGlazes.single.name, '白萩');
  expect(updated.rating, isNull);
  expect(updated.label, isNull);
  expect(updated.firingId, isNull);
  expect(updated.additionalGlazeIds, isEmpty);
  // 部分更新は、送らなかった欄 (Cloud Functions が書く値など) を消さない
  expect(updated.imagePath, piece.imagePath);
  expect(updated.colorData!.single.l, 50);
  final serverSide = await adminGetDoc(
    'users/$uid/test_pieces/${roundTripRef.id}',
  );
  report.add(
    'roundTrip_serverTypes',
    '${(serverSide!['snapshot'] as Map)['glaze']}',
  );

  await subscription.cancel();
  report.add('result', 'ok');
}

Future<void> _offlineWrite(Report report) async {
  expect(
    sdkFirestorePort,
    isNot(liveFirestorePort),
    reason: 'このモードは、誰も待ち受けていないポートを渡して動かす',
  );
  final user = await signUpFreshUser();
  final uid = user.uid;
  final col = _testPieces(uid);

  // サーバーに届かない状態での、サーバーからの読み取り
  final watch = Stopwatch()..start();
  Object? error;
  try {
    await col.doc('anything').get(_server);
  } catch (e) {
    error = e;
  }
  report.add('unreachable_serverGet_ms', watch.elapsedMilliseconds);
  report.add(
    'unreachable_serverGet_error',
    error == null ? 'no error' : describeError(error),
  );
  expect(error, isNotNull);

  // 一覧の読み取り (写しの埋め込みが使う)
  final listWatch = Stopwatch()..start();
  Object? listError;
  try {
    await col.get(_server);
  } catch (e) {
    listError = e;
  }
  report.add('unreachable_serverQuery_ms', listWatch.elapsedMilliseconds);
  report.add(
    'unreachable_serverQuery_error',
    listError == null ? 'no error' : describeError(listError),
  );
  expect(listError, isNotNull);

  // 書き込む。完了は待てない (サーバーに届かない)
  final ids = <String>[];
  for (var i = 0; i < 3; i++) {
    final ref = col.doc();
    ids.add(ref.id);
    unawaited(
      ref.set({'imagePath': 'offline-$i', 'n': i, 'writtenOffline': true}),
    );
  }
  for (final id in ids) {
    final cached = await col.doc(id).get(_cache);
    expect(cached.exists, isTrue);
    expect(cached.metadata.hasPendingWrites, isTrue);
  }
  // 未送信の書き込みがある文書を、届かないサーバーから読もうとした場合
  final pendingWatch = Stopwatch()..start();
  Object? pendingError;
  DocumentSnapshot<Map<String, dynamic>>? pendingSnap;
  try {
    pendingSnap = await col.doc(ids.first).get(_server);
  } catch (e) {
    pendingError = e;
  }
  report.add(
    'unreachable_serverGet_pendingDoc_ms',
    pendingWatch.elapsedMilliseconds,
  );
  report.add(
    'unreachable_serverGet_pendingDoc',
    pendingError != null
        ? describeError(pendingError)
        : 'returned exists=${pendingSnap!.exists} '
              'pending=${pendingSnap.metadata.hasPendingWrites} '
              'fromCache=${pendingSnap.metadata.isFromCache}',
  );

  await writeState('sdk_semantics', {'uid': uid, 'ids': ids});
  // 端末内の保存が済むのを少し待ってから終える (このあとプロセスは止められる)
  await Future<void>.delayed(const Duration(seconds: 2));
  report.add('uid', uid);
  report.add('result', 'ok');
}

Future<void> _afterRestart(Report report) async {
  final state = await readState('sdk_semantics');
  final uid = state['uid'] as String;
  final ids = (state['ids'] as List).cast<String>();

  // サインインし直さなくても、前回の利用者に戻っていること
  final restored = await FirebaseAuth.instance.authStateChanges().first.timeout(
    const Duration(seconds: 30),
  );
  report.add('restoredUid', restored?.uid);
  expect(restored?.uid, uid, reason: 'サインイン状態が再起動をまたいで残る');

  // 起動直後、こちらからは何も書かない。前回の未送信の書き込みが残って
  // いれば、サーバーに届く
  final col = _testPieces(uid);
  final first = await col
      .doc(ids.first)
      .get(_cache)
      .then<Object?>(
        (s) => 'exists=${s.exists} pending=${s.metadata.hasPendingWrites}',
        onError: (Object e) => describeError(e),
      );
  report.add('afterRestart_cacheState', first);

  final arrived = await waitUntil(() async {
    for (final id in ids) {
      if (await adminGetDoc('users/$uid/test_pieces/$id') == null) {
        return false;
      }
    }
    return true;
  }, timeout: const Duration(seconds: 90));
  report.add('afterRestart_arrivedOnServer_ms', arrived?.inMilliseconds);
  expect(arrived, isNotNull, reason: 'オフラインで書いた文書が、再起動後にサーバーへ届く');

  for (final id in ids) {
    final server = await adminGetDoc('users/$uid/test_pieces/$id');
    expect(server!['writtenOffline'], isTrue);
  }
  final settled = await waitUntil(() async {
    final snap = await col.doc(ids.first).get(_server);
    return snap.exists && !snap.metadata.hasPendingWrites;
  }, timeout: const Duration(seconds: 60));
  report.add('afterRestart_noPendingWrites_ms', settled?.inMilliseconds);
  expect(settled, isNotNull);
  report.add('result', 'ok');
}
