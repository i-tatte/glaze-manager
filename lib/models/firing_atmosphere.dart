import 'package:cloud_firestore/cloud_firestore.dart';

enum FiringAtmosphereType {
  oxidation('酸化'),
  reduction('還元'),
  other('その他');

  final String displayName;
  const FiringAtmosphereType(this.displayName);

  static FiringAtmosphereType fromString(String? value) {
    return FiringAtmosphereType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FiringAtmosphereType.other,
    );
  }
}

class FiringAtmosphere {
  final String? id;
  final String name;
  final FiringAtmosphereType type;

  FiringAtmosphere({
    this.id,
    required this.name,
    this.type = FiringAtmosphereType.other,
  });

  factory FiringAtmosphere.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return FiringAtmosphere(
      id: snapshot.id,
      name: data['name'] ?? '',
      type: FiringAtmosphereType.fromString(data['type']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'type': type.name};
  }
}
