import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 端末内に保存したアップロード待ちの 1 件。
@immutable
class PendingUpload {
  final String uid;
  final String testPieceId;

  /// アップロード先のファイル名
  final String fileName;

  /// アップロード先のパス (テストピースの imagePath と同じ値)
  final String storagePath;

  /// 端末内の画像ファイルのパス
  final String localPath;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  const PendingUpload({
    required this.uid,
    required this.testPieceId,
    required this.fileName,
    required this.storagePath,
    required this.localPath,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  /// 直前の送信が失敗しているか
  bool get hasFailed => lastError != null;

  PendingUpload copyWith({int? attempts, String? lastError}) => PendingUpload(
    uid: uid,
    testPieceId: testPieceId,
    fileName: fileName,
    storagePath: storagePath,
    localPath: localPath,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
  );

  /// job.json に書く内容。localPath は保存先のディレクトリから導くので書かない。
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'testPieceId': testPieceId,
    'fileName': fileName,
    'storagePath': storagePath,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  /// job.json から読む。必須の値が欠けていれば null。
  static PendingUpload? tryFromJson(Map<String, dynamic> json, String dirPath) {
    final uid = json['uid'];
    final testPieceId = json['testPieceId'];
    final fileName = json['fileName'];
    final storagePath = json['storagePath'];
    if (uid is! String ||
        testPieceId is! String ||
        fileName is! String ||
        storagePath is! String) {
      return null;
    }
    final attempts = json['attempts'];
    final lastError = json['lastError'];
    return PendingUpload(
      uid: uid,
      testPieceId: testPieceId,
      fileName: fileName,
      storagePath: storagePath,
      localPath: p.join(dirPath, fileName),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      attempts: attempts is num ? attempts.toInt() : 0,
      lastError: lastError is String ? lastError : null,
    );
  }
}

/// アップロード待ちを端末内に保存する層。
///
/// 保存先は `{baseDirectory}/pending_uploads/{testPieceId}/` で、画像を
/// [PendingUpload.fileName] の名前で、情報を `job.json` として置く。
/// 待ちはテストピースにつき 1 つ。
///
/// 送信の完了 ([removeIfCurrent]) と失敗の記録 ([recordFailure]) は、
/// 現在の待ちの storagePath が一致するときだけ反映する。画像 A の送信中に
/// 画像 B へ置き換わった場合に、A の完了で B を消さないためである。
///
/// 同じディレクトリへの読み書きが交錯しないよう、すべての操作を直列に行う。
class PendingUploadStore {
  static const _rootDirName = 'pending_uploads';
  static const _jobFileName = 'job.json';

  final Future<Directory> Function() _baseDirectory;

  /// 保存先のディレクトリを返す関数を注入できる (テスト用)。
  /// 省略時は path_provider の getApplicationSupportDirectory を使う。
  /// コンストラクタでは呼ばない。
  PendingUploadStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  Future<void> _tail = Future.value();

  /// 操作を直列に実行する
  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<Directory> _rootDir() async {
    final base = await _baseDirectory();
    return Directory(p.join(base.path, _rootDirName));
  }

  Future<Directory> _jobDir(String testPieceId) async {
    final root = await _rootDir();
    return Directory(p.join(root.path, testPieceId));
  }

  Future<PendingUpload?> _readJob(Directory dir) async {
    final file = File(p.join(dir.path, _jobFileName));
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return PendingUpload.tryFromJson(json, dir.path);
    } catch (e) {
      debugPrint('Failed to read pending upload ${dir.path}: $e');
      return null;
    }
  }

  /// job.json を書く。途中で落ちても壊れた job.json が残らないよう、
  /// 一時ファイルに書いてから置き換える。
  Future<void> _writeJob(Directory dir, PendingUpload job) async {
    final tmp = File(p.join(dir.path, '$_jobFileName.tmp'));
    await tmp.writeAsString(jsonEncode(job.toJson()), flush: true);
    // rename は既存の job.json を置き換える (dart:io の File.rename の仕様)
    await tmp.rename(p.join(dir.path, _jobFileName));
  }

  /// 保存されているすべての待ち (利用者を問わない)
  Future<List<PendingUpload>> loadAll() => _serialized(() async {
    final root = await _rootDir();
    if (!await root.exists()) return <PendingUpload>[];
    final jobs = <PendingUpload>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final job = await _readJob(entity);
      if (job != null) jobs.add(job);
    }
    jobs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return jobs;
  });

  /// 画像を端末内に保存し、待ちを作る。同じテストピースの古い待ちと
  /// その画像は、新しい待ちを書き終えたあとで消す。
  Future<PendingUpload> save({
    required String uid,
    required String testPieceId,
    required String fileName,
    required String storagePath,
    required Uint8List bytes,
  }) => _serialized(() async {
    final dir = await _jobDir(testPieceId);
    await dir.create(recursive: true);

    final imageFile = File(p.join(dir.path, fileName));
    await imageFile.writeAsBytes(bytes, flush: true);

    final job = PendingUpload(
      uid: uid,
      testPieceId: testPieceId,
      fileName: fileName,
      storagePath: storagePath,
      localPath: imageFile.path,
      createdAt: DateTime.now(),
    );
    await _writeJob(dir, job);

    // 古い画像を消す (新しい画像と job.json 以外)
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (name == fileName || name == _jobFileName) continue;
      try {
        await entity.delete(recursive: true);
      } catch (e) {
        debugPrint('Failed to delete old pending file ${entity.path}: $e');
      }
    }
    return job;
  });

  Future<void> _deleteDir(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('Failed to delete pending upload ${dir.path}: $e');
    }
  }

  /// テストピースの待ちを無条件に消す (テストピースの削除時)。
  Future<void> remove(String testPieceId) => _serialized(() async {
    await _deleteDir(await _jobDir(testPieceId));
  });

  /// 現在の待ちの storagePath が一致するときだけ消す (送信の完了時など)。
  /// 消したら true を返す。
  Future<bool> removeIfCurrent(String testPieceId, String storagePath) =>
      _serialized(() async {
        final dir = await _jobDir(testPieceId);
        final current = await _readJob(dir);
        if (current == null || current.storagePath != storagePath) {
          return false;
        }
        await _deleteDir(dir);
        return true;
      });

  /// 送信の失敗を記録する。現在の待ちの storagePath が一致するときだけ
  /// 反映し、更新後の待ちを返す。一致しなければ null。
  Future<PendingUpload?> recordFailure(
    String testPieceId,
    String storagePath,
    String error,
  ) => _serialized(() async {
    final dir = await _jobDir(testPieceId);
    final current = await _readJob(dir);
    if (current == null || current.storagePath != storagePath) return null;
    final updated = current.copyWith(
      attempts: current.attempts + 1,
      lastError: error,
    );
    await _writeJob(dir, updated);
    return updated;
  });
}
