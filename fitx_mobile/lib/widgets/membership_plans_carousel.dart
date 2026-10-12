import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../models/user_metrics.dart';
import '../screens/membership_screen.dart';
import '../theme/app_theme.dart';

/// A membership plan row from `api_get_membership_plans.php`.
class MembershipPlan {
  const MembershipPlan({
    required this.id,
    required this.planName,
    required this.durationDays,
    required this.price,
  });

  final int id;
  final String planName;
  final int durationDays;
  final double price;

  /// Defensive parse: the PHP endpoint casts numerics, but decoded JSON
  /// may still surface them as strings depending on the driver.
  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: _asInt(json['id']),
      planName: json['plan_name']?.toString() ?? 'Plan',
      durationDays: _asInt(json['duration_days']),
      price: _asDouble(json['price']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

/// Formats a peso amount as "₱1,500.00".
String formatPlanPrice(double price) {
  final fixed = price.toStringAsFixed(2);
  final parts = fixed.split('.');
  final withCommas = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₱$withCommas.${parts[1]}';
}

/// Formats a duration as "30 Days Access" / "1 Day Access".
String planDurationLabel(int days) =>
    '$days Day${days == 1 ? '' : 's'} Access';

/// Dynamic membership-plans carousel for the dashboard header.
///
/// Fetches active plans from the backend and renders them as a swipeable
/// [PageView] with a dot indicator. Shows skeleton cards while loading and
/// falls back to a hardcoded plan list when the network is unreachable.
class MembershipPlansCarousel extends StatefulWidget {
  const MembershipPlansCarousel({super.key, this.metrics});

  /// Current session metrics, used only to open [MembershipScreen].
  /// Null-safe: plan browsing and the details sheet work without it.
  final UserMetrics? metrics;

  /// Base URLs live in [ApiClient]; it tries the LAN host first and falls
  /// back to the emulator alias (10.0.2.2) automatically.
  static List<String> get baseUrls => ApiClient.baseUrls;

  /// Kept for backward compatibility; prefer [ApiClient.baseUrls].
  static String get primaryBaseUrl => ApiClient.baseUrls.first;

  /// Kept for backward compatibility; prefer [ApiClient.baseUrls].
  static String get emulatorBaseUrl => ApiClient.baseUrls.last;

  @override
  State<MembershipPlansCarousel> createState() =>
      _MembershipPlansCarouselState();
}

class _MembershipPlansCarouselState extends State<MembershipPlansCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);

  List<MembershipPlan> _plans = const [];
  bool _isLoading = true;
  bool _usingFallback = false;
  int _currentIndex = 0;

  /// Hardcoded fallback shown when the backend is unreachable.
  /// Mirrors the seeded `membership_plans` rows.
  static const List<MembershipPlan> _fallbackPlans = [
    MembershipPlan(id: -1, planName: 'Daily Pass', durationDays: 1, price: 100),
    MembershipPlan(id: -2, planName: 'Weekly', durationDays: 7, price: 500),
    MembershipPlan(
      id: -3,
      planName: 'Monthly',
      durationDays: 30,
      price: 1500,
    ),
    MembershipPlan(id: -4, planName: '3 Months', durationDays: 90, price: 4000),
    MembershipPlan(
      id: -5,
      planName: 'Annual',
      durationDays: 365,
      price: 15000,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<MembershipPlan>?> _getPlans() async {
    final response = await ApiClient.get(
      'api_get_membership_plans.php',
      timeout: const Duration(seconds: 8),
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map || data['success'] != true || data['plans'] is! List) {
      return null;
    }
    final plans = (data['plans'] as List)
        .whereType<Map<String, dynamic>>()
        .map(MembershipPlan.fromJson)
        .toList();
    return plans;
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _usingFallback = false;
    });

    // ApiClient tries each base URL in turn (LAN host, then emulator alias).
    List<MembershipPlan>? plans;
    try {
      plans = await _getPlans();
      if (plans != null && plans.isEmpty) plans = null;
    } catch (_) {
      plans = null;
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
      _currentIndex = 0;
    });
  }

  /// "1500" -> "₱1,500.00"
  static String formatPrice(double price) => formatPlanPrice(price);

  static String durationLabel(int days) => planDurationLabel(days);

  void _openMembershipScreen() {
    final metrics = widget.metrics;
    if (metrics == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MembershipScreen(metrics: metrics)),
    );
  }

  void _showPlanDetails(MembershipPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final perDay = plan.durationDays > 0
            ? plan.price / plan.durationDays
            : plan.price;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent,
                          AppColors.accentSecondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.card_membership,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          durationLabel(plan.durationDays),
                          style: Theme.of(sheetContext).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price'),
                  Text(
                    formatPrice(plan.price),
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Per day'),
                  Text(formatPrice(perDay)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.metrics == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          _openMembershipScreen();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Select Plan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Membership Plans',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!_isLoading && widget.metrics != null)
              TextButton(
                onPressed: _openMembershipScreen,
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const _CarouselLoading()
        else ...[
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _plans.length,
              onPageChanged: (index) =>
                  setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _plans.length - 1 ? 0 : 8,
                  ),
                  child: _PlanCard(
                    plan: plan,
                    onSelect: () => _showPlanDetails(plan),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_plans.length, (index) {
                final selected = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          if (_usingFallback) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Offline — showing cached plans',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _fetchPlans,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Single swipeable plan card in the brand orange gradient.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onSelect});

  final MembershipPlan plan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentSecondary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_membership,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FITX MEMBERSHIP',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  planDurationLabel(plan.durationDays),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            plan.planName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  formatPlanPrice(plan.price),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton(
                onPressed: onSelect,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Select Plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder shown while plans are loading.
class _CarouselLoading extends StatelessWidget {
  const _CarouselLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.grey[200]!;
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
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
                  const Spacer(),
                  Container(
                    height: 22,
                    width: 140,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 28,
                    width: 110,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
