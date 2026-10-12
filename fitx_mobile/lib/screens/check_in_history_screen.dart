import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/user_metrics.dart';
import '../theme/app_theme.dart';

/// Check-in History screen — displays gym check-in records for the logged-in user.
class CheckInHistoryScreen extends StatefulWidget {
  const CheckInHistoryScreen({super.key, this.loginData, this.userId});

  final Map<String, dynamic>? loginData;

  /// Explicit backend user id (the same value the Dashboard resolves via
  /// [UserMetrics.fromLoginPayload]). Takes precedence over [loginData];
  /// when null, the id is parsed from the login payload instead.
  final int? userId;

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  static const _pageSize = 30;

  late final UserMetrics _metrics = UserMetrics.fromLoginPayload(
    widget.loginData ?? {},
  );

  List<Map<String, dynamic>> _checkIns = [];
  bool _isLoading = true;
  String? _errorMessage;

  /// Backend user id: explicit route param first (works for email and
  /// Google logins alike), login-payload parse as fallback. A 0 matches the
  /// sibling screens' `?? 0` convention for "unknown" and is treated as absent.
  int? get _userId {
    final explicit = widget.userId;
    if (explicit != null && explicit != 0) return explicit;
    return _metrics.userId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppTheme.userDisplayName.value.isEmpty) {
        final name = _metrics.displayName ?? '';
        AppTheme.userDisplayName.value = name.isEmpty ? 'User' : name;
      }
      _fetchCheckIns();
    });
  }

  Future<void> _fetchCheckIns() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User ID not available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.get(
        'api_get_checkins.php?user_id=$userId&limit=$_pageSize',
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['checkins'] is List) {
        final checkIns = List<Map<String, dynamic>>.from(data['checkins']);
        setState(() {
          _checkIns = checkIns;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = data['message'] ?? 'Failed to load check-ins';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to server';
      });
    }
  }

  int get _thisWeekCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 6));

    int count = 0;
    for (final checkIn in _checkIns) {
      final dateStr =
          checkIn['checked_in_at']?.toString() ??
          checkIn['created_at']?.toString() ??
          checkIn['date']?.toString() ??
          '';
      if (dateStr.isEmpty) continue;

      try {
        final date = DateTime.parse(dateStr.split(RegExp(r'\s+')).first);
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (!dateOnly.isBefore(weekAgo) && !dateOnly.isAfter(today)) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  int get _thisMonthCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthAgo = today.subtract(const Duration(days: 29));

    int count = 0;
    for (final checkIn in _checkIns) {
      final dateStr =
          checkIn['checked_in_at']?.toString() ??
          checkIn['created_at']?.toString() ??
          checkIn['date']?.toString() ??
          '';
      if (dateStr.isEmpty) continue;

      try {
        final date = DateTime.parse(dateStr.split(RegExp(r'\s+')).first);
        final dateOnly = DateTime(date.year, date.month, date.day);
        if (!dateOnly.isBefore(monthAgo) && !dateOnly.isAfter(today)) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in History'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _fetchCheckIns);
    }

    if (_checkIns.isEmpty) {
      return _EmptyState(
        icon: Icons.badge_outlined,
        title: 'No check-ins yet',
        message: 'Your visits will appear here once you start tapping in at the gym.',
      );
    }

    final groupedCheckIns = _groupCheckInsByDate(_checkIns);

    return RefreshIndicator(
      onRefresh: _fetchCheckIns,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          _TopSummaryRow(
            thisWeekCount: _thisWeekCount,
            thisMonthCount: _thisMonthCount,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check-in History',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupedCheckIns.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 20),
                    itemBuilder: (_, groupIndex) {
                      final group = groupedCheckIns[groupIndex];
                      return _CheckInDateGroup(
                        dateLabel: group['dateLabel'] as String,
                        checkIns:
                            group['checkIns'] as List<Map<String, dynamic>>,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupCheckInsByDate(
    List<Map<String, dynamic>> checkIns,
  ) {
    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final checkIn in checkIns) {
      final dateStr =
          checkIn['checked_in_at']?.toString() ??
          checkIn['created_at']?.toString() ??
          checkIn['date']?.toString() ??
          '';
      if (dateStr.isEmpty) continue;

      try {
        final date = DateTime.parse(dateStr.split(RegExp(r'\s+')).first);
        final dateOnly = DateTime(date.year, date.month, date.day);
        final key = dateOnly.toIso8601String();
        groups.putIfAbsent(key, () => []).add(checkIn);
      } catch (_) {
        groups.putIfAbsent('unknown', () => []).add(checkIn);
      }
    }

    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((key) {
      final checkInsInGroup = groups[key]!;
      checkInsInGroup.sort((a, b) {
        final aStr =
            a['checked_in_at']?.toString() ?? a['created_at']?.toString() ?? '';
        final bStr =
            b['checked_in_at']?.toString() ?? b['created_at']?.toString() ?? '';
        return bStr.compareTo(aStr);
      });

      DateTime? date;
      if (key != 'unknown') {
        date = DateTime.tryParse(key);
      }
      final dateLabel = date != null ? _formatDateLabel(date) : 'Unknown Date';

      return {'dateLabel': dateLabel, 'checkIns': checkInsInGroup};
    }).toList();
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkInDate = DateTime(date.year, date.month, date.day);

    if (checkInDate == today) {
      return 'Today';
    } else if (checkInDate == yesterday) {
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

/// Top summary row with two small stat cards: "This Week" and "This Month".
class _TopSummaryRow extends StatelessWidget {
  const _TopSummaryRow({
    required this.thisWeekCount,
    required this.thisMonthCount,
  });

  final int thisWeekCount;
  final int thisMonthCount;

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
            _StatCard(
              label: 'This Week',
              value: thisWeekCount.toString(),
              icon: Icons.calendar_view_week,
              color: AppColors.accent,
            ),
            _StatCard(
              label: 'This Month',
              value: thisMonthCount.toString(),
              icon: Icons.calendar_month,
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

/// Error state widget for check-in history.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for check-in history.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
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
}

/// Date header with grouped check-in cards.
class _CheckInDateGroup extends StatelessWidget {
  const _CheckInDateGroup({required this.dateLabel, required this.checkIns});

  final String dateLabel;
  final List<Map<String, dynamic>> checkIns;

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
          itemCount: checkIns.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _CheckInCard(checkIn: checkIns[index]),
        ),
      ],
    );
  }
}

/// Individual check-in card displaying time and check-in icon.
class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkIn});

  final Map<String, dynamic> checkIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.dark
        ? AppColors.darkCard
        : AppColors.card;

    final dateStr =
        checkIn['checked_in_at']?.toString() ??
        checkIn['created_at']?.toString() ??
        checkIn['date']?.toString() ??
        '';

    String timeStr = '--:--';
    if (dateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(dateStr);
        final hour = date.hour;
        final minute = date.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        timeStr = '$displayHour:$minute $period';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.badge, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check-in',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (checkIn['location'] != null &&
                      checkIn['location'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      checkIn['location'].toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              timeStr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
