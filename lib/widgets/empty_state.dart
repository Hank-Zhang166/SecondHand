import 'package:flutter/material.dart';

/// 空状态占位
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: const Color(0xFFD7CCC8)),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Color(0xFF9E9E9E))),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}
