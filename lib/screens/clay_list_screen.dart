import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class ClayListScreen extends StatefulWidget {
  const ClayListScreen({super.key});

  @override
  State<ClayListScreen> createState() => _ClayListScreenState();
}

class _ClayListScreenState extends State<ClayListScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('素地土名の管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context, firestoreService),
          ),
        ],
      ),
      body: StreamBuilder<List<Clay>>(
        stream: firestoreService.getClays(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('素地土名が登録されていません。'));
          }

          final clays = snapshot.data!;

          return ReorderableListView.builder(
            itemCount: clays.length,
            itemBuilder: (context, index) {
              final clay = clays[index];
              return ListTile(
                key: ValueKey(clay.id),
                title: Text(clay.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(
                        context,
                        firestoreService,
                        clay: clay,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _confirmDelete(context, firestoreService, clay),
                    ),
                  ],
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = clays.removeAt(oldIndex);
              clays.insert(newIndex, item);
              firestoreService.updateClayOrder(clays);
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    FirestoreService service, {
    Clay? clay,
  }) async {
    final nameController = TextEditingController(text: clay?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clay == null ? '新規作成' : '編集'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '素地土名'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '名前を入力してください';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(nameController.text);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        if (clay == null) {
          // 新規作成
          final clays = await service.getClays().first;
          await service.addClay(Clay(name: result, order: clays.length));
        } else {
          // 更新
          await service.updateClay(
            Clay(id: clay.id, name: result, order: clay.order),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService service,
    Clay clay,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${clay.name}」を本当に削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await service.deleteClay(clay.id!);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }
}
