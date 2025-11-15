import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class GlazeDetailScreen extends StatefulWidget {
  final Glaze glaze;

  const GlazeDetailScreen({super.key, required this.glaze});

  @override
  State<GlazeDetailScreen> createState() => _GlazeDetailScreenState();
}

class _GlazeDetailScreenState extends State<GlazeDetailScreen> {
  late Future<List<app.Material>> _materialsFuture;

  @override
  void initState() {
    super.initState();
    // initStateでFutureを一度だけ生成する
    _materialsFuture = _loadMaterials();
  }

  Future<List<app.Material>> _loadMaterials() async {
    return context.read<FirestoreService>().getMaterials().first;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${widget.glaze.name}」を本当に削除しますか？\n関連するテストピースは削除されません。'),
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
        await context.read<FirestoreService>().deleteGlaze(widget.glaze.id!);
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
    final Glaze glaze = widget.glaze;
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
                  builder: (context) => GlazeEditScreen(glaze: widget.glaze),
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
        // 変更: initStateで生成したFutureを使用
        future: _materialsFuture,
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
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('原料')),
                    DataColumn(label: Text('配合(g)'), numeric: true),
                  ],
                  rows: _buildRecipeRows(context, materials, materialMap),
                ),
              const Divider(height: 32),
              _buildTestPiecesSection(context, firestoreService),
            ],
          );
        },
      ),
    );
  }

  List<DataRow> _buildRecipeRows(
    BuildContext context,
    List<app.Material> materials,
    Map<String?, String> materialMap,
  ) {
    return widget.glaze.recipe.entries.toList().asMap().entries.map((
      indexedEntry,
    ) {
      final index = indexedEntry.key;
      final entry = indexedEntry.value;
      final materialId = entry.key;
      final materialName = materialMap[materialId] ?? '不明な原料(ID:$materialId)';

      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>((states) {
          if (index.isEven) {
            return Colors.grey.withOpacity(0.1);
          }
          return null; // 奇数行はデフォルト
        }),
        cells: [
          DataCell(Text(materialName)),
          DataCell(Text(entry.value.toString())),
        ],
        onSelectChanged: (selected) {
          // orElseで見つからない場合のフォールバックを追加
          final material = materials.firstWhere(
            (m) => m.id == materialId,
            orElse: () => app.Material(
              id: materialId,
              name: materialName,
              components: {},
              order: 0,
              category: app.MaterialCategory.base,
            ),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MaterialDetailScreen(material: material),
            ),
          );
        },
      );
    }).toList();
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

  Widget _buildTestPiecesSection(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    return StreamBuilder<List<TestPiece>>(
      stream: firestoreService.getTestPiecesByGlazeId(widget.glaze.id!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // データを待っている間は何も表示しないか、インジケータを表示
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // データがなければ何も表示しない
        }

        final testPieces = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'この釉薬を使用したテストピース',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120, // 横スクロールリストの高さ
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: testPieces.length,
                itemBuilder: (context, index) {
                  final testPiece = testPieces[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TestPieceDetailScreen(testPiece: testPiece),
                        ),
                      );
                    },
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: testPiece.imageUrl != null
                            ? Image.network(
                                testPiece.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.photo,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
