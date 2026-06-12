import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/screens/clay_edit_screen.dart';

class ClayListScreen extends ConsumerStatefulWidget {
  const ClayListScreen({super.key});

  @override
  ConsumerState<ClayListScreen> createState() => _ClayListScreenState();
}

class _ClayListScreenState extends ConsumerState<ClayListScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('素地土名の管理')),
      body: Stack(
        children: [
          ref
              .watch(claysProvider)
              .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('エラーが発生しました: $error')),
            data: (data) {
              if (data.isEmpty) {
                return const Center(
                  child: Text(
                    '素地土名が登録されていません。\n右下のボタンから追加してください。',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              // 並べ替え操作でリストを直接変更するためコピーを使う
              final clays = [...data];

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
                          tooltip: '編集',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ClayEditScreen(clay: clay),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: '削除',
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
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'clayListFab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ClayEditScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService service,
    Clay clay,
  ) async {
    // この素地土を使用しているテストピースの数を集計して警告に含める
    final testPieces = await ref.read(testPiecesProvider.future);
    final usedCount = testPieces.where((tp) => tp.clayId == clay.id).length;
    final warning = usedCount > 0
        ? '\n\nこの素地土は$usedCount件のテストピースで使用されています。\n削除すると、それらの表示は「未設定」になります。'
        : '';

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${clay.name}」を本当に削除しますか？$warning'),
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
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }
}
