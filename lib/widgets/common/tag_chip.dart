import 'package:flutter/material.dart';

/// タグ表示の共通Chip。
///
/// 「タグ」という情報は画面を問わず必ずこのウィジェットで表示する
/// (一覧の行内・詳細画面・検索条件・編集フォームなど)。
/// 削除可能な文脈では [onDeleted] を、タップで遷移する文脈では [onPressed] を渡す。
/// 見た目の定義はここに一元化する。
class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;
  final VoidCallback? onPressed;

  const TagChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chip = Chip(
      label: Text(
        label,
        style: TextStyle(color: colorScheme.onPrimary, fontSize: 12),
      ),
      backgroundColor: colorScheme.primary,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onDeleted: onDeleted,
      deleteIconColor: onDeleted != null ? colorScheme.onPrimary : null,
    );
    if (onPressed == null) return chip;
    return GestureDetector(onTap: onPressed, child: chip);
  }
}
