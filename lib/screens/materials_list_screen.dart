import 'package:flutter/material.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/screens/material_edit_screen.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:glaze_manager/screens/material_detail_screen.dart';
import 'package:provider/provider.dart';

class MaterialsListScreen extends StatefulWidget {
  // MainTabScreenから編集状態を監視するためのValueNotifierを受け取る
  final ValueNotifier<bool> isEditingNotifier;

  const MaterialsListScreen({super.key, required this.isEditingNotifier});

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
  State<MaterialsListScreen> createState() => _MaterialsListScreenState();
}

class _MaterialsListScreenState extends State<MaterialsListScreen> {
  final _searchController = TextEditingController();

  late Stream<List<app.Material>> _materialsStream;
  String _searchQuery = '';
  Set<app.MaterialCategory> _selectedCategories = app.MaterialCategory.values
      .toSet();

  @override
  void initState() {
    super.initState();
    _materialsStream = context.read<FirestoreService>().getMaterials();
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
    return Stack(
      children: [
        Column(
          children: [
            // 検索・絞り込みバー
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '原料名, 化学成分で検索...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
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
              child: StreamBuilder<List<app.Material>>(
                stream: _materialsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final allMaterials = snapshot.data ?? [];
                  final displayedMaterials = _filterMaterials(allMaterials);

                  if (displayedMaterials.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty ||
                                _selectedCategories.length !=
                                    app.MaterialCategory.values.length
                            ? '条件に一致する原料が見つかりません。'
                            : '原料が登録されていません。\n右下のボタンから追加してください。',
                        textAlign: TextAlign.center,
                      ),
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
    final firestoreService = context.read<FirestoreService>();
    return ListTile(
      key: ValueKey(material.id),
      leading: IconButton(
        icon: const Icon(Icons.remove_circle, color: Colors.red),
        onPressed: () async {
          // 削除確認ダイアログ
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('削除の確認'),
              content: Text('「${material.name}」を本当に削除しますか？'),
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
            if (mounted) {
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
