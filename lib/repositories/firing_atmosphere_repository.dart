import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class FiringAtmosphereRepository
    extends UserScopedRepository<FiringAtmosphere> {
  FiringAtmosphereRepository({super.db, super.auth});

  @override
  String get collectionName => 'firing_atmospheres';

  @override
  FiringAtmosphere fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => FiringAtmosphere.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(FiringAtmosphere item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('name');
}
