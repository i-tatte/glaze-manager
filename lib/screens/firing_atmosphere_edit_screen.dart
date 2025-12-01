import 'package:flutter/material.dart';
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/services/firestore_service.dart';
import 'package:provider/provider.dart';

class FiringAtmosphereEditScreen extends StatefulWidget {
  final FiringAtmosphere? atmosphere;

  const FiringAtmosphereEditScreen({super.key, this.atmosphere});

  @override
  State<FiringAtmosphereEditScreen> createState() =>
      _FiringAtmosphereEditScreenState();
}

class _FiringAtmosphereEditScreenState
    extends State<FiringAtmosphereEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.atmosphere?.name ?? '',
    );
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

  Future<void> _saveAtmosphere() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);

    try {
      final firestoreService = context.read<FirestoreService>();
      final atmosphere = FiringAtmosphere(
        id: widget.atmosphere?.id,
        name: _nameController.text,
      );

      if (widget.atmosphere == null) {
        await firestoreService.addFiringAtmosphere(atmosphere);
      } else {
        await firestoreService.updateFiringAtmosphere(atmosphere);
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
        if (confirmed == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.atmosphere == null ? '雰囲気の新規作成' : '雰囲気の編集'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveAtmosphere,
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
                decoration: const InputDecoration(labelText: '雰囲気名'),
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
