import 'package:cloud_firestore/cloud_firestore.dart';

enum MaterialCategory {
  base('母剤'),
  additive('添加剤'),
  pigment('顔料');

  const MaterialCategory(this.displayName);
  final String displayName;

  /// Firestoreに保存されている文字列からenumを復元
  static MaterialCategory fromString(String? value) {
    return MaterialCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MaterialCategory.base, // 不明な値の場合はデフォルト
    );
  }
}

class Material {
  final String? id;
  final String name;
  final int order;
  final Map<String, double> components; // 例: {'SiO2': 75.2, 'Al2O3': 14.8}
  final MaterialCategory category;

  Material({
    this.id,
    required this.name,
    required this.order,
    required this.components,
    required this.category,
  });

  // FirestoreのドキュメントからMaterialオブジェクトを生成
  factory Material.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return Material(
      id: snapshot.id,
      name: data['name'] ?? '',
      // orderフィールドがない古いデータとの互換性のため、デフォルト値を設定
      order: data['order'] ?? 0,
      components: data.containsKey('components')
          ? Map<String, double>.from(data['components'])
          : {},
      category: MaterialCategory.fromString(data['category']),
    );
  }

  // MaterialオブジェクトをFirestore用のMapに変換
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'order': order,
      'components': components,
      'category': category.name,
    };
  }
}
