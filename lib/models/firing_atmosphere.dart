import 'package:cloud_firestore/cloud_firestore.dart';

class FiringAtmosphere {
  final String? id;
  final String name;

  FiringAtmosphere({this.id, required this.name});

  factory FiringAtmosphere.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return FiringAtmosphere(id: snapshot.id, name: data['name'] ?? '');
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name};
  }
}
