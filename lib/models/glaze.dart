import 'package:cloud_firestore/cloud_firestore.dart';

class Glaze {
  final String? id;
  final String name;
  final int firingTemperature;
  final Map<String, double> recipe; // {materialId: amount}
  final String? imageUrl;
  final List<String> tags;

  Glaze({
    this.id,
    required this.name,
    required this.firingTemperature,
    required this.recipe,
    this.imageUrl,
    required this.tags,
  });

  factory Glaze.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Glaze(
      id: snapshot.id,
      name: data['name'],
      firingTemperature: data['firingTemperature'],
      recipe: Map<String, double>.from(data['recipe']),
      imageUrl: data['imageUrl'],
      tags: List<String>.from(data['tags']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'firingTemperature': firingTemperature,
      'recipe': recipe,
      'imageUrl': imageUrl,
      'tags': tags,
    };
  }
}
