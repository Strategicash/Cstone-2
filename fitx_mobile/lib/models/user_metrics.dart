/// Defensive, schema-agnostic fitness metric model. Every field is optional.
/// Parses the login payload (`api_login.php`) and tolerates missing/null
/// values and common key-name variations without ever throwing.
class UserMetrics {
  const UserMetrics({
    this.displayName,
    this.firstName,
    this.lastName,
    this.email,
    this.photoUrl,
    this.userId,
    this.goals = const [],
    this.workoutGoals,
    this.workoutsThisWeek,
    this.workoutsTotal,
    this.streakDays,
    this.bodyFat,
    this.weightKg,
    this.heightCm,
    this.memberSince,
    this.membershipType,
    this.membershipStatus,
    this.membershipValidity,
    this.membershipStart,
    this.membershipEnd,
    this.lastVisit,
    this.daysUntilPaymentDue,
  });

  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? photoUrl;
  final int? userId;
  final List<Goal> goals;
  final String? workoutGoals;
  final int? workoutsThisWeek;
  final int? workoutsTotal;
  final int? streakDays;
  final double? bodyFat;
  final double? weightKg;
  final double? heightCm;
  final String? memberSince;
  final String? membershipType;
  final String? lastVisit;
  final int? daysUntilPaymentDue;

  /// e.g. "Active", "Expired", "Pending".
  final String? membershipStatus;

  /// e.g. "1 Year", "Monthly".
  final String? membershipValidity;

  /// Raw date strings as returned by the backend (anything parseable).
  final String? membershipStart;
  final String? membershipEnd;

  /// The membership end date, parsed defensively. Null when unparseable.
  DateTime? get membershipEndDate => parseFlexibleDate(membershipEnd);

  /// Days left on the membership as of now (inclusive of the end date).
  /// Null when no end date is available. Negative values mean expired.
  int? get membershipDaysRemaining {
    final end = membershipEndDate;
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays + 1;
  }

  /// Returns a copy with the given fields replaced. Since [UserMetrics] is
  /// immutable, profile edits use this (or the global [ValueNotifier] store)
  /// instead of mutating in place.
  UserMetrics copyWith({
    String? displayName,
    String? firstName,
    String? lastName,
    String? email,
    String? photoUrl,
    int? userId,
    List<Goal>? goals,
    String? workoutGoals,
    int? workoutsThisWeek,
    int? workoutsTotal,
    int? streakDays,
    double? bodyFat,
    double? weightKg,
    double? heightCm,
    String? memberSince,
    String? membershipType,
    String? membershipStatus,
    String? membershipValidity,
    String? membershipStart,
    String? membershipEnd,
    String? lastVisit,
    int? daysUntilPaymentDue,
  }) {
    return UserMetrics(
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      userId: userId ?? this.userId,
      goals: goals ?? this.goals,
      workoutGoals: workoutGoals ?? this.workoutGoals,
      workoutsThisWeek: workoutsThisWeek ?? this.workoutsThisWeek,
      workoutsTotal: workoutsTotal ?? this.workoutsTotal,
      streakDays: streakDays ?? this.streakDays,
      bodyFat: bodyFat ?? this.bodyFat,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      memberSince: memberSince ?? this.memberSince,
      membershipType: membershipType ?? this.membershipType,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      membershipValidity: membershipValidity ?? this.membershipValidity,
      membershipStart: membershipStart ?? this.membershipStart,
      membershipEnd: membershipEnd ?? this.membershipEnd,
      lastVisit: lastVisit ?? this.lastVisit,
      daysUntilPaymentDue: daysUntilPaymentDue ?? this.daysUntilPaymentDue,
    );
  }

