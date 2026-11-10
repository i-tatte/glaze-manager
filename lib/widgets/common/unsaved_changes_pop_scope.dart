import 'package:flutter/material.dart';

class UnsavedChangesPopScope extends StatelessWidget {
  final Widget child;
  final bool isDirty;
  final VoidCallback? onDiscard;

  /// 未保存の確認とは別に、閉じる前に確かめること。true を返せば閉じてよい。
  /// null なら確かめない。未保存の変更もあれば、これを通ったあとに未保存の
  /// 確認を出す。
  final Future<bool> Function()? confirmLeave;

  const UnsavedChangesPopScope({
    super.key,
    required this.child,
    required this.isDirty,
    this.onDiscard,
    this.confirmLeave,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty && confirmLeave == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmLeave = this.confirmLeave;
        if (confirmLeave != null) {
          if (!await confirmLeave() || !context.mounted) return;
        }
        if (isDirty) {
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
          if (confirmed != true) return;
        }
        if (context.mounted) {
          onDiscard?.call();
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
