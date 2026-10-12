import 'package:flutter/material.dart';

class EmptySection extends StatelessWidget {
  const EmptySection({
    super.key,
    this.icon,
    this.title,
    required this.message,
  });

  final IconData? icon;
  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}