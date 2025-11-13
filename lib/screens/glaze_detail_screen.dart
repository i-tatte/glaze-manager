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

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(glaze.name, overflow: TextOverflow.ellipsis),
            if (glaze.registeredName != null &&
                glaze.registeredName!.isNotEmpty)
              Text(
                glaze.registeredName!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
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
              if (glaze.registeredName != null &&
                  glaze.registeredName!.isNotEmpty) ...[
                _buildInfoTile(context, '登録名', glaze.registeredName!),
                const Divider(height: 32),
              ],
              if (glaze.tags.isNotEmpty) ...[
                _buildTagsSection(context, glaze.tags),
                const Divider(height: 32),
              ],
              if (glaze.description != null &&
                  glaze.description!.isNotEmpty) ...[
                _buildInfoTile(context, '備考', glaze.description!),
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
                    DataColumn(label: Text('配合(g)'), numeric: true),
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

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
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
