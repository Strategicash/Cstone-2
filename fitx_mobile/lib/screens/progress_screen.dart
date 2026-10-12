import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/log_body_metrics_sheet.dart';

/// Progress screen — shows body metric trends over time from body_metrics.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.userId});

  final int userId;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<Map<String, dynamic>> _metrics = [];
  bool _isLoading = true;
  String? _error;
  String _selectedMetric = 'weight_kg';

  static const _metricOptions = {
    'weight_kg': 'Weight (kg)',
    'bmi': 'BMI',
    'chest_cm': 'Chest (cm)',
    'right_arm_cm': 'Right Arm (cm)',
    'left_arm_cm': 'Left Arm (cm)',
    'waist_navel_cm': 'Waist (cm)',
    'hips_cm': 'Hips (cm)',
    'right_leg_cm': 'Right Leg (cm)',
    'left_leg_cm': 'Left Leg (cm)',
  };

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  void _onMetricsSaved() {
    _fetchProgress();
  }

  void _openLogMetricsSheet() {
    final latest = _metrics.isNotEmpty ? _metrics.last : null;
    showLogBodyMetricsSheet(
      context,
      userId: widget.userId,
      onSaved: _onMetricsSaved,
      previousValues: latest,
    );
  }

  Future<void> _fetchProgress() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get(
        'api_get_progress.php?user_id=${widget.userId}',
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          _metrics = List<Map<String, dynamic>>.from(data['metrics'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load progress';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server';
        _isLoading = false;
      });
    }
  }

  /// Parses the selected metric into chart points, skipping null entries.
  List<FlSpot> get _chartSpots {
    final spots = <FlSpot>[];
    for (var i = 0; i < _metrics.length; i++) {
      final raw = _metrics[i][_selectedMetric];
      if (raw == null) continue;
      final value = double.tryParse(raw.toString());
      if (value == null) continue;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  /// Change between first and latest recorded value for the selected metric.
  ({double? first, double? latest, double? change}) get _summary {
    final values = <double>[];
    for (final m in _metrics) {
      final raw = m[_selectedMetric];
      if (raw == null) continue;
      final v = double.tryParse(raw.toString());
      if (v != null) values.add(v);
    }
    if (values.isEmpty) return (first: null, latest: null, change: null);
    final first = values.first;
    final latest = values.last;
    return (first: first, latest: latest, change: latest - first);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _openLogMetricsSheet,
              tooltip: 'Log Metrics',
            ),
          ],
        ),
        body: _MessageState(
          icon: Icons.cloud_off,
          title: 'Something went wrong',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _fetchProgress,
        ),
      );
    }

    if (_metrics.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _openLogMetricsSheet,
              tooltip: 'Log Metrics',
            ),
          ],
        ),
        body: const _MessageState(
          icon: Icons.trending_up,
          title: 'No progress data yet',
          message: 'Record your body metrics to start tracking your progress over time.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openLogMetricsSheet,
            tooltip: 'Log Metrics',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProgress,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _MetricSelector(
              options: _metricOptions,
              selected: _selectedMetric,
              onChanged: (value) => setState(() => _selectedMetric = value),
            ),
            const SizedBox(height: 16),
            _SummaryRow(
              label: _metricOptions[_selectedMetric]!,
              first: _summary.first,
              latest: _summary.latest,
              change: _summary.change,
            ),
            const SizedBox(height: 16),
            _ChartCard(
              spots: _chartSpots,
              label: _metricOptions[_selectedMetric]!,
              entries: _metrics,
            ),
            const SizedBox(height: 16),
            _HistoryList(
              metrics: _metrics,
              metricKey: _selectedMetric,
              metricLabel: _metricOptions[_selectedMetric]!,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrolling chips to pick which metric to chart.
class _MetricSelector extends StatelessWidget {
  const _MetricSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = options.keys.elementAt(index);
          final isSelected = key == selected;
          return ChoiceChip(
            label: Text(options[key]!),
            selected: isSelected,
            onSelected: (_) => onChanged(key),
            selectedColor: AppColors.accent,
            labelStyle: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }
}

/// Starting value, latest value, and the change between them.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.first,
    required this.latest,
    required this.change,
  });

  final String label;
  final double? first;
  final double? latest;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (latest == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No readings recorded for $label yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final delta = change ?? 0;
    final isUp = delta > 0;
    final isFlat = delta == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SummaryCell(label: 'Starting', value: first?.toStringAsFixed(1)),
            _SummaryCell(label: 'Latest', value: latest?.toStringAsFixed(1)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isFlat
                            ? Icons.remove
                            : isUp
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isFlat ? Colors.grey : AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        delta.abs().toStringAsFixed(1),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
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
            value ?? '—',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Line chart of the selected metric over time.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.spots,
    required this.label,
    required this.entries,
  });

  final List<FlSpot> spots;
  final String label;
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (spots.length < 2) {
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
                'Record at least two readings to see a trend line.',
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                label,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Readings listed newest first, with the change from the previous entry.
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.metrics,
    required this.metricKey,
    required this.metricLabel,
  });

  final List<Map<String, dynamic>> metrics;
  final String metricKey;
  final String metricLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reversed = metrics.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(
            'History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...reversed.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final raw = row[metricKey];
          final value = raw == null ? null : double.tryParse(raw.toString());

          // Compare against the entry recorded before this one.
          double? previous;
          if (index + 1 < reversed.length) {
            final prevRaw = reversed[index + 1][metricKey];
            if (prevRaw != null) previous = double.tryParse(prevRaw.toString());
          }
          final delta = (value != null && previous != null)
              ? value - previous
              : null;

          final date = DateTime.tryParse(row['recorded_at']?.toString() ?? '');

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                value == null
                    ? '—'
                    : '${value.toStringAsFixed(1)} $metricLabel',
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

/// Shared empty / error state.
class _MessageState extends StatelessWidget {
  const _MessageState({
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
