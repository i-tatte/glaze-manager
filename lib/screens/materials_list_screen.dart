import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class MaterialsListScreen extends StatefulWidget {
  const MaterialsListScreen({super.key});

  @override
  State<MaterialsListScreen> createState() => _MaterialsListScreenState();
}

class _MaterialsListScreenState extends State<MaterialsListScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('原料一覧'),
        actions: [
          TextButton(
            child: Text(_isEditing ? '完了' : '編集', style: TextStyle(color: Colors.black)),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: StreamBuilder<List<app.Material>>(
        stream: firestoreService.getMaterials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                '原料が登録されていません。\n右下のボタンから追加してください。',
                textAlign: TextAlign.center,
              ),
            );
          }

          final materials = snapshot.data!;

          if (_isEditing) {
            return ReorderableListView.builder(
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index];
                return _buildReorderableTile(context, material, index, firestoreService);
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = materials.removeAt(oldIndex);
                  materials.insert(newIndex, item);
                  // Firestoreの順序を一括更新
                  firestoreService.updateMaterialOrder(materials);
                });
              },
            );
          } else {
            return ListView.builder(
              itemCount: materials.length,
              itemBuilder: (context, index) {
                final material = materials[index];
                return ListTile(
                    title: Text(material.name),
                    subtitle: Text('成分数: ${material.components.length}'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => MaterialEditScreen(material: material),
                      ));
                    });
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        // 編集モード中はFABを非表示にする
        onPressed: _isEditing
            ? null
            : () {
                Navigator.of(context).push(MaterialPageRoute(
                  // 引数を渡さない場合は新規作成モード
                  builder: (context) => const MaterialEditScreen(),
                ));
              },
        backgroundColor: _isEditing ? Colors.grey : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildReorderableTile(BuildContext context, app.Material material, int index,
      FirestoreService firestoreService) {
    return ListTile(
      key: ValueKey(material.id),
      leading: IconButton(
        icon: const Icon(Icons.remove_circle, color: Colors.red),
        onPressed: () async {
          // 削除確認ダイアログ
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('削除の確認'),
              content: Text('「${material.name}」を本当に削除しますか？'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除')),
              ],
            ),
          );
          if (confirmed == true) {
            firestoreService.deleteMaterial(material.id!);
          }
        },
      ),
      title: Text(material.name),
      trailing: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MaterialEditScreen(material: material),
        ));
      },
    );
  }
}