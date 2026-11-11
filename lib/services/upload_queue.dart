import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';

/// アップロード前に調べるテストピースの文書の状態
enum UploadDocState {
  /// サーバーから読めない (通信できない)
  unreachable,

  /// 文書が存在しない (テストピースは削除されている)
  deleted,

  /// 文書の書き込みがまだサーバーに届いていない
  pendingWrite,

  /// 文書の imagePath が待ちの storagePath と違う (画像が選び直された・外された)
  stale,

  /// 送ってよい
  ready,
}

/// サーバーから読んだ文書の状態を分類する。
///
/// `Source.server` の読み取りは、成功しても端末の未送信の書き込みを重ねて返す。
/// したがって imagePath が一致していても、[hasPendingWrites] が true のあいだは
/// 書き込みがサーバーに届いたことにならない。
UploadDocState classifyTestPieceDocument({
  required bool exists,
  required bool hasPendingWrites,
  required Object? imagePath,
  required String storagePath,
}) {
  if (!exists) return UploadDocState.deleted;
  if (hasPendingWrites) return UploadDocState.pendingWrite;
  if (imagePath != storagePath) return UploadDocState.stale;
  return UploadDocState.ready;
}

/// 通信できないことによる失敗か
bool isNetworkError(Object error) {
  if (error is SocketException) return true;
  if (error is FirebaseException) {
    return const {
      'unavailable',
      'network-request-failed',
      'retry-limit-exceeded',
      'deadline-exceeded',
    }.contains(error.code);
  }
  return false;
}

/// 写真のアップロード待ちを送る層。
///
/// 待ちは [PendingUploadStore] で端末内に保存されており、アプリを閉じても
/// 失われない。[processAll] はテストピースの文書がサーバーに届いたことを
/// 確かめてから、1 件ずつ送る。
///
/// コンストラクタでは path_provider にも FirebaseAuth にも触れない。
/// 待ちの読み込みは [load] で明示的に行う。
class UploadQueue extends ChangeNotifier {
  final PendingUploadStore _store;
  final String? Function() _currentUid;
  final Future<UploadDocState> Function(PendingUpload job) _checkDocument;
  final Future<void> Function(PendingUpload job, Uint8List bytes) _upload;
  final void Function(String message)? _onFailure;
  final Duration _retryDelay;
  final Duration _offlineRetryDelay;

  UploadQueue({
    required PendingUploadStore store,
    required String? Function() currentUid,
    required Future<UploadDocState> Function(PendingUpload job) checkDocument,
    required Future<void> Function(PendingUpload job, Uint8List bytes) upload,
    void Function(String message)? onFailure,
    // 文書の同期待ちは、サーバーに届く状態でしか起きないので長くは続かない。
    // 短い間隔で試し直す (起動直後は、前回の書き込みが届く前に最初の試行が
    // 走るので、ここが長いと写真の送信がその分だけ遅れる)
    Duration retryDelay = const Duration(seconds: 3),
    Duration offlineRetryDelay = const Duration(seconds: 60),
  }) : _store = store,
       _currentUid = currentUid,
       _checkDocument = checkDocument,
       _upload = upload,
       _onFailure = onFailure,
       _retryDelay = retryDelay,
       _offlineRetryDelay = offlineRetryDelay;

  static const failureMessage = '写真のアップロードに失敗しました。あとで再試行します。';

  /// テストピース ID → 待ち (利用者を問わない)
  final Map<String, PendingUpload> _jobs = {};

  bool _running = false;
  bool _rerunRequested = false;
  Timer? _retryTimer;
  bool _disposed = false;

