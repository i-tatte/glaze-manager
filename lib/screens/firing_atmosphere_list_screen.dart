import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:glaze_manager/screens/firing_atmosphere_edit_screen.dart';

class FiringAtmosphereListScreen extends StatelessWidget {
  const FiringAtmosphereListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('焼成雰囲気の管理')),
      body: Stack(
        children: [
          StreamBuilder<List<FiringAtmosphere>>(
            stream: firestoreService.getFiringAtmospheres(),
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
                    '焼成雰囲気が登録されていません。\n右下のボタンから追加してください。',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final atmospheres = snapshot.data!;

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
    FirestoreService service,
    FiringAtmosphere atmosphere,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${atmosphere.name}」を本当に削除しますか？'),
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
