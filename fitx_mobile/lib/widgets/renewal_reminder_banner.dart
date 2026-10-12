import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import 'submit_payment_sheet.dart';

/// Conditional payment/renewal reminder banner - shows only if payment is due soon or overdue.
class RenewalReminderBanner extends StatelessWidget {
  const RenewalReminderBanner({super.key, required this.metrics, this.onPaymentSaved});

  final UserMetrics metrics;
  final VoidCallback? onPaymentSaved;

  @override
  Widget build(BuildContext context) {
    final daysLeft = metrics.membershipDaysRemaining;
    final isExpired = daysLeft != null && daysLeft < 0;
    final isWarning = daysLeft != null && daysLeft <= 7 && !isExpired;

    // Hide if account is healthy (no urgency)
    if (!isWarning && !isExpired) return const SizedBox.shrink();

    final color = isExpired ? Colors.red : Colors.orange;
    final message = isExpired
        ? 'Membership has expired'
        : 'Payment due soon - renew your membership';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(isExpired ? Icons.error : Icons.warning, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          if (isWarning)
            TextButton(
              onPressed: () {
                final userId = metrics.userId;
                if (userId == null) return;
                showSubmitPaymentSheet(
                  context,
                  userId: userId,
                  onSaved: onPaymentSaved,
                );
              },
              child: const Text(
                'Renew',
                style: TextStyle(color: Color(0xFFFF5722), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}