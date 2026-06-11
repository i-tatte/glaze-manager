import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class GlazeRepository extends UserScopedRepository<Glaze> {
  GlazeRepository({super.db, super.auth});

  @override
  String get collectionName => 'glazes';

  @override
  Glaze fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Glaze.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(Glaze item) => item.toFirestore();

  /// 複数の釉薬を一括で追加 (バッチ処理)
  Future<void> addBatch(List<Glaze> glazes) async {
    final batch = db.batch();
    for (final glaze in glazes) {
      batch.set(collection.doc(), glaze.toFirestore());
    }
    await batch.commit();
  }
}
