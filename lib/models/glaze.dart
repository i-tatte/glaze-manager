import 'package:cloud_firestore/cloud_firestore.dart';

class Glaze {
  final String? id;
  final String name;
  final String? registeredName;
  final Map<String, double> recipe; // {materialId: amount}
  final String? imageUrl;
  final List<String> tags;
  final String? description;
  final Timestamp createdAt;

  Glaze({
    this.id,
    required this.name,
    this.registeredName,
    required Map<String, double> recipe,
    this.imageUrl,
    required List<String> tags,
    this.description,
    required this.createdAt,
  }) : recipe = Map.of(recipe),
       tags = List.of(tags);

  factory Glaze.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Glaze(
      id: snapshot.id,
      name: data['name'] ?? '',
      registeredName: data['registeredName'],
      recipe: data.containsKey('recipe')
          ? (data['recipe'] as Map).map(
              (key, value) =>
                  MapEntry(key as String, (value as num).toDouble()),
            )
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
      'registeredName': registeredName,
      'recipe': recipe,
      'imageUrl': imageUrl,
      'tags': tags,
      'description': description,
      'createdAt': createdAt,
    };
  }
}
