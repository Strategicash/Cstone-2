import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({
    super.key,
    required this.workoutsThisWeek,
    required this.totalWorkouts,
    required this.streakDays,
    required this.isLoading,
    this.error,
    this.onBodyMetricsTap,
  });

  final int workoutsThisWeek;
  final int totalWorkouts;
  final int streakDays;
  final bool isLoading;
  final String? error;
  final VoidCallback? onBodyMetricsTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid(context);
    }

    final tiles = <_MetricTile>[
      _MetricTile(
        label: 'Workouts / week',
        value: workoutsThisWeek.toString(),
        icon: Icons.calendar_today,
      ),
      _MetricTile(
        label: 'Total workouts',
        value: totalWorkouts.toString(),
        icon: Icons.check_circle_outline,
      ),
      _MetricTile(
        label: 'Streak (days)',
        value: streakDays.toString(),
        icon: Icons.local_fire_department,
      ),
      _MetricTile(
        label: 'Body Metrics',
        value: 'Not tracked yet — tap to add',
        icon: Icons.accessibility_new,
        isAction: true,
        onTap: onBodyMetricsTap,
      ),
      _MetricTile(
        label: 'Last Check-in',
        value: 'No check-ins yet',
        icon: Icons.access_time,
        // TODO: connect to api_get_checkins.php when RFID access log API exists
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            for (final t in tiles)
              _buildMetricCard(context, t),
          ],
        );
      },
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    final columns = 2;
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List.generate(5, (index) => _buildSkeletonCard(context)),
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[200]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 24,
              width: 80,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, _MetricTile t) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: t.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    t.icon,
                    size: 18,
                    color: t.isAction ? AppColors.accent : AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.label,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t.value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: t.isAction ? AppColors.accent : theme.colorScheme.onSurface,
                ),
              ),
              if (error != null && t.label == 'Workouts / week') ...[
                const SizedBox(height: 4),
                Text(
                  'Failed to load: $error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.isAction = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isAction;
  final VoidCallback? onTap;
}