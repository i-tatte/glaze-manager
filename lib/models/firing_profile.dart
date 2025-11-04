import 'package:cloud_firestore/cloud_firestore.dart';

class FiringProfile {
  final String? id;
  final String name;
  // 焼成温度曲線の詳細データ（例: "30,100\n90,200"）
  final String? curveData;

  FiringProfile({this.id, required this.name, this.curveData});

  factory FiringProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return FiringProfile(
      id: snapshot.id,
      name: data['name'] ?? '',
      curveData: data['curveData'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'curveData': curveData};
  }
}
