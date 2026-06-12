import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/services/firestore_service.dart';
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

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

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

final tagsProvider = StreamProvider<List<String>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(firestoreServiceProvider).getTags();
});

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

/// 原料 ID -> 原料名のマップ
final materialNameMapProvider = Provider<Map<String, String>>(
  (ref) => {
    for (final item in ref.watch(materialsProvider).valueOrNull ?? <Material>[])
      item.id!: item.name,
  },
);
