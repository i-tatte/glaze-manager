import 'package:cloud_firestore/cloud_firestore.dart';

class Material {
  final String? id;
  final String name;
  final int order;
  final Map<String, double> components; // 例: {'SiO2': 75.2, 'Al2O3': 14.8}

  Material({this.id, required this.name, required this.order, required this.components});

  // FirestoreのドキュメントからMaterialオブジェクトを生成
  factory Material.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Material(
      id: snapshot.id,
      name: data['name'] ?? '',
      // orderフィールドがない古いデータとの互換性のため、デフォルト値を設定
      order: data['order'] ?? 0,
      components: data.containsKey('components') ? Map<String, double>.from(data['components']) : {},
    );
  }

  // MaterialオブジェクトをFirestore用のMapに変換
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'order': order,
      'components': components,
    };
  }
}
