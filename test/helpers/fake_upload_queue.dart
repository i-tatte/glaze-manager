import 'package:flutter/foundation.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';
import 'package:glaze_manager/services/upload_queue.dart';

/// プラグインにもファイルにも触れない UploadQueue。
/// 画面のテストで uploadQueueProvider を差し替えるのに使う。
class FakeUploadQueue extends UploadQueue {
  FakeUploadQueue({Map<String, PendingUpload> pending = const {}})
    : _pending = Map.of(pending),
      super(
        store: PendingUploadStore(
          baseDirectory: () => throw UnimplementedError(),
        ),
        currentUid: () => 'test-user',
        checkDocument: (_) async => UploadDocState.unreachable,
        upload: (_, _) async {},
      );

  final Map<String, PendingUpload> _pending;

  int loadCount = 0;
  int processAllCount = 0;
  final List<({String testPieceId, String fileName, String storagePath})>
  enqueued = [];
  final List<String> removed = [];

  @override
  Map<String, PendingUpload> get pending => Map.unmodifiable(_pending);

  @override
  Future<void> load() async => loadCount++;

  @override
  Future<void> processAll() async => processAllCount++;

  @override
  Future<void> enqueue({
    required String testPieceId,
    required String fileName,
    required String storagePath,
    required Uint8List bytes,
  }) async {
    enqueued.add((
      testPieceId: testPieceId,
      fileName: fileName,
      storagePath: storagePath,
    ));
  }

  @override
  Future<void> remove(String testPieceId) async {
    removed.add(testPieceId);
    _pending.remove(testPieceId);
    notifyListeners();
  }
}
