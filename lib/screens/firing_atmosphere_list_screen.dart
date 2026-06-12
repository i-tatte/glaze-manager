import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef, AsyncValueX;
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/screens/firing_atmosphere_edit_screen.dart';

class FiringAtmosphereListScreen extends ConsumerWidget {
  const FiringAtmosphereListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('焼成雰囲気の管理')),
      body: Stack(
        children: [
          ref
              .watch(firingAtmospheresProvider)
              .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('エラーが発生しました: $error')),
            data: (atmospheres) {
              if (atmospheres.isEmpty) {
                return const Center(
                  child: Text(
                    '焼成雰囲気が登録されていません。\n右下のボタンから追加してください。',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                itemCount: atmospheres.length,
                itemBuilder: (context, index) {
                  final atmosphere = atmospheres[index];
                  return ListTile(
                    title: Text(atmosphere.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '編集',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    FiringAtmosphereEditScreen(
                                      atmosphere: atmosphere,
                                    ),
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
                          onPressed: () => _confirmDelete(
                            context,
                            ref,
                            firestoreService,
                            atmosphere,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'firingAtmosphereListFab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FiringAtmosphereEditScreen(),
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
    WidgetRef ref,
    FirestoreService service,
    FiringAtmosphere atmosphere,
  ) async {
    // この焼成雰囲気を使用しているテストピースの数を集計して警告に含める
    final testPieces = await ref.read(testPiecesProvider.future);
    final usedCount = testPieces
        .where((tp) => tp.firingAtmosphereId == atmosphere.id)
        .length;
    final warning = usedCount > 0
        ? '\n\nこの焼成雰囲気は$usedCount件のテストピースで使用されています。\n削除すると、それらの表示は「未設定」になります。'
        : '';

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${atmosphere.name}」を本当に削除しますか？$warning'),
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

    if (confirmed == true) {
      await service.deleteFiringAtmosphere(atmosphere.id!);
    }
  }
}
