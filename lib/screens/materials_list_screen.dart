import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState, AsyncValueX;
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:glaze_manager/widgets/common/common_search_bar.dart';
import 'package:glaze_manager/widgets/common/empty_list_placeholder.dart';

class MaterialsListScreen extends ConsumerStatefulWidget {
  final PageStorageKey? pageStorageKey;
  // MainTabScreenから編集状態を監視するためのValueNotifierを受け取る
  final ValueNotifier<bool> isEditingNotifier;

  const MaterialsListScreen({
    super.key,
    this.pageStorageKey,
    required this.isEditingNotifier,
  });
  // AppBarに表示するアクションボタンを生成する静的メソッド
  // MainTabScreenから呼び出される
  static List<Widget> buildActions(
    BuildContext context,
    ValueNotifier<bool> isEditingNotifier,
  ) {
    // isEditingNotifierの値を元にボタンのテキストを決定
    final isEditing = isEditingNotifier.value;
    return [
      TextButton(
        onPressed: () => isEditingNotifier.value = !isEditing,
        child: Text(isEditing ? '完了' : '編集'),
      ),
    ];
  }

  @override
  ConsumerState<MaterialsListScreen> createState() =>
      MaterialsListScreenState();
}

class MaterialsListScreenState extends ConsumerState<MaterialsListScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<app.MaterialCategory> _selectedCategories = app
      .MaterialCategory
      .values
      .toSet();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    widget.isEditingNotifier.addListener(_onEditingChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    widget.isEditingNotifier.removeListener(_onEditingChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> handleRefresh() async {
    ref.invalidate(materialsProvider);
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  void _onEditingChanged() {
    // 編集モードが切り替わったら再描画
    if (mounted) {
      setState(() {});
    }
  }

  List<app.Material> _filterMaterials(List<app.Material> allMaterials) {
    // カテゴリで絞り込み
    if (_selectedCategories.length != app.MaterialCategory.values.length) {
      allMaterials = allMaterials
          .where((material) => _selectedCategories.contains(material.category))
          .toList();
    }

    // テキストで絞り込み
    if (_searchQuery.isNotEmpty) {
      final lowerCaseQuery = _searchQuery.toLowerCase();
      allMaterials = allMaterials.where((material) {
        // 原料名
        if (material.name.toLowerCase().contains(lowerCaseQuery)) {
          return true;
        }
        // 化学成分名
        if (material.components.keys.any(
          (component) => component.toLowerCase().contains(lowerCaseQuery),
        )) {
          return true;
        }
        return false;
      }).toList();
    }
    return allMaterials;
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // ダイアログ内の状態を管理するためにStatefulBuilderを使用
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('カテゴリで絞り込み'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: app.MaterialCategory.values.map((category) {
                  return CheckboxListTile(
                    title: Text(category.displayName),
                    value: _selectedCategories.contains(category),
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // フィルターが変更されたことをUIに反映
                    Navigator.of(context).pop();
                  },
                  child: const Text('適用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditingNotifier.value;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // 検索・絞り込みバー
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CommonSearchBar(
                        controller: _searchController,
                        hintText: '原料名, 化学成分で検索...',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_alt),
                      onPressed: _showCategoryFilterDialog,
                      tooltip: 'カテゴリで絞り込み',
                    ),
                  ],
                ),
              ),
              // リスト表示エリア
              Expanded(
                child: RefreshIndicator(
                  onRefresh: handleRefresh,
                  child: ref
                      .watch(materialsProvider)
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            Center(child: Text('Error: $error')),
                        data: (allMaterials) {
                          final displayedMaterials = _filterMaterials(
                            allMaterials,
                          );

                          if (displayedMaterials.isEmpty) {
                            return EmptyListPlaceholder(
                              message:
                                  _searchQuery.isNotEmpty ||
                                      _selectedCategories.length !=
                                          app.MaterialCategory.values.length
                                  ? '条件に一致する原料が見つかりません。'
                                  : '原料が登録されていません。\n右下のボタンから追加してください。',
                            );
                          }

                          return ListView.builder(
                            itemCount: displayedMaterials.length,
                            itemBuilder: (context, index) {
                              final material = displayedMaterials[index];
                              return isEditing
                                  ? _buildEditableTile(context, material)
                                  : _buildNormalTile(context, material);
                            },
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'materialsListFab',
              onPressed: isEditing
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MaterialEditScreen(),
                        ),
                      );
                    },
              backgroundColor: isEditing
                  ? Colors.grey
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isEditing ? Colors.black54 : Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  /// 通常表示用のタイル
  Widget _buildNormalTile(BuildContext context, app.Material material) {
    return ListTile(
      title: Row(
        children: [
          Text(material.name),
          const SizedBox(width: 8),
          Chip(
            label: Text(
              material.category.displayName,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            backgroundColor: material.category == app.MaterialCategory.pigment
                ? Colors.pink
                : material.category == app.MaterialCategory.additive
                ? Colors.blue
                : Colors.green,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
          ),
        ],
      ),
      subtitle: Text(
        material.components.keys.join(', '),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MaterialDetailScreen(material: material),
          ),
        );
      },
    );
  }

  /// 編集モード用のタイル
  Widget _buildEditableTile(BuildContext context, app.Material material) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return ListTile(
      key: ValueKey(material.id),
      leading: IconButton(
        icon: const Icon(Icons.remove_circle, color: Colors.red),
        onPressed: () async {
          // この原料を使用している釉薬の数を集計して警告に含める
          final glazes = await ref.read(glazesProvider.future);
          final usedCount = glazes
              .where((g) => g.recipe.containsKey(material.id))
              .length;
          final warning = usedCount > 0
              ? '\n\nこの原料は$usedCount件の釉薬のレシピで使用されています。\n削除すると、それらのレシピでは「不明な原料」と表示されます。'
              : '';

          if (!context.mounted) return;
          // 削除確認ダイアログ
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('削除の確認'),
              content: Text('「${material.name}」を本当に削除しますか？$warning'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('削除'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await firestoreService.deleteMaterial(material.id!);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('「${material.name}」を削除しました。')),
              );
            }
          }
        },
      ),
      title: Text(material.name),
      trailing: const Icon(Icons.edit_note),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MaterialEditScreen(material: material),
          ),
        );
      },
    );
  }
}
