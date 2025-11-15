import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class MaterialDetailScreen extends StatelessWidget {
  final app.Material material;

  const MaterialDetailScreen({super.key, required this.material});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text(
          '「${material.name}」を本当に削除しますか？\nこの原料を使用している釉薬レシピがある場合、問題が発生する可能性があります。',
        ),
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
        await context.read<FirestoreService>().deleteMaterial(material.id!);
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(material.name, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(material.category.displayName),
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: material.category == app.MaterialCategory.pigment
                  ? Colors.pink
                  : material.category == app.MaterialCategory.additive
                  ? Colors.blue
                  : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              visualDensity: VisualDensity.compact,
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
                  builder: (context) => MaterialEditScreen(material: material),
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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text('化学成分', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (material.components.isEmpty)
            const Text('化学成分が登録されていません。')
          else
            DataTable(
              columns: const [
                DataColumn(label: Text('成分名')),
                DataColumn(label: Text('量 (%)'), numeric: true),
              ],
              rows: material.components.entries.toList().asMap().entries.map((
                indexedEntry,
              ) {
                final index = indexedEntry.key;
                final entry = indexedEntry.value;
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (index.isEven) {
                      return Colors.grey.withValues(alpha: 0.1);
                    }
                    return null; // 奇数行はデフォルト
                  }),
                  cells: [
                    DataCell(Text(entry.key)),
                    DataCell(Text(entry.value.toString())),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
