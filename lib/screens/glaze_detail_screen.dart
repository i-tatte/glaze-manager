import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class GlazeDetailScreen extends StatelessWidget {
  final Glaze glaze;

  const GlazeDetailScreen({super.key, required this.glaze});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${glaze.name}」を本当に削除しますか？\n関連するテストピースは削除されません。'),
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

    if (confirmed == true && context.mounted) {
      final navigator = Navigator.of(context);
      try {
        await context.read<FirestoreService>().deleteGlaze(glaze.id!);
        navigator.pop();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(glaze.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GlazeEditScreen(glaze: glaze),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: '削除',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: FutureBuilder<List<app.Material>>(
        future: firestoreService.getMaterials().first,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('原料データの読み込みエラー: ${snapshot.error}'));
          }

          final materials = snapshot.data ?? [];
          final materialMap = {for (var m in materials) m.id: m.name};

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (glaze.tags.isNotEmpty) ...[
                _buildTagsSection(context, glaze.tags),
                const Divider(height: 32),
              ],
              Text('調合レシピ', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (glaze.recipe.isEmpty)
                const Text('レシピが登録されていません。')
              else
                DataTable(
                  columns: const [
                    DataColumn(label: Text('原料')),
                    DataColumn(label: Text('割合'), numeric: true),
                  ],
                  rows: glaze.recipe.entries.toList().asMap().entries.map((
                    indexedEntry,
                  ) {
                    final index = indexedEntry.key;
                    final entry = indexedEntry.value;
                    final materialName =
                        materialMap[entry.key] ?? '不明な原料(ID:${entry.key})';
                    return DataRow(
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (index.isOdd) {
                          return Colors.grey.withValues(alpha: 0.1);
                        }
                        return null; // 奇数行はデフォルト
                      }),
                      cells: [
                        DataCell(Text(materialName)),
                        DataCell(Text(entry.value.toString())),
                      ],
                      onSelectChanged: (value) {
                        // 原料詳細画面へ遷移
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MaterialDetailScreen(
                              material:
                                  materials[materials.indexWhere(
                                    (m) => m.id == entry.key,
                                  )],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                  showCheckboxColumn: false,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, List<String> tags) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('タグ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: tags.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(color: Colors.white)),
                backgroundColor: Theme.of(context).primaryColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
