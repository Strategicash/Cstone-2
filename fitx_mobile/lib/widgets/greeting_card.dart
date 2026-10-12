import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GreetingCard extends StatelessWidget {
  const GreetingCard({super.key, required this.name, this.email});

  final String name;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center,
                    size: 36, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: theme.textTheme.bodyMedium),
                      Text(name, style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
              ],
            ),
            if (email != null) ...[
              const SizedBox(height: 12),
              Text(
                email!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}