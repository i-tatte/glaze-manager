import 'package:flutter/material.dart';

class UnsavedChangesPopScope extends StatelessWidget {
  final Widget child;
  final bool isDirty;
  final VoidCallback? onDiscard;

  const UnsavedChangesPopScope({
    super.key,
    required this.child,
    required this.isDirty,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
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
          onDiscard?.call();
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
