import 'package:cloud_firestore/cloud_firestore.dart';

class Glaze {
  final String? id;
  final String name;
  final Map<String, double> recipe; // {materialId: amount}
  final String? imageUrl;
  final List<String> tags;
  final String? description;
  final Timestamp createdAt;

  Glaze({
    this.id,
    required this.name,
    required this.recipe,
    this.imageUrl,
    required this.tags,
    this.description,
    required this.createdAt,
  });

  factory Glaze.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Glaze(
      id: snapshot.id,
      name: data['name'] ?? '',
      recipe: data.containsKey('recipe')
          ? Map<String, double>.from(data['recipe'])
          : {},
      imageUrl: data['imageUrl'],
      tags: data.containsKey('tags') ? List<String>.from(data['tags']) : [],
      description: data['description'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'recipe': recipe,
      'imageUrl': imageUrl,
      'tags': tags,
      'description': description,
      'createdAt': createdAt,
    };
  }
}
