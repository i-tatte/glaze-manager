import 'package:flutter/material.dart';
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class ClayEditScreen extends StatefulWidget {
  final Clay? clay;

  const ClayEditScreen({super.key, this.clay});

  @override
  State<ClayEditScreen> createState() => _ClayEditScreenState();
}

class _ClayEditScreenState extends State<ClayEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.clay?.name ?? '');
    _nameController.addListener(() {
      if (!_isDirty) {
        setState(() => _isDirty = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveClay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);

    try {
      final firestoreService = context.read<FirestoreService>();

      if (widget.clay == null) {
        // 新規作成
        final clays = await firestoreService.getClays().first;
        final newClay = Clay(name: _nameController.text, order: clays.length);
        await firestoreService.addClay(newClay);
      } else {
        // 更新
        final updatedClay = Clay(
          id: widget.clay!.id,
          name: _nameController.text,
          order: widget.clay!.order,
        );
        await firestoreService.updateClay(updatedClay);
      }

      _isDirty = false;
      navigator.pop();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
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
          title: Text(widget.clay == null ? '素地土の新規作成' : '素地土の編集'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: '保存',
                onPressed: _saveClay,
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
                decoration: const InputDecoration(labelText: '素地土名'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? '名前を入力してください' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
