import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class MaterialDetailScreen extends StatefulWidget {
  final app.Material material;

  const MaterialDetailScreen({super.key, required this.material});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<app.Material>(
      stream: firestoreService.getMaterialStream(widget.material.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('原料データの読み込みに失敗しました。')),
          );
        }

        final material = snapshot.data!;

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
                  backgroundColor: Theme.of(context).colorScheme.primary,
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
                      builder: (context) =>
                          MaterialEditScreen(material: material),
                    ),
                  );
                },
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
                  rows: material.components.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((indexedEntry) {
                        final index = indexedEntry.key;
                        final entry = indexedEntry.value;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((
                            states,
                          ) {
                            if (index.isEven) {
                              return Colors.grey.withOpacity(0.1);
                            }
                            return null;
                          }),
                          cells: [
                            DataCell(Text(entry.key)),
                            DataCell(Text(entry.value.toString())),
                          ],
                        );
                      })
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
