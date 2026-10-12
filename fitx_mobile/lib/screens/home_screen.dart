import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/user_metrics.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../screens/workouts_screen.dart';
import '../widgets/renewal_reminder_banner.dart';
import '../widgets/goals_list.dart';
import '../widgets/greeting_card.dart';
import '../widgets/membership_card.dart';
import '../widgets/metrics_grid.dart';
import '../widgets/log_workout_sheet.dart';
import '../screens/progress_screen.dart';
import '../screens/body_metrics_screen.dart';
import '../screens/nutrition_plan_screen.dart';
import '../screens/check_in_history_screen.dart';
import '../screens/membership_screen.dart';
import '../screens/payments_screen.dart';

/// Dashboard shell: owns the responsive sidebar and swaps content based on
/// the selected [AppSection]. All data comes from the login payload and is
/// parsed defensively via [UserMetrics.fromLoginPayload].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.loginData});

  /// The raw JSON body returned by the login backend, parsed as a map.
  final Map<String, dynamic>? loginData;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _wideBreakpoint = 900.0;

  AppSection _section = AppSection.dashboard;
  late final UserMetrics _metrics = UserMetrics.fromLoginPayload(
    widget.loginData ?? {},
  );

  List<Map<String, dynamic>> _workouts = [];
  bool _isLoadingWorkouts = true;
  String? _workoutsError;

  int _workoutsThisWeek = 0;
  int _totalWorkouts = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Overwrite (never seed-if-empty): these notifiers are process-static
      // and survive Log Out -> Log In, so each new session must replace the
      // previous user's values instead of inheriting them.
      final sessionName = _metrics.displayName ?? '';
      AppTheme.userDisplayName.value = sessionName.isNotEmpty
          ? sessionName
          : _emailPrefix(_metrics.email);
      AppTheme.userEmail.value = _metrics.email ?? '';
      AppTheme.userWorkoutGoals.value = _metrics.workoutGoals ?? '';
      _fetchWorkouts();
    });
  }

  /// Email prefix (`kokoy` from `kokoy@gmail.com`) used as a last-resort
  /// display name. Returns '' when there is no usable email.
  static String _emailPrefix(String? email) {
    if (email == null) return '';
    final at = email.indexOf('@');
    if (at <= 0) return '';
    return email.substring(0, at);
  }

  Future<void> _fetchWorkouts() async {
    final userId = _metrics.userId;
    if (userId == null) {
      setState(() {
        _isLoadingWorkouts = false;
        _workoutsError = 'User ID not available';
        _calculateMetrics();
      });
      return;
    }

    setState(() {
      _isLoadingWorkouts = true;
      _workoutsError = null;
    });

    try {
      final response = await ApiClient.get(
        'api_get_workouts.php?user_id=$userId',
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['workouts'] is List) {
        final workouts = List<Map<String, dynamic>>.from(data['workouts']);
        setState(() {
          _workouts = workouts;
          _isLoadingWorkouts = false;
        });
        _calculateMetrics();
      } else {
        setState(() {
          _isLoadingWorkouts = false;
          _workoutsError = data['message'] ?? 'Failed to load workouts';
          _calculateMetrics();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingWorkouts = false;
        _workoutsError = 'Could not connect to server';
        _calculateMetrics();
      });
    }
  }

  void _calculateMetrics() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));

    int workoutsThisWeek = 0;
    final Set<String> workoutDates = {};

    for (final workout in _workouts) {
      final dateStr =
          workout['logged_at']?.toString() ??
          workout['created_at']?.toString() ??
          workout['date']?.toString() ??
          '';
      if (dateStr.isEmpty) continue;

      try {
        final date = _parseMysqlDateTime(dateStr);
        final dateOnly = DateTime(date.year, date.month, date.day);
        workoutDates.add(dateOnly.toIso8601String());

        if (!dateOnly.isBefore(weekAgo) && !dateOnly.isAfter(today)) {
          workoutsThisWeek++;
        }
      } catch (_) {}
    }

    int streakDays = 0;
    DateTime checkDate = today;
    while (workoutDates.contains(checkDate.toIso8601String())) {
      streakDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    setState(() {
      _workoutsThisWeek = workoutsThisWeek;
      _totalWorkouts = _workouts.length;
      _streakDays = streakDays;
    });
  }

  DateTime _parseMysqlDateTime(String dateStr) {
    final trimmed = dateStr.trim();
    final datePart = trimmed.split(RegExp(r'\s+')).first;
    return DateTime.parse(datePart);
  }

  void _onSectionSelected(AppSection section) {
    setState(() => _section = section);
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
        final drawer = AppDrawer(
          metrics: _metrics,
          selectedSection: _section,
          onSectionSelected: _onSectionSelected,
          automaticallyClose: !wide,
          loginData: widget.loginData,
        );

        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 300, child: drawer),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(_sectionTitle)),
          drawer: drawer,
          body: _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case AppSection.workouts:
        return WorkoutsScreen(loginData: widget.loginData);

      case AppSection.progress:
        return ProgressScreen(userId: _metrics.userId ?? 0);

      case AppSection.bodyMetrics:
        return BodyMetricsScreen(userId: _metrics.userId ?? 0);

      case AppSection.nutritionPlan:
        return NutritionPlanScreen(memberId: _metrics.userId ?? 0);

      case AppSection.checkInHistory:
        return CheckInHistoryScreen(
          loginData: widget.loginData,
          userId: _metrics.userId,
        );

      case AppSection.payments:
        return PaymentsScreen(userId: _metrics.userId ?? 0);

      case AppSection.membership:
        return MembershipScreen(metrics: _metrics);

      case AppSection.dashboard:
        final content = RefreshIndicator(
          onRefresh: () async {
            // Pull-to-refresh returns immediately; the login payload is static
            // per session. Hook future API fetches here.
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Membership Card with dynamic plan/expiry/urgency
              MembershipCard(metrics: _metrics),
              const SizedBox(height: 16),

              // 2. Log Workout button - full-width, orange accent
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
              const SizedBox(height: 16),

              // 3. Greeting Card
              GreetingCard(
                name: _metrics.displayName ?? 'Member',
                email: _metrics.email ?? 'No email',
              ),
              const SizedBox(height: 16),

              // 4. Metrics Grid (stats grid)
              MetricsGrid(
                workoutsThisWeek: _workoutsThisWeek,
                totalWorkouts: _totalWorkouts,
                streakDays: _streakDays,
                isLoading: _isLoadingWorkouts,
                error: _workoutsError,
                onBodyMetricsTap: () =>
                    _onSectionSelected(AppSection.bodyMetrics),
              ),
              const SizedBox(height: 16),

              // 5. Last Check-in stat - added to grid below
              // (handled inside MetricsGrid tiles)

              // 6. Recent Workouts section
              _RecentWorkoutsSection(
                workouts: _workouts,
                isLoading: _isLoadingWorkouts,
                error: _workoutsError,
                onViewAll: () => _onSectionSelected(AppSection.workouts),
              ),

              const SizedBox(height: 16),

              // 7. Conditional Payment Due Soon banner - only shows if <= 7 days
              if (_metrics.daysUntilPaymentDue != null &&
                  _metrics.daysUntilPaymentDue! <= 7)
                RenewalReminderBanner(metrics: _metrics),
              const SizedBox(height: 16),

              GoalsList(metrics: _metrics),
            ],
          ),
        );

        // Keep the dashboard readable on very wide screens.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: content,
          ),
        );
      default:
        return _SectionPlaceholder(section: _section, title: _sectionTitle);
    }
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

