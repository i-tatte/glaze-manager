import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glaze_manager/models/material.dart' as app;
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class MaterialEditScreen extends StatefulWidget {
  final app.Material? material;

  const MaterialEditScreen({super.key, this.material});

  @override
  State<MaterialEditScreen> createState() => _MaterialEditScreenState();
}

class _MaterialEditScreenState extends State<MaterialEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late List<_ComponentController> _componentControllers;
  bool _isLoading = false;
  bool _isDirty = false;
  late app.MaterialCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material?.name ?? '');
    _componentControllers =
        widget.material?.components.entries.map((e) {
          return _ComponentController(
            name: TextEditingController(text: e.key),
            value: TextEditingController(text: e.value.toString()),
          );
        }).toList() ??
        [];
    _selectedCategory = widget.material?.category ?? app.MaterialCategory.base;

    _nameController.addListener(_markAsDirty);
    for (var controller in _componentControllers) {
      controller.name.addListener(_markAsDirty);
      controller.value.addListener(_markAsDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var controller in _componentControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Future<void> _saveMaterial() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final firestoreService = Provider.of<FirestoreService>(
          context,
          listen: false,
        );
        final componentsMap = {
          for (var c in _componentControllers)
            if (c.name.text.isNotEmpty)
              c.name.text: double.tryParse(c.value.text) ?? 0.0,
        };

        final navigator = Navigator.of(context);

        if (widget.material == null) {
          // 新規作成
          final newMaterial = app.Material(
            name: _nameController.text,
            components: componentsMap,
            // orderは現在時刻のミリ秒を使うことで、オフラインでもユニークな順序を担保する
            order: DateTime.now().millisecondsSinceEpoch,
            category: app.MaterialCategory.base, // デフォルト値を設定
          );
          firestoreService.addMaterial(newMaterial);
        } else {
          // 更新
          final updatedMaterial = app.Material(
            id: widget.material!.id,
            name: _nameController.text,
            components: componentsMap,
            order: widget.material!.order,
            category: _selectedCategory,
          );
          firestoreService.updateMaterial(updatedMaterial);
        }

        if (mounted) {
          _isDirty = false; // isDirtyはUI更新不要
        }
        navigator.pop(); // 成功したら画面を閉じる
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      } finally {
        // 成功・失敗にかかわらず、最後に必ずローディング状態を解除する
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _confirmDelete() async {
    // 新規作成時は何もしない
    if (widget.material == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: Text(
          '「${widget.material!.name}」を本当に削除しますか？\nこの原料を使用している釉薬レシピがある場合、問題が発生する可能性があります。',
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

    if (confirmed == true && mounted) {
      final navigator = Navigator.of(context);
      try {
        await context.read<FirestoreService>().deleteMaterial(widget.material!.id!);
        navigator.popUntil((route) => route.isFirst); // 一覧画面まで戻る
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    }
  }

  /// ペーストされた組成データを解析してコンポーネントを追加する
  void _parseAndAddComponents(String text) {
    final lines = text.trim().split('\n');
    for (final line in lines) {
      final parts = line.split('\t');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final valueStr = parts[1].trim().replaceAll('%', '');
        double value;

        if (name.isEmpty) continue;

        if (valueStr.toLowerCase() == 'trace') {
          value = 0.0;
        } else {
          value = double.tryParse(valueStr) ?? 0.0;
        }

        _componentControllers.add(
          _ComponentController(
            name: TextEditingController(text: name),
            value: TextEditingController(text: value.toString()),
          ),
        );
        // 新しく追加されたコントローラーにもリスナーをセット
        _componentControllers.last.name.addListener(_markAsDirty);
        _componentControllers.last.value.addListener(_markAsDirty);
      }
    }
    if (lines.isNotEmpty) {
      _markAsDirty();
      setState(() {});
    }
  }

  /// 組成データをペーストするためのダイアログを表示する
  Future<void> _showPasteDialog() async {
    final pasteController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('組成データを貼り付け'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pasteController,
              maxLines: 10,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'ここに組成データを貼り付けてください。\n例:\nSiO2\t66.71%\nAl2O3\t18.56%',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('クリップボードから貼り付け'),
              onPressed: () async {
                final clipboardData = await Clipboard.getData(
                  Clipboard.kTextPlain,
                );
                if (clipboardData != null) {
                  pasteController.text = clipboardData.text ?? '';
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              _parseAndAddComponents(pasteController.text);
              Navigator.of(context).pop();
            },
            child: const Text('フォームに追加'),
          ),
        ],
      ),
    );
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
          title: Text(widget.material == null ? '原料の新規作成' : '原料の編集'),
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
                  if (widget.material != null)
                    IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: '削除',
                        onPressed: _confirmDelete),
                  IconButton(icon: const Icon(Icons.save), tooltip: '保存', onPressed: _saveMaterial),
                ],
              )
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '原料名'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? '原料名を入力してください' : null,
              ),
              const SizedBox(height: 24),
              Text('カテゴリ', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<app.MaterialCategory>(
                segments: app.MaterialCategory.values
                    .map(
                      (category) => ButtonSegment<app.MaterialCategory>(
                        value: category,
                        label: Text(category.displayName),
                      ),
                    )
                    .toList(),
                selected: {_selectedCategory},
                onSelectionChanged: (newSelection) {
                  _markAsDirty();
                  setState(() {
                    _selectedCategory = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  // 選択されていないボタンのテキスト色を少し薄くする
                  foregroundColor: Colors.grey.shade600,
                  selectedForegroundColor: Theme.of(
                    context,
                  ).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('化学成分', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.paste),
                    tooltip: 'クリップボードから貼り付け',
                    onPressed: _showPasteDialog,
                  ),
                ],
              ),
              ..._buildComponentFields(),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('成分を追加'),
                onPressed: () {
                  _markAsDirty();
                  setState(() {
                    final newController = _ComponentController();
                    newController.name.addListener(_markAsDirty);
                    newController.value.addListener(_markAsDirty);
                    _componentControllers.add(newController);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComponentFields() {
    return List.generate(_componentControllers.length, (index) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _componentControllers[index].name,
              decoration: const InputDecoration(labelText: '成分名 (例: SiO2)'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: _componentControllers[index].value,
              decoration: const InputDecoration(labelText: '量 (%)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              _markAsDirty();
              setState(() {
                _componentControllers.removeAt(index).dispose();
              });
            },
          ),
        ],
      );
    });
  }
}

class _ComponentController {
  final TextEditingController name;
  final TextEditingController value;
  _ComponentController({
    TextEditingController? name,
    TextEditingController? value,
  }) : name = name ?? TextEditingController(),
       value = value ?? TextEditingController();

  void dispose() {
    name.dispose();
    value.dispose();
  }
}
