import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import '../theme/app_theme.dart';

import 'package:fitx_mobile/screens/profile_screen.dart';
import 'package:fitx_mobile/screens/nutrition_plan_screen.dart';
import 'package:fitx_mobile/screens/check_in_history_screen.dart';
import 'package:fitx_mobile/screens/membership_screen.dart';
import 'package:fitx_mobile/screens/payments_screen.dart';
import 'package:fitx_mobile/screens/login_screen.dart';

/// Top-level app sections reachable from the sidebar.
enum AppSection {
  dashboard,
  workouts,
  progress,
  bodyMetrics,
  profile,
  nutritionPlan,
  checkInHistory,
  logOut,
  payments,
  membership,
}

/// Responsive sidebar navigation. Used both as a Scaffold drawer (narrow
/// screens) and as a fixed side panel (wide screens); set
/// [automaticallyClose] to false when embedding it inline.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.metrics,
    required this.selectedSection,
    required this.onSectionSelected,
    this.automaticallyClose = true,
    this.loginData,
  });

  final UserMetrics metrics;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final bool automaticallyClose;
  final Map<String, dynamic>? loginData;

  void _handleSelect(BuildContext context, AppSection section) {
    // Merge globally edited profile fields so pushed routes never see a
    // stale login payload after a Profile save.
    final syncedMetrics = metrics.copyWith(
      displayName: AppTheme.userDisplayName.value.isNotEmpty
          ? AppTheme.userDisplayName.value
          : metrics.displayName,
      email: AppTheme.userEmail.value.isNotEmpty
          ? AppTheme.userEmail.value
          : metrics.email,
      workoutGoals: AppTheme.userWorkoutGoals.value.isNotEmpty
          ? AppTheme.userWorkoutGoals.value
          : metrics.workoutGoals,
    );
    if (section == AppSection.profile) {
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(metrics: syncedMetrics),
        ),
      );
    } else if (section == AppSection.logOut) {
      _showLogoutConfirmation(context);
    } else if (section == AppSection.nutritionPlan) {
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NutritionPlanScreen(memberId: metrics.userId ?? 0),
        ),
      );
    } else if (section == AppSection.checkInHistory) {
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CheckInHistoryScreen(
            loginData: loginData,
            userId: metrics.userId,
          ),
        ),
      );
    } else if (section == AppSection.payments) {
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PaymentsScreen(userId: metrics.userId ?? 0),
        ),
      );
    } else if (section == AppSection.membership) {
      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => MembershipScreen(metrics: syncedMetrics),
        ),
      );
    } else {
      onSectionSelected(section);
      if (automaticallyClose) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      }
    }
  }

  void _showLogoutConfirmation(BuildContext context) {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              navigator.pop();
              // Drop the session identity so the next login cannot inherit
              // the previous user's name/email from these process-static
              // notifiers (HomeScreen re-seeds them on every login).
              AppTheme.userDisplayName.value = '';
              AppTheme.userEmail.value = '';
              AppTheme.userWorkoutGoals.value = '';
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Drawer mode (Scaffold drawer): standard 78%-width panel with rounded
    // right corners. Embedded mode (wide side panel, automaticallyClose:
    // false) keeps filling its parent with square corners.
    if (automaticallyClose) {
      const radius = BorderRadius.horizontal(right: Radius.circular(20));
      return Drawer(
        width: MediaQuery.of(context).size.width * 0.78,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        child: ClipRRect(
          borderRadius: radius,
          child: _buildBody(context),
        ),
      );
    }

    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final surface = Theme.of(context).cardTheme.color ?? AppColors.card;

    return Material(
      color: surface,
      child: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(metrics: metrics),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const _GroupLabel('MAIN'),
                  for (final item in _mainItems)
                    _NavTile(
                      item: item,
                      selected: selectedSection == item.section,
                      onTap: () => _handleSelect(context, item.section),
                    ),
                  const _GroupLabel('SERVICES'),
                  for (final item in _servicesItems)
                    _NavTile(
                      item: item,
                      selected: selectedSection == item.section,
                      onTap: () => _handleSelect(context, item.section),
                    ),
                  const _GroupLabel('ACCOUNT'),
                  for (final item in _accountItems) ...[
                    if (item.isDestructive)
                      const Divider(height: 24, indent: 24, endIndent: 24),
                    _NavTile(
                      item: item,
                      selected: selectedSection == item.section,
                      onTap: () => _handleSelect(context, item.section),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const _ThemeSwitch(),
          ],
        ),
      ),
    );
  }

  static const _mainItems = [
    _NavItem(
      section: AppSection.dashboard,
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _NavItem(
      section: AppSection.workouts,
      label: 'Workouts',
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
    ),
    _NavItem(
      section: AppSection.progress,
      label: 'Progress',
      icon: Icons.trending_up,
      selectedIcon: Icons.trending_up,
    ),
    _NavItem(
      section: AppSection.bodyMetrics,
      label: 'Body Metrics',
      icon: Icons.accessibility_new,
      selectedIcon: Icons.accessibility_new,
    ),
    _NavItem(
      section: AppSection.nutritionPlan,
      label: 'Nutrition Plan',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
    ),
    _NavItem(
      section: AppSection.checkInHistory,
      label: 'Check-in History',
      icon: Icons.access_time_outlined,
      selectedIcon: Icons.access_time,
    ),
  ];

  static const _servicesItems = [
    _NavItem(
      section: AppSection.membership,
      label: 'Membership',
      icon: Icons.card_membership_outlined,
      selectedIcon: Icons.card_membership,
    ),
    _NavItem(
      section: AppSection.payments,
      label: 'Payments',
      icon: Icons.payment_outlined,
      selectedIcon: Icons.payment,
    ),
  ];

  static const _accountItems = [
    _NavItem(
      section: AppSection.profile,
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
    _NavItem(
      section: AppSection.logOut,
      label: 'Log Out',
      icon: Icons.logout_outlined,
      selectedIcon: Icons.logout,
      isDestructive: true,
    ),
  ];
}

class _NavItem {
  const _NavItem({
    required this.section,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.isDestructive = false,
  });

  final AppSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isDestructive;
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: item.isDestructive
                      ? Colors.red
                      : selected
                      ? AppColors.accent
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.isDestructive
                          ? Colors.red
                          : selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.metrics});

  final UserMetrics metrics;

  @override
  Widget build(BuildContext context) {
    // Listen to global profile edits so drawer instantly reflects Profile
    // saves across all links and screen switches.
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppTheme.userDisplayName,
        AppTheme.userEmail,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        // Dynamic session identity only: global profile edits first, then
        // the login payload. Missing names fall back to the actual email
        // prefix, then to '' — never to another person's details.
        final email = AppTheme.userEmail.value.isNotEmpty
            ? AppTheme.userEmail.value
            : (metrics.email ?? '');
        var name = AppTheme.userDisplayName.value;
        if (name.isEmpty) name = metrics.displayName ?? '';
        if (name.isEmpty) name = _emailPrefix(email);
        final status = metrics.membershipStatus ?? 'Active Member';
        final photoUrl = metrics.photoUrl;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Row(
            children: [
              if (photoUrl != null && photoUrl.isNotEmpty)
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent,
                  backgroundImage: NetworkImage(photoUrl),
                  onBackgroundImageError: (_, _) {},
                )
              else
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),
                    _StatusBadge(label: status),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
  }

  /// Email prefix (`kokoy` from `kokoy@gmail.com`) for display-name fallback.
  static String _emailPrefix(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return '';
    return email.substring(0, at);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final isExpired = lower.contains('expir') || lower.contains('inactive');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: 0.15)
            : AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isExpired ? Colors.red : AppColors.accent,
        ),
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: Icon(
            dark ? Icons.dark_mode : Icons.light_mode_outlined,
            color: AppColors.accent,
          ),
          title: const Text('Dark Mode'),
          value: dark,
          onChanged: (v) =>
              AppTheme.mode.value = v ? ThemeMode.dark : ThemeMode.light,
        );
      },
    );
  }
}
