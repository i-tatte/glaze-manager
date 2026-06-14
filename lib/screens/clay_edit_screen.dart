import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:glaze_manager/models/clay.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/widgets/common/unsaved_changes_pop_scope.dart';
import 'package:glaze_manager/widgets/common/common_app_bar_actions.dart';

class ClayEditScreen extends ConsumerStatefulWidget {
  final Clay? clay;

  const ClayEditScreen({super.key, this.clay});

  @override
  ConsumerState<ClayEditScreen> createState() => _ClayEditScreenState();
}

class _ClayEditScreenState extends ConsumerState<ClayEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
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

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      final Future<void> writeFuture;
      if (widget.clay == null) {
        // 新規作成 (getClaysOnce はローカルキャッシュから即返るため await を維持)
        final clays = await firestoreService.getClaysOnce();
        final newClay = Clay(name: _nameController.text, order: clays.length);
        writeFuture = firestoreService.addClay(newClay);
      } else {
        // 更新
        final updatedClay = Clay(
          id: widget.clay!.id,
          name: _nameController.text,
          order: widget.clay!.order,
        );
        writeFuture = firestoreService.updateClay(updatedClay);
      }
      writeFuture.catchError((Object e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      });

      _isDirty = false;
      navigator.pop();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesPopScope(
      isDirty: _isDirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.clay == null ? '素地土の新規作成' : '素地土の編集'),
          actions: [
            CommonAppBarActions(
              onDelete: null,
              onSave: _saveClay,
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
