import 'package:cloud_firestore/cloud_firestore.dart';

class FiringProfile {
  final String? id;
  final String name;
  // 焼成温度曲線の詳細データ（例: "30,100\n90,200"）
  final String? curveData;
  final bool isReduction;
  final int? reductionStartTemp;
  final int? reductionEndTemp;

  FiringProfile({
    this.id,
    required this.name,
    this.curveData,
    this.isReduction = false,
    this.reductionStartTemp,
    this.reductionEndTemp,
  });

  factory FiringProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return FiringProfile(
      id: snapshot.id,
      name: data['name'] ?? '',
      curveData: data['curveData'] ?? '',
      isReduction: data['isReduction'] ?? false,
      reductionStartTemp: data['reductionStartTemp'],
      reductionEndTemp: data['reductionEndTemp'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'curveData': curveData,
      'isReduction': isReduction,
      'reductionStartTemp': reductionStartTemp,
      'reductionEndTemp': reductionEndTemp,
    };
  }
}
