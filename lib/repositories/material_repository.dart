import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/material.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class MaterialRepository extends UserScopedRepository<Material> {
  MaterialRepository({super.db, super.auth});

  @override
  String get collectionName => 'materials';

  @override
  Material fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Material.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(Material item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('order');

  /// 原料名からIDを取得 (見つからなければnull)
  Future<String?> getIdByName(String name) async {
    final querySnapshot = await collection
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  /// 複数の原料の並び順を更新
  Future<void> updateOrder(List<Material> materials) async {
    final batch = db.batch();
    for (int i = 0; i < materials.length; i++) {
      batch.update(collection.doc(materials[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// 複数の原料を名前で検索し、存在しない場合は指定カテゴリで一括作成する。
  /// 新規作成した原料名のリストを返す。
  Future<List<String>> findOrCreate(
    List<String> names, {
    required MaterialCategory category,
  }) async {
    if (names.isEmpty) return [];

    final existing = await getAll();
    final existingNames = existing.map((m) => m.name).toSet();
    final newNames = names
        .toSet()
        .where((name) => name.isNotEmpty && !existingNames.contains(name))
        .toList();

    if (newNames.isNotEmpty) {
      final batch = db.batch();
      final baseOrder = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < newNames.length; i++) {
        final newMaterial = Material(
          name: newNames[i],
          components: {},
          order: baseOrder + i,
          category: category,
        );
        batch.set(collection.doc(), newMaterial.toFirestore());
      }
      await batch.commit();
    }
    return newNames;
  }
}