/// Recent Workouts section showing the 3 most recent workout entries.
class _RecentWorkoutsSection extends StatelessWidget {
  const _RecentWorkoutsSection({
    required this.workouts,
    required this.isLoading,
    this.error,
    required this.onViewAll,
  });

  final List<Map<String, dynamic>> workouts;
  final bool isLoading;
  final String? error;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Workouts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(
                3,
                (index) => _buildSkeletonWorkoutCard(context),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Workouts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load: $error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final recentWorkouts = workouts.take(3).toList();

    if (recentWorkouts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Workouts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'No workouts logged yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Workouts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 12),
            ...recentWorkouts.map(
              (workout) => _RecentWorkoutCard(workout: workout),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonWorkoutCard(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[200]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual recent workout card for the dashboard.
class _RecentWorkoutCard extends StatelessWidget {
  const _RecentWorkoutCard({required this.workout});

  final Map<String, dynamic> workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final exercise = workout['exercise']?.toString() ?? 'Unknown Exercise';
    final sets = workout['sets']?.toString() ?? '0';
    final reps = workout['reps']?.toString() ?? '0';
    final weight = workout['weight_kg']?.toString() ?? '0';
    final dateStr =
        workout['logged_at']?.toString() ??
        workout['created_at']?.toString() ??
        workout['date']?.toString() ??
        '';

    final relativeDate = _formatRelativeDate(dateStr);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fitness_center,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sets × $reps  •  ${double.tryParse(weight)?.toStringAsFixed(1) ?? weight} kg',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            relativeDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(String dateStr) {
    if (dateStr.isEmpty) return 'Unknown';

    try {
      final trimmed = dateStr.trim();
      final datePart = trimmed.split(RegExp(r'\s+')).first;
      final date = DateTime.parse(datePart);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final workoutDate = DateTime(date.year, date.month, date.day);

      final diff = today.difference(workoutDate).inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return '${diff}d ago';

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return 'Unknown';
    }
  }
}
