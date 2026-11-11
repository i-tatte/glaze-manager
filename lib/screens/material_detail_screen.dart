import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/widgets/common/material_category_chip.dart';
import 'package:glaze_manager/widgets/common/striped_data_table.dart';

class MaterialDetailScreen extends ConsumerStatefulWidget {
  final app.Material material;

  const MaterialDetailScreen({super.key, required this.material});

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final materialAsync = ref.watch(materialByIdProvider(widget.material.id!));

    return materialAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('原料データの読み込みに失敗しました。')),
      ),
      data: (material) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(material.name, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                MaterialCategoryChip(category: material.category),
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
                StripedDataTable(
                  columnLabels: const ['成分名', '量 (%)'],
                  rows: material.components.entries
                      .map(
                        (entry) =>
                            StripedDataRow([entry.key, entry.value.toString()]),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
