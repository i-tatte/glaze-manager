import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/firing.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class FiringRepository extends UserScopedRepository<Firing> {
  FiringRepository({super.db, super.auth});

  @override
  String get collectionName => 'firings';

  @override
  Firing fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Firing.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(Firing item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('firedOn', descending: true);

  /// 新規ドキュメントIDを発行する (書き込みはまだ行わない)。
  /// 作成した直後にその ID をテストピースに持たせるために使う。
  String newDocumentId() => collection.doc().id;

  /// 指定IDでドキュメントを作成する (newDocumentIdとセットで使用)
  Future<void> setById(String id, Firing firing) async {
    await collection.doc(id).set(toFirestore(firing));
  }
}
