import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:glaze_manager/models/firing_atmosphere.dart';
import 'package:glaze_manager/providers/data_providers.dart';
import 'package:glaze_manager/widgets/common/unsaved_changes_pop_scope.dart';
import 'package:glaze_manager/widgets/common/common_app_bar_actions.dart';

class FiringAtmosphereEditScreen extends ConsumerStatefulWidget {
  final FiringAtmosphere? atmosphere;

  const FiringAtmosphereEditScreen({super.key, this.atmosphere});

  @override
  ConsumerState<FiringAtmosphereEditScreen> createState() =>
      _FiringAtmosphereEditScreenState();
}

class _FiringAtmosphereEditScreenState
    extends ConsumerState<FiringAtmosphereEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late FiringAtmosphereType _selectedType;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.atmosphere?.name ?? '',
    );
    _selectedType = widget.atmosphere?.type ?? FiringAtmosphereType.other;
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

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final atmosphere = FiringAtmosphere(
        id: widget.atmosphere?.id,
        name: _nameController.text,
        type: _selectedType,
      );

      final Future<void> writeFuture;
      if (widget.atmosphere == null) {
        writeFuture = firestoreService.addFiringAtmosphere(atmosphere);
      } else {
        writeFuture = firestoreService.updateFiringAtmosphere(atmosphere);
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
          title: Text(widget.atmosphere == null ? '雰囲気の新規作成' : '雰囲気の編集'),
          actions: [
            CommonAppBarActions(onDelete: null, onSave: _saveAtmosphere),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<FiringAtmosphereType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: '雰囲気タイプ'),
                items: FiringAtmosphereType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      _isDirty = true;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
