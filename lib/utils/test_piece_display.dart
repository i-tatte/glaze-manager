import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/test_piece.dart';

/// テストピースの主たる釉薬の表示名。
/// 釉薬が現存すれば現在の名前、削除されていれば写しの名前を返す。
String glazeDisplayName(
  TestPiece testPiece,
  Map<String, Glaze> glazeMap, {
  String fallback = '不明な釉薬',
}) {
  return glazeMap[testPiece.glazeId]?.name ??
      testPiece.snapshot?.glaze?.name ??
      fallback;
}

/// テストピースの追加釉薬 [glazeId] の表示名。
/// 現存すれば現在の名前、削除されていれば写しの名前を返す。
String additionalGlazeDisplayName(
  TestPiece testPiece,
  String glazeId,
  Map<String, Glaze> glazeMap, {
  String fallback = '不明な釉薬',
}) {
  return glazeMap[glazeId]?.name ??
      testPiece.snapshot?.glazeSnapshotFor(glazeId)?.name ??
      fallback;
}

/// テストピースの素地土の表示名。
/// 素地土が現存すれば現在の名前、削除されていれば写しの名前を返す。
String clayDisplayName(
  TestPiece testPiece,
  Map<String, Clay> clayMap, {
  String fallback = '不明な素地',
}) {
  return clayMap[testPiece.clayId]?.name ??
      testPiece.snapshot?.clayName ??
      fallback;
}

/// テストピースの焼成の情報を解決した結果。
///
/// 焼成回を参照するテストピースでは焼成回を正とし、参照しないテストピースでは
/// テストピース自身の焼成雰囲気・焼成プロファイルの参照を使う。
class ResolvedFiring {
  /// 参照する焼成回 (なければ null)
  final Firing? firing;

  /// firingId はあるが焼成回が見つからない
  final bool firingMissing;

  final DateTime? firedOn;
  final String? kilnName;
  final String? atmosphereName;
  final FiringAtmosphereType atmosphereType;
  final String? profileName;
  final String? curveData;
  final bool isReduction;
  final int? reductionStartTemp;
  final int? reductionEndTemp;

  const ResolvedFiring({
    this.firing,
    this.firingMissing = false,
    this.firedOn,
    this.kilnName,
    this.atmosphereName,
    this.atmosphereType = FiringAtmosphereType.other,
    this.profileName,
    this.curveData,
    this.isReduction = false,
    this.reductionStartTemp,
    this.reductionEndTemp,
  });

  /// 値の表示の文言。焼成回が見つからなければ「不明」、値がなければ「未設定」。
  String display(String? value) {
    if (firingMissing) return '不明';
    return (value == null || value.isEmpty) ? '未設定' : value;
  }

  String get atmosphereLabel => display(atmosphereName);
  String get profileLabel => display(profileName);
}

/// テストピースの焼成の情報を解決する。
///
/// - 焼成回が見つかる: 雰囲気・プロファイルの名前は現存すれば現在の値、
///   なければ焼成回の写しの値。温度曲線と還元の値は常に焼成回の写し。
/// - firingId があるが焼成回が見つからない: [ResolvedFiring.firingMissing]。
/// - firingId がない: テストピースの firingAtmosphereId / firingProfileId から
///   現在の値を引く。
ResolvedFiring resolveFiring(
  TestPiece piece, {
  required Map<String, Firing> firingMap,
  required Map<String, FiringAtmosphere> atmosphereMap,
  required Map<String, FiringProfile> profileMap,
}) {
  final firingId = piece.firingId;
  if (firingId != null && firingId.isNotEmpty) {
    final firing = firingMap[firingId];
    if (firing == null) {
      return const ResolvedFiring(firingMissing: true);
    }
    final atmosphere = atmosphereMap[firing.firingAtmosphereId];
    final profile = profileMap[firing.firingProfileId];
    final snapshot = firing.profile;
    return ResolvedFiring(
      firing: firing,
      firedOn: firing.firedOn.toDate(),
      kilnName: firing.kilnName,
      atmosphereName: atmosphere?.name ?? firing.atmosphereName,
      atmosphereType:
          atmosphere?.type ??
          FiringAtmosphereType.fromString(firing.atmosphereType),
      profileName: profile?.name ?? snapshot?.name,
      curveData: snapshot?.curveData,
      isReduction: snapshot?.isReduction ?? false,
      reductionStartTemp: snapshot?.reductionStartTemp,
      reductionEndTemp: snapshot?.reductionEndTemp,
    );
  }

  final atmosphere = atmosphereMap[piece.firingAtmosphereId];
  final profile = profileMap[piece.firingProfileId];
  return ResolvedFiring(
    atmosphereName: atmosphere?.name,
    atmosphereType: atmosphere?.type ?? FiringAtmosphereType.other,
    profileName: profile?.name,
    curveData: profile?.curveData,
    isReduction: profile?.isReduction ?? false,
    reductionStartTemp: profile?.reductionStartTemp,
    reductionEndTemp: profile?.reductionEndTemp,
  );
}

/// 写真待ち (写真がまだ登録されていない) テストピースか。
/// imagePath も imageUrl もないものをいう。
bool isAwaitingPhoto(TestPiece piece) =>
    (piece.imagePath == null || piece.imagePath!.isEmpty) &&
    (piece.imageUrl == null || piece.imageUrl!.isEmpty);
