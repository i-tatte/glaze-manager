import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class FiringProfileRepository extends UserScopedRepository<FiringProfile> {
  FiringProfileRepository({super.db, super.auth});

  @override
  String get collectionName => 'firing_profiles';

  @override
  FiringProfile fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => FiringProfile.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(FiringProfile item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('name');
}
