import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import '../theme/app_theme.dart';

/// Highlighted membership summary shown at the top of the dashboard.
class MembershipCard extends StatelessWidget {
  const MembershipCard({super.key, required this.metrics});

  final UserMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final plan = metrics.membershipType;
    final validity = metrics.membershipValidity;
    final status = metrics.membershipStatus ?? 'Active Member';
    final start = metrics.membershipStart;
    final end = metrics.membershipEnd;
    final daysLeft = metrics.membershipDaysRemaining;
    final isExpired = daysLeft != null && daysLeft < 0;
    final isWarning = daysLeft != null && daysLeft <= 7 && !isExpired;

    final hasPlan = plan != null && plan.isNotEmpty;
    final hasValidity = validity != null && validity.isNotEmpty;
    final hasStart = start != null && start.isNotEmpty;
    final hasEnd = end != null && end.isNotEmpty;
    final hasDaysLeft = daysLeft != null;
    final hasDetails =
        hasPlan || hasValidity || hasStart || hasEnd || hasDaysLeft;

    final hasActiveStatus = status.isNotEmpty;
    if (!hasActiveStatus || metrics.membershipEndDate == null) {
      return Card(
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accentSecondary],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.card_membership_outlined,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'FITX MEMBERSHIP',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: Colors.white, letterSpacing: 1.1),
                    ),
                  ),
                  const _StatusChip(label: 'INACTIVE', isExpired: false),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'NO ACTIVE MEMBERSHIP',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a plan below to activate your FitX Gym membership.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    Color? borderColor;
    if (isExpired) {
      borderColor = Colors.red;
    } else if (isWarning) {
      borderColor = Colors.orange;
    }

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          gradient: isWarning
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFfda41b), Color(0xFFFF7849)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.accentSecondary],
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_membership, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'FITX MEMBERSHIP',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: Colors.white, letterSpacing: 1.1),
                  ),
                ),
                _StatusChip(label: status, isExpired: isExpired),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    plan ?? 'Membership',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (validity != null)
                  Text(validity, style: const TextStyle(color: Colors.white70)),
              ],
            ),
            if (!hasDetails) ...[
              const SizedBox(height: 4),
              Text(
                'Membership details are not available yet.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (hasDetails) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (hasStart) ...[
                    Expanded(
                      child: _DetailColumn(
                        label: 'Start',
                        value: _formatDate(start),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (hasEnd) ...[
                    Expanded(
                      child: _DetailColumn(
                        label: 'End',
                        value: _formatDate(end),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (hasValidity) ...[
                    Expanded(
                      child: _DetailColumn(label: 'Valid', value: validity),
                    ),
                  ],
                ],
              ),
              if (daysLeft != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isExpired
                            ? 'Membership expired'
                            : isWarning
                            ? '⚠️ $daysLeft days remaining - renew soon'
                            : '$daysLeft days remaining',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (isWarning)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Renew',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(String? raw) {
    final dt = parseFlexibleDate(raw);
    if (dt == null) return raw ?? '—';
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
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isExpired});

  final String label;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.shade700
            : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _DetailColumn extends StatelessWidget {
  const _DetailColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