  /// テストピース ID → アップロード待ち。現在の利用者のものだけ。
  Map<String, PendingUpload> get pending {
    // 待ちがなければ認証に触れない (テストでプラグインなしに動くように)
    if (_jobs.isEmpty) return const {};
    final uid = _currentUid();
    if (uid == null) return const {};
    return Map.unmodifiable({
      for (final e in _jobs.entries)
        if (e.value.uid == uid) e.key: e.value,
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 端末内に保存されている待ちを読み込む。
  Future<void> load() async {
    try {
      final loaded = await _store.loadAll();
      for (final job in loaded) {
        // 読み込みの最中に enqueue されたものを古い内容で上書きしない
        _jobs.putIfAbsent(job.testPieceId, () => job);
      }
      _notify();
    } catch (e) {
      debugPrint('Failed to load pending uploads: $e');
    }
  }

  /// 画像を端末内に保存して待ちに入れる。保存を終えたら、送信は待たずに返る。
  Future<void> enqueue({
    required String testPieceId,
    required String fileName,
    required String storagePath,
    required Uint8List bytes,
  }) async {
    final uid = _currentUid();
    if (uid == null) throw StateError('User not logged in');
    final job = await _store.save(
      uid: uid,
      testPieceId: testPieceId,
      fileName: fileName,
      storagePath: storagePath,
      bytes: bytes,
    );
    _jobs[testPieceId] = job;
    _notify();
    // 呼び出し側 (編集画面) が Firestore への書き込みを発火してから送り始める
    // よう、イベントキューに回す
    Timer.run(() => processAll());
  }

  /// テストピースの待ちを消す (テストピースの削除時)。
  Future<void> remove(String testPieceId) async {
    _jobs.remove(testPieceId);
    _notify();
    await _store.remove(testPieceId);
  }

  /// 待ちになっているものを順に送る。実行中に呼ばれたら、今の処理のあとで
  /// もう一度送る。
  Future<void> processAll() async {
    if (_disposed) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _running = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    var reachable = true;
    var waitingForSync = false;
    try {
      do {
        _rerunRequested = false;
        final uid = _currentUid();
        if (uid == null) break;
        final jobs = _jobs.values.where((job) => job.uid == uid).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        waitingForSync = false;
        for (final job in jobs) {
          if (_disposed) return;
          UploadDocState outcome;
          try {
            outcome = await _processOne(job);
          } catch (e) {
            // 1 件の想定外の失敗で、残りの待ちを止めない
            debugPrint('Pending upload failed unexpectedly: $e');
            continue;
          }
          if (outcome == UploadDocState.unreachable) {
            reachable = false;
            break;
          }
          if (outcome == UploadDocState.pendingWrite) waitingForSync = true;
        }
      } while (reachable && _rerunRequested && !_disposed);
    } finally {
      _running = false;
    }
    if (_disposed) return;
    // 実行中に届いた要求 (通信の回復など) が、通信不可での打ち切りで
    // 処理されないまま残っていたら、もう一度回す
    if (_rerunRequested) {
      _rerunRequested = false;
      Timer.run(processAll);
      return;
    }
    if (pending.isEmpty) return;
    if (!reachable) {
      // 通信の回復の通知は、接続の種類が変わったときにしか来ない。同じ接続の
      // まま疎通だけが戻った場合に備えて、間隔を空けて試し直す
      _retryTimer = Timer(_offlineRetryDelay, processAll);
    } else if (waitingForSync) {
      // 文書の同期待ちが残り、通信は可能だったら、少し待ってもう一度
      _retryTimer = Timer(_retryDelay, processAll);
    }
  }

  /// 1 件を処理し、文書の状態を返す。
  Future<UploadDocState> _processOne(PendingUpload job) async {
    // 処理の順番が来るまでに置き換え・削除されていたら何もしない
    if (_jobs[job.testPieceId]?.storagePath != job.storagePath) {
      return UploadDocState.stale;
    }
    // 利用者が切り替わっていたら、この回を打ち切る
    if (_currentUid() != job.uid) return UploadDocState.unreachable;

    UploadDocState state;
    try {
      state = await _checkDocument(job);
    } catch (e) {
      debugPrint('Pending upload check failed: $e');
      state = UploadDocState.unreachable;
    }
    // 文書を読んでいるあいだに利用者が切り替わっていたら、読んだのは別の
    // 利用者の領域かもしれない。結果を使わず (待ちを捨てず)、この回を打ち切る
    if (_currentUid() != job.uid) return UploadDocState.unreachable;

    switch (state) {
      case UploadDocState.unreachable:
      case UploadDocState.pendingWrite:
        return state;
      case UploadDocState.deleted:
      case UploadDocState.stale:
        await _discardIfCurrent(job);
        return state;
      case UploadDocState.ready:
        break;
    }

    final file = File(job.localPath);
    final Uint8List bytes;
    try {
      if (!await file.exists()) {
        // 端末内の画像が消えていたら、待ちを捨てる
        await _discardIfCurrent(job);
        return UploadDocState.stale;
      }
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint('Failed to read pending image ${job.localPath}: $e');
      return UploadDocState.ready;
    }

    // 読んでいるあいだにサインアウト・切り替えがあれば送らない
    if (_currentUid() != job.uid) return UploadDocState.ready;

    try {
      await _upload(job, bytes);
    } catch (e) {
      final network = isNetworkError(e);
      PendingUpload? updated;
      try {
        updated = await _store.recordFailure(
          job.testPieceId,
          job.storagePath,
          e.toString(),
        );
      } catch (recordError) {
        debugPrint('Failed to record upload failure: $recordError');
      }
      if (updated != null &&
          _jobs[job.testPieceId]?.storagePath == job.storagePath) {
        _jobs[job.testPieceId] = updated;
        _notify();
      }
      if (network) return UploadDocState.unreachable;
      _onFailure?.call(failureMessage);
      return UploadDocState.ready;
    }

    await _discardIfCurrent(job);
    return UploadDocState.ready;
  }

  /// 現在の待ちが同じ storagePath のときだけ、待ちと画像を消す。
  Future<void> _discardIfCurrent(PendingUpload job) async {
    await _store.removeIfCurrent(job.testPieceId, job.storagePath);
    if (_jobs[job.testPieceId]?.storagePath == job.storagePath) {
      _jobs.remove(job.testPieceId);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }
}
