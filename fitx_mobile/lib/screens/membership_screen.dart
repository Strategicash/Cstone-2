import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user_metrics.dart';
import '../theme/app_theme.dart';
import '../widgets/membership_card.dart';
import '../widgets/membership_plans_carousel.dart';
import '../widgets/renewal_reminder_banner.dart';
import '../widgets/submit_payment_sheet.dart';
import 'payments_screen.dart';

/// Membership & Rates page — current membership summary on top,
/// list of available plans below.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key, required this.metrics});

  final UserMetrics metrics;

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  List<MembershipPlan> _plans = const [];
  bool _isLoading = true;
  bool _usingFallback = false;

  /// Local default rates shown when the device is offline or the backend is unreachable.
  static const List<MembershipPlan> _fallbackPlans = [
    MembershipPlan(id: -1, planName: 'Daily Pass', durationDays: 1, price: 100),
    MembershipPlan(id: -2, planName: 'Weekly', durationDays: 7, price: 500),
    MembershipPlan(id: -3, planName: 'Monthly', durationDays: 30, price: 1500),
    MembershipPlan(id: -4, planName: '3 Months', durationDays: 90, price: 4000),
    MembershipPlan(id: -5, planName: 'Annual', durationDays: 365, price: 15000),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<List<MembershipPlan>?> _getPlans(String baseUrl) async {
    final uri = Uri.parse('$baseUrl/api_get_membership_plans.php');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map || data['success'] != true || data['plans'] is! List) {
      return null;
    }
    return (data['plans'] as List)
        .whereType<Map<String, dynamic>>()
        .map(MembershipPlan.fromJson)
        .toList();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _usingFallback = false;
    });

    List<MembershipPlan>? plans;
    for (final baseUrl in [
      MembershipPlansCarousel.primaryBaseUrl,
      MembershipPlansCarousel.emulatorBaseUrl,
    ]) {
      try {
        plans = await _getPlans(baseUrl);
        if (plans != null && plans.isNotEmpty) break;
        plans = null;
      } catch (_) {
        plans = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (plans != null && plans.isNotEmpty) {
        _plans = plans;
        _usingFallback = false;
      } else {
        _plans = _fallbackPlans;
        _usingFallback = true;
      }
    });
  }

  void _openPayments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PaymentsScreen(userId: widget.metrics.userId ?? 0),
      ),
    );
  }

  /// Opens checkout directly over this screen with the plan pre-filled.
  /// No navigation — PaymentsScreen stays strictly a history view.
  void _choosePlan(MembershipPlan plan) {
    showSubmitPaymentSheet(
      context,
      userId: widget.metrics.userId ?? 0,
      selectedPlan: plan,
      onSaved: _fetchPlans,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: RefreshIndicator(
        onRefresh: _fetchPlans,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Active membership summary.
            RenewalReminderBanner(metrics: widget.metrics),
            MembershipCard(metrics: widget.metrics),
            const SizedBox(height: 12),

            // 2. Payments history button.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openPayments(),
                icon: const Icon(Icons.payment_outlined),
                label: const Text('View Payments History'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Plans & rates header.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Membership Plans & Rates',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_usingFallback && !_isLoading)
                  TextButton.icon(
                    onPressed: _fetchPlans,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.wifi_off_outlined, size: 14),
                    label: const Text('Retry'),
                  ),
              ],
            ),
            if (_usingFallback && !_isLoading) ...[
              const SizedBox(height: 4),
              Text(
                'Offline — showing cached rates',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // 4. Dynamic plan list.
            if (_isLoading)
              ...List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _PlanCardSkeleton(),
                ),
              )
            else
              ..._plans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlanRateCard(
                    plan: plan,
                    onChoose: () => _choosePlan(plan),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple vertical plan/rate card.
class _PlanRateCard extends StatelessWidget {
  const _PlanRateCard({required this.plan, required this.onChoose});

  final MembershipPlan plan;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.planName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatPlanPrice(plan.price),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ ${plan.durationDays} day${plan.durationDays == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onChoose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Choose Plan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder shown while plans are loading.
class _PlanCardSkeleton extends StatelessWidget {
  const _PlanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[200]!;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading plans…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            bar(140, 22),
            const SizedBox(height: 8),
            bar(110, 28),
          ],
        ),
      ),
    );
  }
}
