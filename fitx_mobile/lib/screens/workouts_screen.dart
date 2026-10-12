import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/user_metrics.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/log_workout_sheet.dart';

/// Workouts screen — placeholder dashboard content for the Workouts section.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key, required this.loginData});

  final Map<String, dynamic>? loginData;

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  static const _wideBreakpoint = 900.0;
  static const _pageSize = 20;
  final AppSection _section = AppSection.dashboard;

  late final UserMetrics _metrics = UserMetrics.fromLoginPayload(
    widget.loginData ?? {},
  );

  List<Map<String, dynamic>> _workouts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppTheme.userDisplayName.value.isEmpty) {
        final name = _metrics.displayName ?? '';
        AppTheme.userDisplayName.value = name.isEmpty ? 'User' : name;
      }
      _fetchWorkouts();
    });
  }

  Future<void> _fetchWorkouts({bool loadMore = false}) async {
    final userId = _metrics.userId;
    if (userId == null) {
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          _isLoading = false;
          _errorMessage = 'User ID not available';
        }
      });
      return;
    }

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiClient.get(
        'api_get_workouts.php?user_id=$userId&limit=$_pageSize&offset=$_offset',
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['workouts'] is List) {
        final newWorkouts = List<Map<String, dynamic>>.from(data['workouts']);
        setState(() {
          if (loadMore) {
            _workouts.addAll(newWorkouts);
            _isLoadingMore = false;
          } else {
            _workouts = newWorkouts;
            _isLoading = false;
          }
          _offset += newWorkouts.length;
          _hasMore = newWorkouts.length >= _pageSize;
        });
      } else {
        setState(() {
          if (loadMore) {
            _isLoadingMore = false;
          } else {
            _isLoading = false;
            _errorMessage = data['message'] ?? 'Failed to load workouts';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          _isLoading = false;
          _errorMessage = 'Could not connect to server';
        }
      });
    }
  }

  String get _sectionTitle => switch (_section) {
    AppSection.dashboard => 'Dashboard',
    AppSection.workouts => 'Workouts',
    AppSection.progress => 'Progress',
    AppSection.bodyMetrics => 'Body Metrics',
    AppSection.profile => 'Profile',
    AppSection.nutritionPlan => 'Nutrition Plan',
    AppSection.checkInHistory => 'Check-in History',
    AppSection.payments => 'Payments',
    AppSection.membership => 'Membership',
    AppSection.logOut => 'Log Out',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;

        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) ...[
                AppDrawer(
                  metrics: _metrics,
                  selectedSection: _section,
                  onSectionSelected: (_) {},
                  automaticallyClose: false,
                ),
                const VerticalDivider(width: 1, thickness: 1),
              ],
              Expanded(child: _buildContent(wide)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(bool wide) {
    if (_section != AppSection.dashboard) {
      return _SectionPlaceholder(section: _section, title: _sectionTitle);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopSummaryRow(metrics: _metrics),
          const SizedBox(height: 24),

          // Log Workout button - matching the style from HomeScreen
          ElevatedButton.icon(
            onPressed: () {
              showLogWorkoutSheet(
                context,
                userId: _metrics.userId ?? 0,
                onSaved: _fetchWorkouts,
              );
            },
            icon: const Icon(Icons.fitness_center, color: Colors.white),
            label: const Text(
              'Log Workout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.all(16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Workout History section
          _WorkoutHistorySection(
            workouts: _workouts,
            isLoading: _isLoading,
            isLoadingMore: _isLoadingMore,
            hasMore: _hasMore,
            errorMessage: _errorMessage,
            onRetry: _fetchWorkouts,
            onLoadMore: () => _fetchWorkouts(loadMore: true),
          ),
        ],
      ),
    );
  }
}

/// Top summary row with two small stat cards: "This Week" and "Last Logged".
class _TopSummaryRow extends StatelessWidget {
  const _TopSummaryRow({required this.metrics});

