import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class ClayRepository extends UserScopedRepository<Clay> {
  ClayRepository({super.db, super.auth});

  @override
  String get collectionName => 'clays';

  @override
  Clay fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Clay.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(Clay item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('order');

  /// 複数の素地土の並び順を更新
  Future<void> updateOrder(List<Clay> clays) async {
    final batch = db.batch();
    for (int i = 0; i < clays.length; i++) {
      batch.update(collection.doc(clays[i].id), {'order': i});
    }
    await batch.commit();
  }
}
