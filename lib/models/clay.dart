import 'package:cloud_firestore/cloud_firestore.dart';

class Clay {
  final String? id;
  final String name;
  final int order;

  Clay({this.id, required this.name, required this.order});

  factory Clay.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Clay(
      id: snapshot.id,
      name: data['name'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'name': name, 'order': order};
  }
}
