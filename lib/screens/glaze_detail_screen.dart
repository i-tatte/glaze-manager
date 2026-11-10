import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerWidget, WidgetRef, AsyncValueX;
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/models/recipe_snapshot.dart';
import 'package:glaze_manager/utils/recipe_diff.dart';
import 'package:glaze_manager/widgets/common/recipe_diff_table.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/glaze_edit_screen.dart';
import 'package:glaze_manager/screens/glaze_list_screen.dart';
import 'package:glaze_manager/screens/mixing_calculator_screen.dart';
import 'package:glaze_manager/screens/test_piece_detail_screen.dart';
import 'package:glaze_manager/widgets/common/app_network_image.dart';
import 'package:glaze_manager/widgets/common/info_tile.dart';
import 'package:glaze_manager/widgets/common/recipe_table.dart';
import 'package:glaze_manager/widgets/common/tag_chip.dart';

class GlazeDetailScreen extends ConsumerWidget {
  final Glaze glaze;

  const GlazeDetailScreen({super.key, required this.glaze});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider).valueOrNull ?? [];
    final glazeAsync = ref.watch(glazeByIdProvider(glaze.id!));

    return glazeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('釉薬データの読み込みに失敗しました。')),
      ),
      data: (glaze) {
        final materialMap = {for (var m in materials) m.id: m.name};

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
                icon: const Icon(Icons.copy_outlined),
                tooltip: '複製して新規作成',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GlazeEditScreen(sourceGlaze: glaze),
                    ),
                  );
                },
              ),
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
          body: _buildContent(context, ref, glaze, materialMap, materials),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Glaze glaze,
    Map<String?, String?> materialMap,
    List<app.Material> materials,
  ) {
    final glazeMap = ref.watch(glazeMapProvider);
    final parent = glaze.parentGlazeId == null
        ? null
        : glazeMap[glaze.parentGlazeId];
    final parentSnapshot = glaze.parentSnapshot;
    final derivedGlazes =
        glazeMap.values.where((g) => g.parentGlazeId == glaze.id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('基本情報', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (glaze.registeredName != null &&
            glaze.registeredName!.isNotEmpty) ...[
          InfoTile(label: '登録名', value: glaze.registeredName!),
          const Divider(height: 32),
        ],
        if (glaze.parentGlazeId != null) ...[
          InfoTile(
            label: '派生元',
            // 派生元が現存すれば現在の名前とリンク、なければ写しの名前
            value: parent?.name ?? parentSnapshot?.name ?? '不明な釉薬',
            onTap: parent == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GlazeDetailScreen(glaze: parent),
                      ),
                    );
                  },
          ),
          const Divider(height: 32),
        ],
        if (glaze.tags.isNotEmpty) ...[
          _buildTagsSection(context, glaze.tags),
          const Divider(height: 32),
        ],
        if (glaze.description != null && glaze.description!.isNotEmpty) ...[
          InfoTile(label: '備考', value: glaze.description!),
          const Divider(height: 32),
        ],
        Row(
          children: [
            Text('調合', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            const Tooltip(
              message: '原料ごとの重量です。行をタップすると原料の詳細を開きます。',
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(Icons.info_outline, size: 20, color: Colors.grey),
            ),
          ],
        ),
        if (glaze.recipe.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MixingCalculatorScreen(
                      recipe: glaze.recipe,
                      materialNames: materialMap.cast<String, String>(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.calculate),
              label: const Text('調合計算へ'),
            ),
          ),
        const SizedBox(height: 8),
        if (glaze.recipe.isEmpty)
          const Text('レシピが登録されていません。')
        else
          RecipeTable(recipe: glaze.recipe, materials: materials),
        if (parentSnapshot != null) ...[
          const SizedBox(height: 24),
          Text('派生元からの変更', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildParentDiff(glaze, parentSnapshot, materials),
        ],
        if (derivedGlazes.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('派生した釉薬', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final derived in derivedGlazes)
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GlazeDetailScreen(glaze: derived),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  derived.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        const Divider(height: 32),
        _buildTestPiecesSection(context, ref, glaze.id!),
      ],
    );
  }

  /// 派生元 (複製した時点) とこの釉薬の調合の違いを、違いのある原料だけ表示する。
  Widget _buildParentDiff(
    Glaze glaze,
    GlazeSnapshot parentSnapshot,
    List<app.Material> materials,
  ) {
    final recipes = [parentSnapshot.recipe, glaze.recipe];
    final hasDifference = diffRecipes(recipes).any((row) => row.differs);
    if (!hasDifference) return const Text('派生元と同じ調合です。');

    final materialById = {for (final m in materials) m.id: m};
    final snapshotNames = {
      for (final line in parentSnapshot.lines) line.materialId: line.name,
    };
    return RecipeDiffTable(
      columnLabels: const ['派生元', 'この釉薬'],
      recipes: recipes,
      materialName: (id) =>
          materialById[id]?.name ?? snapshotNames[id] ?? '不明な原料',
      onlyDiffering: true,
    );
  }

  Widget _buildTestPiecesSection(
    BuildContext context,
    WidgetRef ref,
    String glazeId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('テストピース', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ref
            .watch(testPiecesForGlazeProvider(glazeId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                debugPrint("Test piece stream error: $error");
                return const Text('テストピースの読み込みに失敗しました。');
              },
              data: (testPieces) {
                if (testPieces.isEmpty) {
                  return const Text('この釉薬を使ったテストピースはまだ登録されていません。');
                }

                return SizedBox(
                  height: 120, // 画像とキャプションのための高さを確保
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: testPieces.length,
                    itemBuilder: (context, index) {
                      final testPiece = testPieces[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    TestPieceDetailScreen(testPiece: testPiece),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox(
                            width: 100,
                            child: Column(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: AppNetworkImage(
                                      url:
                                          (testPiece.thumbnailUrl != null &&
                                              testPiece
                                                  .thumbnailUrl!
                                                  .isNotEmpty)
                                          ? testPiece.thumbnailUrl
                                          : testPiece.imageUrl,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      ],
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
              // タップでそのタグのフィルタを適用した釉薬一覧へ
              return TagChip(
                label: tag,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GlazeListScreen(initialTags: [tag]),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