  final UserMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.dark
        ? AppColors.darkCard
        : AppColors.card;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // "This Week" stat card
            _StatCard(
              label: 'This Week',
              value: '3',
              icon: Icons.trending_up,
              color: AppColors.accent,
            ),
            // "Last Logged" stat card
            _StatCard(
              label: 'Last Logged',
              value: 'Bench Press',
              icon: Icons.fitness_center,
              color: AppColors.accentSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat card inside the top summary row.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic workout history section showing loading, error, empty, or populated states.
class _WorkoutHistorySection extends StatelessWidget {
  const _WorkoutHistorySection({
    required this.workouts,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    this.errorMessage,
    this.onRetry,
    this.onLoadMore,
  });

  final List<Map<String, dynamic>> workouts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Loading workout history...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (workouts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'No workouts logged yet — log your first workout above',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final groupedWorkouts = _groupWorkoutsByDate(workouts);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groupedWorkouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 20),
              itemBuilder: (_, groupIndex) {
                final group = groupedWorkouts[groupIndex];
                return _WorkoutDateGroup(
                  dateLabel: group['dateLabel'] as String,
                  workouts: group['workouts'] as List<Map<String, dynamic>>,
                );
              },
            ),
            if (hasMore) ...[
              const SizedBox(height: 16),
              Center(
                child: _LoadMoreButton(
                  isLoading: isLoadingMore,
                  onPressed: onLoadMore,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupWorkoutsByDate(
    List<Map<String, dynamic>> workouts,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final workout in workouts) {
      final dateStr =
          workout['logged_at']?.toString() ??
          workout['created_at']?.toString() ??
          workout['date']?.toString() ??
          '';
      if (dateStr.isEmpty) continue;

      try {
        final date = DateTime.parse(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);
        final key = dateOnly.toIso8601String();
        groups.putIfAbsent(key, () => []).add(workout);
      } catch (_) {
        groups.putIfAbsent('unknown', () => []).add(workout);
      }
    }

    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((key) {
      final workoutsInGroup = groups[key]!;
      workoutsInGroup.sort((a, b) {
        final aStr =
            a['logged_at']?.toString() ?? a['created_at']?.toString() ?? '';
        final bStr =
            b['logged_at']?.toString() ?? b['created_at']?.toString() ?? '';
        return bStr.compareTo(aStr);
      });

      DateTime? date;
      if (key != 'unknown') {
        date = DateTime.tryParse(key);
      }
      final dateLabel = date != null ? _formatDateLabel(date) : 'Unknown Date';

      return {'dateLabel': dateLabel, 'workouts': workoutsInGroup};
    }).toList();
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(date.year, date.month, date.day);

    if (workoutDate == today) {
      return 'Today';
    } else if (workoutDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

/// Date header with grouped workout cards.
class _WorkoutDateGroup extends StatelessWidget {
  const _WorkoutDateGroup({required this.dateLabel, required this.workouts});

  final String dateLabel;
  final List<Map<String, dynamic>> workouts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            dateLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: workouts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _WorkoutCard(workout: workouts[index]),
        ),
      ],
    );
  }
}

/// Load more button for pagination.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.keyboard_arrow_down),
        label: Text(
          isLoading ? 'Loading...' : 'Load More',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: isLoading
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Individual workout card displaying exercise details.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Map<String, dynamic> workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.dark
        ? AppColors.darkCard
        : AppColors.card;

    final exercise = workout['exercise']?.toString() ?? 'Unknown Exercise';
    final sets = workout['sets']?.toString() ?? '0';
    final reps = workout['reps']?.toString() ?? '0';
    final weight = workout['weight_kg']?.toString() ?? '0';
    final muscleGroup = workout['muscle_group']?.toString() ?? 'Unknown';
    final durationRaw = workout['duration_minutes'];

    final typeRaw = workout['type']?.toString().toLowerCase();
    final bool isCardio;
    if (typeRaw == 'cardio') {
      isCardio = true;
    } else if (typeRaw == 'strength') {
      isCardio = false;
    } else {
      // Infer legacy rows without a type column: duration present => cardio.
      isCardio =
          durationRaw != null &&
          durationRaw.toString().isNotEmpty &&
          durationRaw.toString() != '0' &&
          durationRaw.toString().toLowerCase() != 'null';
    }
    final durationText = durationRaw?.toString() ?? '0';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise name
            Text(
              exercise,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Sets x Reps + Weight (strength) or Duration (cardio)
            if (isCardio)
              Row(
                children: [
                  _InfoChip(
                    label: 'Duration',
                    value: '$durationText min',
                    icon: Icons.timer,
                    color: AppColors.accent,
                  ),
                ],
              )
            else
              Row(
                children: [
                  _InfoChip(
                    label: 'Sets × Reps',
                    value: '$sets × $reps',
                    icon: Icons.repeat,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    label: 'Weight',
                    value:
                        '${double.tryParse(weight)?.toStringAsFixed(1) ?? weight} kg',
                    icon: Icons.fitness_center,
                    color: AppColors.accentSecondary,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            // Muscle group
            Row(
              children: [
                Icon(
                  Icons.accessibility_new,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  muscleGroup,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small info chip used in workout cards.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({required this.section, required this.title});

  final AppSection section;
  final String title;

  static const _icons = {
    AppSection.workouts: Icons.fitness_center,
    AppSection.progress: Icons.trending_up,
    AppSection.bodyMetrics: Icons.accessibility_new,
    AppSection.profile: Icons.person,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[section] ?? Icons.dashboard,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This section is coming soon.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
