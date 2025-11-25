import 'package:flutter/material.dart';

class CommonAppBarActions extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onDelete;
  final VoidCallback onSave;
  final bool hasDelete;

  const CommonAppBarActions({
    super.key,
    required this.isLoading,
    this.onDelete,
    required this.onSave,
    this.hasDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    return Row(
      children: [
        if (hasDelete && onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: '削除',
            onPressed: onDelete,
          ),
        IconButton(
          icon: const Icon(Icons.save),
          tooltip: '保存',
          onPressed: onSave,
        ),
      ],
    );
  }
}
