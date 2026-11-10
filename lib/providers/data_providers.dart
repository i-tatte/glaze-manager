import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/auth_service.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/services/pending_upload_store.dart';
import 'package:glaze_manager/services/upload_queue.dart';
import 'package:glaze_manager/services/settings_service.dart';
import 'package:glaze_manager/services/storage_service.dart';

/// アプリスコープのデータ層プロバイダ群。
///
/// 主要コレクションの購読をここに集約し、各画面は `ref.watch` で参照する。
/// これにより:
///  - 同じコレクションを画面ごとに重複購読しない (読み取り課金・メモリの節約)
///  - どの画面でも常に最新データが見える (画面ローカルのスナップショット固定を排除)
///  - サインイン/アウトで自動的に購読が張り直される
///
/// テストでは `firestoreServiceProvider` と `authStateChangesProvider` を
/// override して使う。

final settingsServiceProvider = ChangeNotifierProvider<SettingsService>(
  (ref) => SettingsService(),
);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

/// 通信状態の変化。テストでは空のストリームに差し替える
/// (プラグインのない環境で MissingPluginException を出さないため)。
final connectivityChangesProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// 写真のアップロードの失敗を利用者に知らせる関数。
/// アプリでは main.dart が scaffoldMessengerKey の SnackBar に差し替える。
final uploadFailureReporterProvider = Provider<void Function(String message)>(
  (ref) => (_) {},
);

/// 写真のアップロード待ち。
///
/// 生成時にはプラグインにも認証にも触れない。待ちの読み込みは
/// MainTabScreen が load() で行う。
final uploadQueueProvider = ChangeNotifierProvider<UploadQueue>((ref) {
  return UploadQueue(
    store: PendingUploadStore(),
    currentUid: () => FirebaseAuth.instance.currentUser?.uid,
    checkDocument: (job) async {
      final snapshot = await ref
          .read(firestoreServiceProvider)
          .testPieces
          .getFromServer(job.testPieceId);
      return classifyTestPieceDocument(
        exists: snapshot.exists,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        imagePath: snapshot.data()?['imagePath'],
        storagePath: job.storagePath,
      );
    },
    upload: (job, bytes) async {
      final storage = ref.read(storageServiceProvider);
      // 送り先は待ちに記録したパスと同じでなければならない
      // (別の利用者に切り替わっていたら送らない)
      final path = storage.getUploadPath(
        testPieceId: job.testPieceId,
        name: job.fileName,
      );
      if (path != job.storagePath) {
        throw StateError('Upload path mismatch: $path != ${job.storagePath}');
      }
      await storage.uploadTestPieceImage(
        testPieceId: job.testPieceId,
        name: job.fileName,
        bytes: bytes,
        mimeType: 'image/jpeg',
      );
    },
    onFailure: (message) => ref.read(uploadFailureReporterProvider)(message),
  );
});

/// 認証状態。各コレクションのプロバイダはこれをwatchすることで、
/// ユーザーが切り替わったときに購読を張り直す。
final authStateChangesProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

// --- コレクションのリアルタイム購読 ---

final glazesProvider = StreamProvider<List<Glaze>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getGlazes();
});

final testPiecesProvider = StreamProvider<List<TestPiece>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getTestPieces();
});

final materialsProvider = StreamProvider<List<Material>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getMaterials();
});

final claysProvider = StreamProvider<List<Clay>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getClays();
});

final firingAtmospheresProvider = StreamProvider<List<FiringAtmosphere>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getFiringAtmospheres();
});

final firingProfilesProvider = StreamProvider<List<FiringProfile>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getFiringProfiles();
});

/// 焼成回の一覧 (焼成日の新しい順)
final firingsProvider = StreamProvider<List<Firing>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getFirings();
});

final tagsProvider = StreamProvider<List<String>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getTags();
});

// --- 単一ドキュメント / 関連リストの購読 (詳細画面・検索履歴用) ---
//
// 詳細画面の build() 内で Stream を毎回生成すると、画面が他データの変化で
// 再ビルドされるたびに購読が張り直されてスピナーが点滅し、読み取りも無駄になる。
// これらを ref.watch することで購読を安定させる。
// autoDispose: 画面を閉じたら購読を破棄する。family: ドキュメント ID ごとに分離。
// 画面テストは firestoreServiceProvider のモック経由で同メソッドが呼ばれるため、
// 個別 override は不要 (必要なら glazeByIdProvider('id').overrideWith(...) も可)。

final glazeByIdProvider = StreamProvider.autoDispose.family<Glaze, String>(
  (ref, id) => ref.watch(firestoreServiceProvider).getGlazeStream(id),
);

final materialByIdProvider = StreamProvider.autoDispose
    .family<Material, String>(
      (ref, id) => ref.watch(firestoreServiceProvider).getMaterialStream(id),
    );

final testPieceByIdProvider = StreamProvider.autoDispose
    .family<TestPiece, String>(
      (ref, id) => ref.watch(firestoreServiceProvider).getTestPieceStream(id),
    );

final testPiecesForGlazeProvider = StreamProvider.autoDispose
    .family<List<TestPiece>, String>(
      (ref, glazeId) =>
          ref.watch(firestoreServiceProvider).getTestPiecesForGlaze(glazeId),
    );

final recentTestPieceIdsProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(firestoreServiceProvider).getRecentTestPieceIds(),
);

// --- 派生データ (ID -> モデルのマップ。ロード中・エラー時は空マップ) ---

final glazeMapProvider = Provider<Map<String, Glaze>>(
  (ref) => {
    for (final item in ref.watch(glazesProvider).valueOrNull ?? <Glaze>[])
      item.id!: item,
  },
);

final clayMapProvider = Provider<Map<String, Clay>>(
  (ref) => {
    for (final item in ref.watch(claysProvider).valueOrNull ?? <Clay>[])
      item.id!: item,
  },
);

final firingAtmosphereMapProvider = Provider<Map<String, FiringAtmosphere>>(
  (ref) => {
    for (final item
        in ref.watch(firingAtmospheresProvider).valueOrNull ??
            <FiringAtmosphere>[])
      item.id!: item,
  },
);

final firingProfileMapProvider = Provider<Map<String, FiringProfile>>(
  (ref) => {
    for (final item
        in ref.watch(firingProfilesProvider).valueOrNull ?? <FiringProfile>[])
      item.id!: item,
  },
);

final firingMapProvider = Provider<Map<String, Firing>>(
  (ref) => {
    for (final item in ref.watch(firingsProvider).valueOrNull ?? <Firing>[])
      item.id!: item,
  },
);

/// 原料 ID -> 原料名のマップ
final materialNameMapProvider = Provider<Map<String, String>>(
  (ref) => {
    for (final item in ref.watch(materialsProvider).valueOrNull ?? <Material>[])
      item.id!: item.name,
  },
);

/// 原料 ID -> 原料のマップ
final materialMapProvider = Provider<Map<String, Material>>(
  (ref) => {
    for (final item in ref.watch(materialsProvider).valueOrNull ?? <Material>[])
      item.id!: item,
  },
);
