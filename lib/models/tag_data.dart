import 'package:cloud_firestore/cloud_firestore.dart';

class TagData {
  final String id; // Tag name is the ID
  final Timestamp createdAt;

  TagData({
    required this.id,
    required this.createdAt,
  });

  factory TagData.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return TagData(
      id: snapshot.id,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdAt': createdAt,
    };
  }
}
