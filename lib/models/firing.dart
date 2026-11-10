import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/utils/date_format.dart';

/// 焼成回。いつ、どの窯で、どの条件で焼いたかと、その実績を持つ。
/// テストピースは `firingId` でこれを参照する。
class Firing {
  final String? id;

  /// 焼成日。その日の正午 (端末の時刻) で保存する
  final Timestamp firedOn;

  /// 窯の名前 (自由入力)
  final String? kilnName;

  /// 計画として使った焼成プロファイル
  final String? firingProfileId;

  /// その時点のプロファイルの写し
  final FiringProfileSnapshot? profile;

  final String? firingAtmosphereId;

  /// その時点の雰囲気名
  final String? atmosphereName;

  /// その時点の FiringAtmosphereType.name
  final String? atmosphereType;

  /// 実測の最高温度 (℃)
  final int? peakTemp;

  /// コーンの結果 (自由入力)
  final String? cone;

  /// 所感
  final String? note;

  final Timestamp createdAt;

  Firing({
    this.id,
    required this.firedOn,
    this.kilnName,
    this.firingProfileId,
    this.profile,
    this.firingAtmosphereId,
    this.atmosphereName,
    this.atmosphereType,
    this.peakTemp,
    this.cone,
    this.note,
    required this.createdAt,
  });

  /// 日付だけの値を、端末の時刻のその日の正午の Timestamp にする。
  /// 時間帯の違いで日付がずれないようにするため。
  static Timestamp noonOf(DateTime date) =>
      Timestamp.fromDate(DateTime(date.year, date.month, date.day, 12));

  /// 一覧やグループの見出しに使う表示名。例: '2026/11/8 電気窯'
  String get displayLabel {
    final date = formatDate(firedOn.toDate());
    final kiln = kilnName;
    return (kiln == null || kiln.isEmpty) ? date : '$date $kiln';
  }

  static String? _readString(Object? value) =>
      (value is String && value.isNotEmpty) ? value : null;

  factory Firing.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    final createdAt = data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : Timestamp.now();
    return Firing(
      id: snapshot.id,
      firedOn: data['firedOn'] is Timestamp
          ? data['firedOn'] as Timestamp
          : createdAt,
      kilnName: _readString(data['kilnName']),
      firingProfileId: _readString(data['firingProfileId']),
      profile: FiringProfileSnapshot.tryFromMap(data['profile']),
      firingAtmosphereId: _readString(data['firingAtmosphereId']),
      atmosphereName: _readString(data['atmosphereName']),
      atmosphereType: _readString(data['atmosphereType']),
      peakTemp: (data['peakTemp'] is num)
          ? (data['peakTemp'] as num).toInt()
          : null,
      cone: _readString(data['cone']),
      note: _readString(data['note']),
      createdAt: createdAt,
    );
  }

  /// 更新は文書全体の update なので、空にした項目を消すために null も出力する。
  Map<String, dynamic> toFirestore() {
    return {
      'firedOn': firedOn,
      'kilnName': kilnName,
      'firingProfileId': firingProfileId,
      'profile': profile?.toMap(),
      'firingAtmosphereId': firingAtmosphereId,
      'atmosphereName': atmosphereName,
      'atmosphereType': atmosphereType,
      'peakTemp': peakTemp,
      'cone': cone,
      'note': note,
      'createdAt': createdAt,
    };
  }
}

/// 焼成回が持つ、その時点の焼成プロファイルの写し。
class FiringProfileSnapshot {
  final String name;
  final String? curveData;
  final bool isReduction;
  final int? reductionStartTemp;
  final int? reductionEndTemp;

  const FiringProfileSnapshot({
    required this.name,
    this.curveData,
    this.isReduction = false,
    this.reductionStartTemp,
    this.reductionEndTemp,
  });

  /// 現在の焼成プロファイルから写しを作る。
  factory FiringProfileSnapshot.capture(FiringProfile profile) {
    return FiringProfileSnapshot(
      name: profile.name,
      curveData: profile.curveData,
      isReduction: profile.isReduction,
      reductionStartTemp: profile.reductionStartTemp,
      reductionEndTemp: profile.reductionEndTemp,
    );
  }

  /// Map でなければ null を返す。欠損に耐える。
  static FiringProfileSnapshot? tryFromMap(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    int? readInt(Object? v) => v is num ? v.toInt() : null;
    return FiringProfileSnapshot(
      name: map['name'] is String ? map['name'] as String : '',
      curveData: map['curveData'] is String ? map['curveData'] as String : null,
      isReduction: map['isReduction'] == true,
      reductionStartTemp: readInt(map['reductionStartTemp']),
      reductionEndTemp: readInt(map['reductionEndTemp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'curveData': curveData,
      'isReduction': isReduction,
      'reductionStartTemp': reductionStartTemp,
      'reductionEndTemp': reductionEndTemp,
    };
  }
}
