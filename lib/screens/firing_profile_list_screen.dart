import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:glaze_manager/screens/firing_profile_edit_screen.dart';

class FiringProfileListScreen extends StatelessWidget {
  const FiringProfileListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('焼成プロファイルの管理')),
      body: Stack(
        children: [
          StreamBuilder<List<FiringProfile>>(
            stream: firestoreService.getFiringProfiles(),
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
                    '焼成プロファイルが登録されていません。\n右下のボタンから追加してください。',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final profiles = snapshot.data!;

              return ListView.builder(
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return ListTile(
                    title: Text(profile.name),
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
                                    FiringProfileEditScreen(profile: profile),
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
                            profile,
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
              heroTag: 'firingProfileListFab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        FiringProfileEditScreen(profile: null),
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
    FiringProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${profile.name}」を本当に削除しますか？'),
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
      await service.deleteFiringProfile(profile.id!);
    }
  }
}
