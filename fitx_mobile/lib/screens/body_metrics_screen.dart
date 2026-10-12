import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/log_body_metrics_sheet.dart';

/// Body Metrics screen — shows only the LATEST reading as a snapshot.
/// (Trends and history over time live on the Progress screen instead —
/// this screen intentionally does not duplicate that.)
class BodyMetricsScreen extends StatefulWidget {
  const BodyMetricsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  Map<String, dynamic>? _latest;
  bool _isLoading = true;
  String? _error;

  static const _fields = [
    ('weight_kg', 'Weight', 'kg', Icons.monitor_weight_outlined),
    ('height_cm', 'Height', 'cm', Icons.height),
    ('bmi', 'BMI', '', Icons.speed_outlined),
    ('chest_cm', 'Chest', 'cm', Icons.accessibility_new),
    ('right_arm_cm', 'Right Arm', 'cm', Icons.fitness_center),
    ('left_arm_cm', 'Left Arm', 'cm', Icons.fitness_center),
    ('waist_navel_cm', 'Waist (Navel)', 'cm', Icons.straighten),
    ('waist_below_cm', 'Waist (Below)', 'cm', Icons.straighten),
    ('hips_cm', 'Hips', 'cm', Icons.straighten),
    ('right_leg_cm', 'Right Leg', 'cm', Icons.directions_walk),
    ('left_leg_cm', 'Left Leg', 'cm', Icons.directions_walk),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLatest();
  }

  Future<void> _fetchLatest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.0.164/Capstone Project1/api_get_progress.php?user_id=${widget.userId}',
        ),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final metrics = List<Map<String, dynamic>>.from(data['metrics'] ?? []);
        setState(() {
          _latest = metrics.isNotEmpty ? metrics.last : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load body metrics';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => showLogBodyMetricsSheet(
          context,
          userId: widget.userId,
          onSaved: _fetchLatest,
          previousValues: _latest,
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
        onAction: _fetchLatest,
      );
    }

    if (_latest == null) {
      return _EmptyState(
        icon: Icons.accessibility_new,
        title: 'No body metrics recorded yet',
        message: 'Tap the + button to log your first reading.',
      );
    }

    final recordedRaw = _latest!['recorded_at']?.toString();
    final recordedAt = DateTime.tryParse(recordedRaw ?? '');

    return RefreshIndicator(
      onRefresh: _fetchLatest,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Card(
            color: AppColors.accent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.event_available, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recordedAt == null
                          ? 'Latest reading'
                          : 'Last recorded: ${_formatDate(recordedAt)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: _fields.map((f) {
              final (key, label, unit, icon) = f;
              final raw = _latest![key];
              final value = raw == null
                  ? null
                  : double.tryParse(raw.toString());
              final bmiBadge = key == 'bmi' && value != null
                  ? _bmiCategory(value)
                  : null;
              return _MetricTile(
                label: label,
                value: value == null
                    ? '—'
                    : '${value.toStringAsFixed(1)}${unit.isEmpty ? '' : ' $unit'}',
                icon: icon,
                badgeLabel: bmiBadge?.label,
                badgeColor: bmiBadge?.color,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
  }

  /// WHO-style BMI category for a score. Returns the label and badge color:
  /// <18.5 Underweight (blue), 18.5–24.9 Normal (green),
  /// 25–29.9 Overweight (orange), >=30 Obese (red).
  static ({String label, Color color}) _bmiCategory(double bmi) {
    if (bmi < 18.5) return (label: 'Underweight', color: Colors.blue);
    if (bmi <= 24.9) return (label: 'Normal', color: Colors.green);
    if (bmi <= 29.9) return (label: 'Overweight', color: Colors.orange);
    return (label: 'Obese', color: Colors.red);
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.badgeLabel,
    this.badgeColor,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Optional status chip shown under the value (used for the BMI category).
  final String? badgeLabel;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (badgeLabel != null && badgeColor != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor!.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
