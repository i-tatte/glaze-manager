import 'package:flutter/material.dart';

/// 詳細画面の「ラベル + 値」表示の共通ウィジェット。
///
/// [onTap] を渡すとリンク表示 (primary色 + 下線) になる。
/// [tooltip] を渡すとラベル横にヘルプアイコンが付く。
/// 詳細画面でこの形の情報を表示するときは必ずこれを使う。
class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? tooltip;

  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: onTap != null
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