  /// Parses a raw login payload, unwrapping common user wrappers
  /// (`user`, `data`, `member`, `profile`, `client`) before reading metrics.
  factory UserMetrics.fromLoginPayload(Map<String, dynamic>? payload) {
    if (payload == null) return const UserMetrics();
    for (final key in const ['user', 'data', 'member', 'profile', 'client']) {
      final value = payload[key];
      if (value is Map) {
        return UserMetrics.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return UserMetrics.fromJson(payload);
  }

  /// Extracts metrics from any JSON map, tolerating missing/null/unknown
  /// fields and common naming variations. Never throws on malformed input.
  factory UserMetrics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserMetrics();

    final name = _firstString(json, const [
      'display_name',
      'displayName',
      'full_name',
      'fullName',
      'name',
    ]);
    final first = _firstString(json, const [
      'first_name',
      'firstName',
      'firstname',
      'fname',
    ]);
    final last = _firstString(json, const [
      'last_name',
      'lastName',
      'lastname',
      'lname',
    ]);
    final parsedGoals = parseGoals(json);

    return UserMetrics(
      displayName:
          name ?? (first != null && last != null ? '$first $last' : ''),
      firstName: first ?? '',
      lastName: last ?? '',
      email: _firstString(json, const ['email', 'email_address', 'mail']) ?? '',
      photoUrl: _firstString(json, const [
        'photo_url',
        'photoUrl',
        'avatar',
        'avatar_url',
        'profile_image',
        'profileImage',
        'picture',
      ]),
      userId: _firstInt(json, const [
        'user_id',
        'userId',
        'id',
        'member_id',
        'memberId',
      ]),
      goals: parsedGoals,
      workoutGoals:
          _firstString(json, const [
            'workout_goals',
            'workoutGoals',
            'workout_goal',
            'fitness_goal',
            'goal_text',
          ]) ??
          (parsedGoals.isNotEmpty
              ? parsedGoals
                    .map((g) => g.title)
                    .whereType<String>()
                    .where((t) => t.trim().isNotEmpty)
                    .join(', ')
              : null),
      workoutsThisWeek:
          _firstInt(json, const [
            'workouts_this_week',
            'workoutsThisWeek',
            'weekly_workouts',
            'sessions_week',
          ]) ??
          0,
      workoutsTotal:
          _firstInt(json, const [
            'total_workouts',
            'workoutsTotal',
            'workouts',
            'sessions_total',
            'completed_workouts',
          ]) ??
          0,
      streakDays:
          _firstInt(json, const [
            'streak_days',
            'streakDays',
            'streak',
            'day_streak',
          ]) ??
          0,
      bodyFat:
          _firstDouble(json, const [
            'body_fat',
            'bodyFat',
            'body_fat_percent',
            'fat_percent',
          ]) ??
          0.0,
      weightKg:
          _firstDouble(json, const [
            'weight_kg',
            'weightKg',
            'weight',
            'body_weight',
          ]) ??
          0.0,
      heightCm:
          _firstDouble(json, const ['height_cm', 'heightCm', 'height']) ?? 0.0,
      memberSince:
          _firstString(json, const [
            'member_since',
            'memberSince',
            'joined',
            'joined_at',
            'created_at',
          ]) ??
          '',
      membershipType:
          _firstString(json, const [
            'membership',
            'membership_type',
            'membershipType',
            'plan',
            'tier',
          ]) ??
          '',
      membershipStatus:
          _firstString(json, const [
            'membership_status',
            'membershipStatus',
            'status',
            'plan_status',
            'account_status',
          ]) ??
          '',
      membershipValidity:
          _firstString(json, const [
            'membership_validity',
            'membershipValidity',
            'validity',
            'membership_period',
            'duration',
          ]) ??
          '',
      membershipStart:
          _firstString(json, const [
            'membership_start',
            'membershipStart',
            'membership_start_date',
            'plan_start',
            'start_date',
            'valid_from',
          ]) ??
          '',
      membershipEnd:
          _firstString(json, const [
            'membership_end',
            'membershipEnd',
            'membership_end_date',
            'plan_end',
            'end_date',
            'expiry',
            'expires_at',
            'valid_until',
          ]) ??
          '',
      lastVisit:
          _firstString(json, const [
            'last_visit',
            'lastVisit',
            'last_checked_in',
            'last_login',
            'last_access',
          ]) ??
          '',
      daysUntilPaymentDue: _firstInt(json, const [
        'days_until_payment',
        'daysUntilPaymentDue',
        'payment_due_days',
      ]),
    );
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static double? _firstDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Parses `goals`/`fitness_goals`/`objectives` from the payload. Accepts a
  /// list of strings, a list of maps (`{title, progress}`), or a map of
  /// `{goalTitle: progress}`.
  static List<Goal> parseGoals(Map<String, dynamic> json) {
    final raw = json['goals'] ?? json['fitness_goals'] ?? json['objectives'];
    if (raw is List) {
      return raw
          .whereType<Object>()
          .map((e) {
            if (e is String) return Goal(title: e);
            if (e is Map) {
              final map = e.map((k, v) => MapEntry(k.toString(), v));
              return Goal(
                title: _firstString(map, const [
                  'title',
                  'name',
                  'goal',
                  'label',
                ]),
                progress: _firstDouble(map, const [
                  'progress',
                  'percent',
                  'progress_percent',
                ]),
              );
            }
            return null;
          })
          .whereType<Goal>()
          .toList();
    }
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return map.entries
          .map(
            (e) => Goal(
              title: e.key,
              progress: e.value is num ? (e.value as num).toDouble() : null,
            ),
          )
          .toList();
    }
    return const [];
  }
}

class Goal {
  const Goal({this.title, this.progress});

  final String? title;
  final double? progress; // 0..100
}

/// Parses a date string defensively. Accepts full ISO timestamps such as
/// `2026-08-01 00:00:00` (trims the time part) and plain `YYYY-MM-DD`.
/// Returns null for anything unparseable.
DateTime? parseFlexibleDate(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final datePart = trimmed.split(RegExp(r'\s+')).first;
  return DateTime.tryParse(datePart);
}
