import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/log_nutrition_plan_sheet.dart';

class NutritionPlanScreen extends StatefulWidget {
  const NutritionPlanScreen({super.key, required this.memberId});

  final int memberId;

  @override
  State<NutritionPlanScreen> createState() => _NutritionPlanScreenState();
}

class _NutritionPlanScreenState extends State<NutritionPlanScreen> {
  Map<String, dynamic>? _plan;
  List<Map<String, dynamic>> _weightHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlan();
  }

  Future<void> _fetchPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get(
        'api_get_nutrition_plan.php?member_id=${widget.memberId}',
      );

      final data = jsonDecode(response.body);

      if (data['success'] != true) {
        setState(() {
          _error = data['message'] ?? 'Failed to load nutrition plan';
          _isLoading = false;
        });
        return;
      }

      final plan = data['plan'];

      // Fetch full weight history from body_metrics (same endpoint the
      // Progress screen uses). Non-fatal: if this fails we still show the
      // plan with an explanatory message in the progress card.
      List<Map<String, dynamic>> history = [];
      try {
        final progressResponse = await ApiClient.get(
          'api_get_progress.php?user_id=${widget.memberId}',
        );
        final progressData = jsonDecode(progressResponse.body);
        if (progressData['success'] == true) {
          history = List<Map<String, dynamic>>.from(
            progressData['metrics'] ?? [],
          );
        }
      } catch (_) {
        history = [];
      }

      setState(() {
        _plan = plan;
        _weightHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server';
        _isLoading = false;
      });
    }
  }

  /// Valid weight_kg readings in chronological order (oldest first).
  List<double> get _orderedWeights {
    return _sortedWeightEntries
        .map((e) => double.parse(e['weight_kg'].toString()))
        .toList();
  }

  /// Weight entries with a valid weight_kg, sorted oldest first.
  /// Backs both the chart (needs recorded_at alignment) and the summary.
  List<Map<String, dynamic>> get _sortedWeightEntries {
    final entries = List<Map<String, dynamic>>.from(_weightHistory);
    entries.sort((a, b) {
      final da = DateTime.tryParse(a['recorded_at']?.toString() ?? '');
      final db = DateTime.tryParse(b['recorded_at']?.toString() ?? '');
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    return entries
        .where(
          (entry) =>
              double.tryParse(entry['weight_kg']?.toString() ?? '') != null,
        )
        .toList();
  }

  /// Chart points for the "Your Weight" series (index -> weight_kg).
  List<FlSpot> get _weightSpots {
    final entries = _sortedWeightEntries;
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      final value = double.tryParse(entries[i]['weight_kg'].toString());
      if (value == null) continue;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  double? get _goalWeight =>
      double.tryParse(_plan?['goal_weight_kg']?.toString() ?? '');

  double? get _startingWeight {
    final weights = _orderedWeights;
    return weights.isEmpty ? null : weights.first;
  }

  double? get _currentWeight {
    final weights = _orderedWeights;
    return weights.isEmpty ? null : weights.last;
  }

  bool get _canShowProgress =>
      _orderedWeights.length >= 2 && _goalWeight != null;

  /// Fraction (0..1) of how far Current has moved from Starting toward Goal.
  double get _goalProgress {
    final starting = _startingWeight;
    final current = _currentWeight;
    final goal = _goalWeight;
    if (starting == null || current == null || goal == null) return 0;
    if (goal == starting) return current == goal ? 1 : 0;
    return ((current - starting) / (goal - starting)).clamp(0.0, 1.0);
  }

  void _onEditPlan() {
    showLogNutritionPlanSheet(
      context,
      memberId: widget.memberId,
      previousValues: _plan,
      onSaved: _fetchPlan,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition Plan')),
      floatingActionButton: _plan != null
          ? FloatingActionButton(
              backgroundColor: AppColors.accent,
              onPressed: _onEditPlan,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : FloatingActionButton(
              backgroundColor: AppColors.accent,
              onPressed: () => showLogNutritionPlanSheet(
                context,
                memberId: widget.memberId,
                onSaved: _fetchPlan,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EmptyState(
        icon: Icons.cloud_off,
        title: 'Something went wrong',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _fetchPlan,
      );
    }

    if (_plan == null) {
      return _EmptyState(
        icon: Icons.restaurant_outlined,
        title: 'No nutrition plan set yet',
        message: 'Tap the + button to create your first nutrition plan.',
        actionLabel: 'Create Plan',
        onAction: () => showLogNutritionPlanSheet(
          context,
          memberId: widget.memberId,
          onSaved: _fetchPlan,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPlan,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Plan header card
          Card(
            color: AppColors.accent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _plan!['plan_name']?.toString() ?? 'My Nutrition Plan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _plan!['goal']?.toString() ?? 'Maintenance',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _WeightGoalProgress(
            canShow: _canShowProgress,
            starting: _startingWeight,
            current: _currentWeight,
            goal: _goalWeight,
            progress: _goalProgress,
          ),
          const SizedBox(height: 16),

          _WeightTrendChart(
            canShow: _canShowProgress,
            spots: _weightSpots,
            entries: _sortedWeightEntries,
            goalWeight: _goalWeight,
          ),
          const SizedBox(height: 16),

          _WeightHistoryList(entries: _sortedWeightEntries),
          const SizedBox(height: 16),

          // Daily Calories prominent card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Daily Calorie Target',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_plan!['daily_calories']?.toString() ?? '—'} kcal',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Macro breakdown visual
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Macronutrient Breakdown',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _MacroBreakdown(
                    protein: double.tryParse(_plan!['protein_g']?.toString() ?? '0') ?? 0,
                    carbs: double.tryParse(_plan!['carbs_g']?.toString() ?? '0') ?? 0,
                    fats: double.tryParse(_plan!['fats_g']?.toString() ?? '0') ?? 0,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroLegendItem(
                          label: 'Protein',
                          value:
                              '${(double.tryParse(_plan!['protein_g']?.toString() ?? '0') ?? 0).toStringAsFixed(1)}g',
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      Expanded(
                        child: _MacroLegendItem(
                          label: 'Carbs',
                          value:
                              '${(double.tryParse(_plan!['carbs_g']?.toString() ?? '0') ?? 0).toStringAsFixed(1)}g',
                          color: const Color(0xFF2196F3),
                        ),
                      ),
                      Expanded(
                        child: _MacroLegendItem(
                          label: 'Fats',
                          value:
                              '${(double.tryParse(_plan!['fats_g']?.toString() ?? '0') ?? 0).toStringAsFixed(1)}g',
                          color: const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Meals per day & Notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: AppColors.accent, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Meals per Day',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_plan!['meals_per_day']?.toString() ?? '3'} meals',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if ((_plan!['notes']?.toString() ?? '').isNotEmpty) ...[
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, color: AppColors.accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _plan!['notes']!.toString(),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Starting → Current → Goal comparison with a horizontal progress bar.
/// Shows an explanatory message when there are fewer than 2 weigh-ins or
/// no goal weight is set.
class _WeightGoalProgress extends StatelessWidget {
  const _WeightGoalProgress({
    required this.canShow,
    required this.starting,
    required this.current,
    required this.goal,
    required this.progress,
  });

  final bool canShow;
  final double? starting;
  final double? current;
  final double? goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Weight Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!canShow)
              Text(
                'Set a goal weight and log at least two weigh-ins to see your progress here',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _WeightCell(
                      label: 'Starting',
                      value: '${starting!.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _WeightCell(
                      label: 'Current',
                      value: '${current!.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _WeightCell(
                      label: 'Goal',
                      value: '${goal!.toStringAsFixed(1)} kg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% of the way from Starting to Goal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightCell extends StatelessWidget {
  const _WeightCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Dual-line weight-vs-goal chart: "Your Weight" trend + dashed "Goal" line.
/// Mirrors progress_screen.dart's _ChartCard styling for the weight series.
/// Shows the explanatory empty-state message when there are fewer than 2
/// weigh-ins or no goal weight is set.
class _WeightTrendChart extends StatelessWidget {
  const _WeightTrendChart({
    required this.canShow,
    required this.spots,
    required this.entries,
    required this.goalWeight,
  });

  final bool canShow;
  final List<FlSpot> spots;
  final List<Map<String, dynamic>> entries;
  final double? goalWeight;

  static const _goalColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!canShow || goalWeight == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Set a goal weight and log at least two weigh-ins to see your progress here',
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

    final goalSpots = [
      FlSpot(0, goalWeight!),
      FlSpot((spots.length - 1).toDouble(), goalWeight!),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Weight vs Goal (kg)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (spots.length / 4).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final raw = entries[i]['recorded_at']?.toString();
                          final date = DateTime.tryParse(raw ?? '');
                          if (date == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${date.month}/${date.day}',
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: AppColors.accent,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.accent,
                              strokeWidth: 2,
                              strokeColor: theme.colorScheme.surface,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    LineChartBarData(
                      spots: goalSpots,
                      isCurved: false,
                      color: _goalColor,
                      barWidth: 2,
                      dashArray: [6, 4],
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChartLegendItem(
                  color: AppColors.accent,
                  label: 'Your Weight',
                ),
                SizedBox(width: 20),
                _ChartLegendItem(
                  color: _WeightTrendChart._goalColor,
                  label: 'Goal',
                  dashed: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                Container(
                  width: 6,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (i < 2) const SizedBox(width: 2),
              ],
            ],
          )
        else
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Weight-only history (newest first), mirroring progress_screen.dart's
/// _HistoryList: each entry shows weight, date, and change vs the previous.
class _WeightHistoryList extends StatelessWidget {
  const _WeightHistoryList({required this.entries});

  /// Chronological (oldest first) entries with valid weight_kg.
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final reversed = entries.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(
            'Weight History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...reversed.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final value = double.tryParse(row['weight_kg']?.toString() ?? '');

          // Compare against the entry recorded before this one.
          double? previous;
          if (index + 1 < reversed.length) {
            previous = double.tryParse(
              reversed[index + 1]['weight_kg']?.toString() ?? '',
            );
          }
          final delta = (value != null && previous != null)
              ? value - previous
              : null;

          final date = DateTime.tryParse(row['recorded_at']?.toString() ?? '');

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                value == null ? '—' : '${value.toStringAsFixed(1)} kg',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                date == null ? 'Unknown date' : _formatDate(date),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: delta == null || delta == 0
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          delta.abs().toStringAsFixed(1),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }),
      ],
    );
  }

  static String _formatDate(DateTime date) {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _MacroBreakdown extends StatelessWidget {
  const _MacroBreakdown({
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  final double protein;
  final double carbs;
  final double fats;

  double get _total => protein + carbs + fats;
  double get _proteinPct => _total > 0 ? protein / _total : 0;
  double get _carbsPct => _total > 0 ? carbs / _total : 0;
  double get _fatsPct => _total > 0 ? fats / _total : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Horizontal bar chart
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (protein > 0)
                Flexible(
                  flex: (_proteinPct * 1000).round(),
                  fit: FlexFit.tight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (carbs > 0)
                Flexible(
                  flex: (_carbsPct * 1000).round(),
                  fit: FlexFit.tight,
                  child: Container(
                    color: const Color(0xFF2196F3),
                    child: _proteinPct == 0
                        ? Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              if (fats > 0)
                Flexible(
                  flex: (_fatsPct * 1000).round(),
                  fit: FlexFit.tight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800),
                      borderRadius: _total == fats
                          ? BorderRadius.circular(14)
                          : const BorderRadius.only(
                              topRight: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                    ),
                  ),
                ),
              if (_total == 0)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No macro data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Percentage labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (protein > 0)
              Text(
                '${(_proteinPct * 100).toStringAsFixed(0)}% Protein',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (carbs > 0)
              Text(
                '${(_carbsPct * 100).toStringAsFixed(0)}% Carbs',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (fats > 0)
              Text(
                '${(_fatsPct * 100).toStringAsFixed(0)}% Fats',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFFF9800),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MacroLegendItem extends StatelessWidget {
  const _MacroLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}