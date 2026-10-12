import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_section.dart';
import '../widgets/submit_payment_sheet.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    if (widget.userId == 0) {
      setState(() {
        _isLoading = false;
        _error = 'User ID not available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get(
        'api_get_payments.php?user_id=${widget.userId}',
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (data['success'] == true && data['payments'] is List) {
        final payments = List<Map<String, dynamic>>.from(data['payments']);
        payments.sort((a, b) {
          final dateA = _parseDate(a['created_at'] ?? a['date'] ?? '');
          final dateB = _parseDate(b['created_at'] ?? b['date'] ?? '');
          return dateB.compareTo(dateA);
        });
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = data['message'] ?? 'Failed to load payments';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not connect to server';
      });
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      final trimmed = dateStr.trim();
      final datePart = trimmed.split(RegExp(r'\s+')).first;
      return DateTime.parse(datePart);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = _parseDate(raw);
      if (dt == DateTime.fromMillisecondsSinceEpoch(0)) return raw;
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatAmount(dynamic amount) {
    final num value = amount is num
        ? amount
        : num.tryParse(amount?.toString() ?? '0') ?? 0;
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(value);
  }

  Map<String, dynamic>? _getActiveMembershipPayment() {
    for (final payment in _payments) {
      final status = (payment['status'] ?? '').toString().toLowerCase();
      if (status == 'paid') {
        final expiresAt = payment['expires_at']?.toString() ?? '';
        final expiresDate = _parseDate(expiresAt);
        if (expiresDate != DateTime.fromMillisecondsSinceEpoch(0) &&
            expiresDate.isAfter(DateTime.now())) {
          return payment;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activePayment = _getActiveMembershipPayment();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPayments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Membership Status Summary Card
            _buildMembershipStatusCard(activePayment),
            const SizedBox(height: 16),

            // Submit Payment Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showSubmitPaymentSheet(
                    context,
                    userId: widget.userId,
                    onSaved: _fetchPayments,
                  );
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  'Submit Payment',
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
            ),
            const SizedBox(height: 16),

            // Payment History Section
            _buildPaymentHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipStatusCard(Map<String, dynamic>? activePayment) {
    final theme = Theme.of(context);

    if (activePayment != null) {
      final expiresAt = activePayment['expires_at']?.toString() ?? '';
      final formattedDate = _formatDate(expiresAt);

      return Card(
        margin: EdgeInsets.zero,
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
          child: Row(
            children: [
              const Icon(Icons.card_membership, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Membership',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Active until $formattedDate',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Icon(
              Icons.card_membership_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Membership Status',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No active membership period on file',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'INACTIVE',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistorySection() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(3, (index) => _buildSkeletonPaymentCard()),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment History',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load: $_error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return EmptySection(
        icon: Icons.receipt_long_outlined,
        message: 'No payments recorded yet.\nTap "Submit Payment" to add your first payment.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._payments.map(
              (payment) => _PaymentHistoryCard(
                payment: payment,
                formatDate: _formatDate,
                formatAmount: _formatAmount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonPaymentCard() {
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
                  width: 140,
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

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.payment,
    required this.formatDate,
    required this.formatAmount,
  });

  final Map<String, dynamic> payment;
  final String Function(String?) formatDate;
  final String Function(dynamic) formatAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final description = payment['description']?.toString() ?? 'Payment';
    final amount = payment['amount'];
    final status = (payment['status'] ?? 'pending').toString().toLowerCase();
    final dateStr =
        payment['created_at']?.toString() ?? payment['date']?.toString() ?? '';
    final formattedDate = formatDate(dateStr);
    final formattedAmount = formatAmount(amount);
    final referenceNumber =
        (payment['reference_number'] ??
                payment['reference_no'] ??
                payment['ref_number'] ??
                '')
            .toString()
            .trim();

    final isPaid = status == 'paid';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPaid
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPaid ? Icons.check_circle : Icons.pending,
                color: isPaid ? Colors.green : Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedAmount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isPaid ? 'Paid' : 'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                if (referenceNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ref: $referenceNumber',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
