import 'package:flutter/material.dart';
import 'package:glaze_manager/models/glaze.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlazeEditScreen extends StatefulWidget {
  final Glaze? glaze;

  const GlazeEditScreen({super.key, this.glaze});

  @override
  State<GlazeEditScreen> createState() => _GlazeEditScreenState();
}

class _GlazeEditScreenState extends State<GlazeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _registeredNameController;
  late TextEditingController _descriptionController;
  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();

  // レシピの各行を管理するためのリスト
  late List<_RecipeRow> _recipeRows;

  // 選択可能な原料のリスト
  List<app.Material> _availableMaterials = [];
  // 既存のタグリスト (オートコンプリート用)
  List<String> _availableTags = [];

  List<String> _tags = [];
  bool _isLoading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.glaze?.name ?? '');
    _registeredNameController =
        TextEditingController(text: widget.glaze?.registeredName ?? '');
    _descriptionController = TextEditingController(
      text: widget.glaze?.description ?? '',
    );
    _tags = widget.glaze?.tags.toList() ?? [];
    _recipeRows = [];

    _nameController.addListener(_markAsDirty);
    _registeredNameController.addListener(_markAsDirty);
    _descriptionController.addListener(_markAsDirty);

    _loadMaterialsAndTags();
    _tagInputController.addListener(_onTagInputChanged);
  }

  Future<void> _loadMaterialsAndTags() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    _availableMaterials = await firestoreService.getMaterials().first;
    _availableTags = await firestoreService.getTags().first;

    if (widget.glaze != null) {
      // 編集モードの場合、既存のレシピを復元
      for (var entry in widget.glaze!.recipe.entries) {
        final materialId = entry.key;
        final amount = entry.value;
        final controller = TextEditingController(text: amount.toString());
        controller.addListener(_markAsDirty);
        _recipeRows.add(
          _RecipeRow(
            selectedMaterialId: materialId,
            amountController: controller,
          ),
        );
      }
    }
    setState(() {}); // 原料リストとタグのロード完了をUIに反映
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  void _onTagInputChanged() {
    final text = _tagInputController.text;
    if (text.contains('　') || text.contains(',')) {
      final newTag = text.replaceAll('　', '').replaceAll(',', '').trim();
      if (newTag.isNotEmpty && !_tags.contains(newTag)) {
        setState(() {
          _tags.add(newTag);
          _markAsDirty();
        });
      }
      _tagInputController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_markAsDirty);
    _registeredNameController.removeListener(_markAsDirty);
    _descriptionController.removeListener(_markAsDirty);
    _tagInputController.removeListener(_onTagInputChanged);
    _nameController.dispose();
    _registeredNameController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    for (var row in _recipeRows) {
      row.amountController.dispose();
    }
    super.dispose();
  }

  Future<void> _saveGlaze() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );

        // レシピMapを作成
        final recipeMap = {
          for (var row in _recipeRows)
            if (row.selectedMaterialId != null)
              row.selectedMaterialId!:
                  double.tryParse(row.amountController.text) ?? 0.0,
        };

        final glaze = Glaze(
          id: widget.glaze?.id,
          name: _nameController.text,
          registeredName: _registeredNameController.text.trim().isEmpty
              ? null : _registeredNameController.text.trim(),
          recipe: recipeMap,
          description: _descriptionController.text.trim(),
          tags: _tags,
          createdAt: widget.glaze?.createdAt ?? Timestamp.now(),
        );

        // タグをマスターリストに追加 (存在しない場合のみ)
        for (final tag in _tags) {
          await firestoreService.addTag(tag);
        }

        if (widget.glaze == null) {
          await firestoreService.addGlaze(glaze);
        } else {
          await firestoreService.updateGlaze(glaze);
        }

        if (mounted) {
          _isDirty = false; // 保存成功でダーティ状態をリセット
          // 1つ前の画面（詳細画面）に戻る
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _confirmDelete() async {
    // 新規作成時は何もしない
    if (widget.glaze == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text('「${widget.glaze!.name}」を本当に削除しますか？\n関連するテストピースは削除されません。'),
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

    if (confirmed == true && mounted) {
      final navigator = Navigator.of(context);
      try {
        await context.read<FirestoreService>().deleteGlaze(widget.glaze!.id!);
        if (mounted) {
          // 編集画面と詳細画面を閉じて一覧画面まで戻る
          int count = 0;
          navigator.popUntil((_) => count++ >= 2);
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return; // canPop: true の場合
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('変更を破棄しますか？'),
            content: const Text('入力中の内容は保存されません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('破棄', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.glaze == null ? '釉薬の新規作成' : '釉薬の編集'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              )
            else
              Row(
                children: [
                  if (widget.glaze != null)
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: '削除', onPressed: _confirmDelete),
                  IconButton(icon: const Icon(Icons.save), tooltip: '保存', onPressed: _saveGlaze),
                ],
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '釉薬名'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? '釉薬名を入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _registeredNameController,
                decoration: const InputDecoration(labelText: '登録名（任意）'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '備考'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text('配合レシピ', style: Theme.of(context).textTheme.titleMedium),
              ..._buildRecipeRows(),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('原料を追加'),
                onPressed: () {
                  _markAsDirty();
                  setState(() {
                    final newAmountController = TextEditingController();
                    newAmountController.addListener(_markAsDirty);
                    _recipeRows.add(
                      _RecipeRow(amountController: newAmountController),
                    );
                  });
                },
              ),
              const SizedBox(height: 24),
              // タグ入力UI
              _buildTagInput(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecipeRows() {
    return List.generate(_recipeRows.length, (index) {
      final row = _recipeRows[index];
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownSearch<app.Material>(
              items: (f, cs) => _availableMaterials,
              itemAsString: (app.Material m) => m.name,
              selectedItem: row.selectedMaterialId != null
                  ? _availableMaterials
                        .where((m) => m.id == row.selectedMaterialId)
                        .firstOrNull
                  : null,
              onChanged: (app.Material? data) {
                _markAsDirty();
                setState(() => row.selectedMaterialId = data?.id);
              },
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                    labelText: "原料を検索",
                    hintText: "原料名を入力...",
                  ),
                  autofocus: true,
                ),
              ),
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(labelText: "原料"),
              ),
              compareFn: (app.Material a, app.Material b) => a.id == b.id,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.amountController,
              decoration: const InputDecoration(labelText: '配合量'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              _markAsDirty();
              setState(
                () => _recipeRows.removeAt(index).amountController.dispose(),
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildTagInput() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'タグ (スペース or カンマで確定)',
        border: OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ..._tags.map(
            (tag) => Chip(
              label: Text(tag),
              onDeleted: () {
                setState(() {
                  _tags.remove(tag);
                  _markAsDirty();
                });
              },
            ),
          ),
          SizedBox(
            width: 200, // 入力フィールドの幅
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return _availableTags.where((String option) {
                  return option.contains(textEditingValue.text) &&
                      !_tags.contains(option);
                });
              },
              onSelected: (String selection) {
                if (!_tags.contains(selection)) {
                  setState(() {
                    _tags.add(selection);
                    _markAsDirty();
                  });
                }
                _tagInputController.clear();
                _tagFocusNode.requestFocus();
              },
              fieldViewBuilder: (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                // 内部のコントローラーと外部のコントローラーを同期させる必要があるが、
                // ここでは単純に内部のコントローラーを使用し、イベントリスナーで処理する
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4.0),
                    hintText: 'タグを入力...',
                  ),
                  onSubmitted: (value) {
                    final newTag = value.trim();
                    if (newTag.isNotEmpty && !_tags.contains(newTag)) {
                      setState(() {
                        _tags.add(newTag);
                        _markAsDirty();
                      });
                    }
                    fieldTextEditingController.clear();
                    fieldFocusNode.requestFocus();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// レシピの一行を管理するためのヘルパークラス
class _RecipeRow {
  String? selectedMaterialId;
  final TextEditingController amountController;

  _RecipeRow({this.selectedMaterialId, TextEditingController? amountController})
    : amountController = amountController ?? TextEditingController();
}
