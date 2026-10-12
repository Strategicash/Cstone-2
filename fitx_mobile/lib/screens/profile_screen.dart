import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/membership_card.dart';
import '../screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.metrics});

  final UserMetrics metrics;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _displayName;
  late String _email;
  String? _workoutGoals;
  double? _editedWeight;
  double? _editedHeight;
  bool _notificationsEnabled = true;
  String _notificationFrequency = 'Daily';
  String? _avatarSource;

  static const _defaultWorkoutGoals = 'Build strength and stay consistent';

  @override
  void initState() {
    super.initState();
    // Prefer globally persisted edits so re-entering Profile after drawer
    // switches doesn't reset to the stale login payload. UserMetrics is
    // immutable, so AppTheme notifiers are the source of truth after edits.
    _displayName = AppTheme.userDisplayName.value.isNotEmpty
        ? AppTheme.userDisplayName.value
        : (widget.metrics.displayName?.isNotEmpty == true
              ? widget.metrics.displayName!
              : 'User');
    _email = AppTheme.userEmail.value.isNotEmpty
        ? AppTheme.userEmail.value
        : (widget.metrics.email ?? '');
    _workoutGoals = AppTheme.userWorkoutGoals.value.isNotEmpty
        ? AppTheme.userWorkoutGoals.value
        : (widget.metrics.workoutGoals?.isNotEmpty == true
              ? widget.metrics.workoutGoals
              : _defaultWorkoutGoals);
  }

  String _getWeightValue() {
    if (_editedWeight != null) return _editedWeight!.toStringAsFixed(1);
    final w = widget.metrics.weightKg;
    return w != null ? w.toStringAsFixed(1) : '—';
  }

  String _getHeightValue() {
    if (_editedHeight != null) return _editedHeight!.toStringAsFixed(1);
    final h = widget.metrics.heightCm;
    return h != null ? h.toStringAsFixed(1) : '—';
  }

  void _showEditBottomSheet(
    BuildContext context,
    String section,
    String currentValue,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return _EditBottomSheet(
          section: section,
          initialValue: currentValue,
          onSave: (newValue) {
            if (!mounted) return;
            setState(() {
              if (section == 'Personal Info') {
                // Sheet is seeded as "Name\nEmail" — split back on save.
                final lines = newValue
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                String nextName = _displayName;
                String nextEmail = _email;
                if (lines.isNotEmpty) {
                  final emailLine = lines.firstWhere(
                    (l) => l.contains('@'),
                    orElse: () => '',
                  );
                  if (emailLine.isNotEmpty) {
                    nextEmail = emailLine;
                    final nameLines = lines
                        .where((l) => l != emailLine)
                        .toList();
                    if (nameLines.isNotEmpty) {
                      nextName = nameLines.join(' ');
                    }
                  } else {
                    // Single-line edit without email: treat whole text as name
                    // unless it looks like a lone email update.
                    nextName = newValue.isNotEmpty ? newValue : 'User';
                  }
                }
                _displayName = nextName.isNotEmpty ? nextName : 'User';
                _email = nextEmail;
                AppTheme.userDisplayName.value = _displayName;
                AppTheme.userEmail.value = _email;
              } else if (section == 'Weight') {
                _editedWeight = double.tryParse(newValue);
              } else if (section == 'Height') {
                _editedHeight = double.tryParse(newValue);
              } else if (section == 'Workout Goals') {
                _workoutGoals = newValue.isNotEmpty
                    ? newValue
                    : _defaultWorkoutGoals;
                AppTheme.userWorkoutGoals.value = _workoutGoals!;
              }
            });
          },
        );
      },
    ).then((savedValue) {
      // Controller is owned and disposed by [_EditBottomSheetState];
      // nothing to clean up here — just confirm the save.
      if (savedValue == null || savedValue.isEmpty) return;
      if (!mounted) return;
      final display = savedValue.length > 20
          ? '${savedValue.substring(0, 20)}...'
          : savedValue;
      messenger.showSnackBar(
        SnackBar(content: Text('$section updated: $display')),
      );
    });
  }

  void _showWeightBottomSheet() {
    final current = _getWeightValue();
    _showEditBottomSheet(context, 'Weight', current);
  }

  void _showHeightBottomSheet() {
    final current = _getHeightValue();
    _showEditBottomSheet(context, 'Height', current);
  }

  Widget _buildHeader(BuildContext context) {
    final name = _displayName;
    final email = _email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showImagePicker(context),
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person_outline,
                  size: 40,
                  color: AppColors.accent,
                ),
              ),
              Positioned(
                right: -8,
                bottom: -8,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _StatusBadge(label: 'Active Member'),
        if (_avatarSource != null) ...[
          const SizedBox(height: 8),
          Text(
            _avatarSource == 'camera'
                ? 'Photo update via camera queued'
                : 'Photo update via gallery queued',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  void _showImagePicker(
    BuildContext context, {
    ValueChanged<String>? onSourceSelected,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Update profile photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(sheetContext).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Library'),
                onTap: () => Navigator.of(sheetContext).pop('gallery'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).then((source) {
      if (source == null) return;
      onSourceSelected?.call(source);
      if (!mounted) return;
      setState(() => _avatarSource = source);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            source == 'camera'
                ? 'Camera selected — profile photo update queued.'
                : 'Gallery selected — profile photo update queued.',
          ),
        ),
      );
    });
  }

  void _showNotificationPreferencesSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        const options = ['Immediate', 'Daily', 'Weekly', 'Off'];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification preferences',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable notifications'),
                      value: _notificationsEnabled,
                      onChanged: (v) {
                        setSheetState(() {});
                        setState(() => _notificationsEnabled = v);
                      },
                    ),
                    const Divider(height: 1),
                    RadioGroup<String>(
                      groupValue: _notificationFrequency,
                      onChanged: (v) {
                        if (!_notificationsEnabled) return;
                        if (v == null) return;
                        setSheetState(() {});
                        setState(() => _notificationFrequency = v);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in options)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(option),
                              value: option,
                              enabled: _notificationsEnabled,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickMetrics() {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Weight',
            value: _getWeightValue(),
            icon: Icons.monitor_weight_outlined,
            color: AppColors.accent,
            onTap: _showWeightBottomSheet,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Height',
            value: _getHeightValue(),
            icon: Icons.height,
            color: AppColors.accentSecondary,
            onTap: _showHeightBottomSheet,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Workouts',
            value: '${widget.metrics.workoutsTotal ?? 0} Sessions',
            icon: Icons.fitness_center,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipCard() {
    return MembershipCard(metrics: widget.metrics);
  }

  Widget _buildSettingsTiles(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingTile(
          title: 'Personal Info',
          subtitle: _email.isNotEmpty ? '$_displayName\n$_email' : _displayName,
          trailing: Icon(Icons.edit, color: theme.colorScheme.onSurfaceVariant),
          onTap: () => _showEditBottomSheet(
            context,
            'Personal Info',
            _email.isNotEmpty ? '$_displayName\n$_email' : _displayName,
          ),
        ),
        const Divider(height: 1),
        _SettingTile(
          title: 'Workout Goals',
          subtitle: _workoutGoals,
          trailing: Icon(
            Icons.fitness_center,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () => _showEditBottomSheet(
            context,
            'Workout Goals',
            _workoutGoals ?? _defaultWorkoutGoals,
          ),
        ),
        const Divider(height: 1),
        _SettingTile(
          title: 'Notification preferences',
          subtitle: _notificationsEnabled ? _notificationFrequency : 'Off',
          trailing: Switch(
            value: _notificationsEnabled,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
          onTap: _showNotificationPreferencesSheet,
        ),
        const Divider(height: 1),
        _SettingTile(
          title: 'Dark Mode',
          trailing: ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.mode,
            builder: (context, mode, _) {
              final dark = mode == ThemeMode.dark;
              return Switch(
                value: dark,
                activeThumbColor: AppColors.accent,
                onChanged: (v) =>
                    AppTheme.mode.value = v ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
          onTap: () {},
        ),
        const Divider(height: 1),
        _LogOutButton(
          onTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Profile')),
      drawer: AppDrawer(
        metrics: widget.metrics,
        selectedSection: AppSection.profile,
        onSectionSelected: (_) => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildQuickMetrics(),
            const SizedBox(height: 24),
            _buildMembershipCard(),
            const SizedBox(height: 24),
            _buildSettingsTiles(context),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(flex: 1),
              Text(
                'Log Out',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.logout, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet form that owns its [TextEditingController] and disposes it
/// when the sheet is closed, preventing controller leaks.
class _EditBottomSheet extends StatefulWidget {
  const _EditBottomSheet({
    required this.section,
    required this.initialValue,
    required this.onSave,
  });

  final String section;
  final String initialValue;
  final ValueChanged<String> onSave;

  @override
  State<_EditBottomSheet> createState() => _EditBottomSheetState();
}

class _EditBottomSheetState extends State<_EditBottomSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNumeric = widget.section == 'Weight' || widget.section == 'Height';
    final hint = switch (widget.section) {
      'Weight' => 'Enter weight (kg)',
      'Height' => 'Enter height (cm)',
      _ => 'Enter details',
    };
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.section,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: isNumeric
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.multiline,
                maxLines: isNumeric ? 1 : 3,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final newValue = _controller.text.trim();
                    widget.onSave(newValue);
                    Navigator.of(context).pop(newValue);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
