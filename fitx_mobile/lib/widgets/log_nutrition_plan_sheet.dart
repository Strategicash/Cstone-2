import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';

Future<void> showLogNutritionPlanSheet(
  BuildContext context, {
  required int memberId,
  Map<String, dynamic>? previousValues,
  VoidCallback? onSaved,
}) async {
  final planNameController = TextEditingController(
    text: previousValues?['plan_name']?.toString() ?? 'My Nutrition Plan',
  );
  final dailyCaloriesController = TextEditingController(
    text: previousValues?['daily_calories']?.toString() ?? '',
  );
  final proteinController = TextEditingController(
    text: previousValues?['protein_g']?.toString() ?? '',
  );
  final carbsController = TextEditingController(
    text: previousValues?['carbs_g']?.toString() ?? '',
  );
  final fatsController = TextEditingController(
    text: previousValues?['fats_g']?.toString() ?? '',
  );
  final mealsPerDayController = TextEditingController(
    text: previousValues?['meals_per_day']?.toString() ?? '3',
  );
  final notesController = TextEditingController(
    text: previousValues?['notes']?.toString() ?? '',
  );
  final goalWeightController = TextEditingController(
    text: previousValues?['goal_weight_kg']?.toString() ?? '',
  );

  // Canonical goal options — every value must be unique, otherwise
  // DropdownButton throws "There should be exactly one item with
  // [DropdownButton]'s value". Do not add duplicates (e.g. two entries
  // both set to "Lose Weight / Cut").
  final goals = [
    'Weight Loss',
    'Muscle Gain',
    'Maintenance',
    'Body Recomposition',
  ];
  assert(
    goals.toSet().length == goals.length,
    'Duplicate goal dropdown option detected',
  );

  // Normalize the stored value so it matches one option character-for-
  // character (trims leading/trailing whitespace, collapses inconsistent
  // spacing around '/'), mapping legacy backend values such as
  // "Lose Weight / Cut", "Lose Weight", or "Cut" to their canonical option.
  String normalizeGoal(dynamic raw) {
    final trimmed = raw?.toString().trim() ?? '';
    if (trimmed.isEmpty) return 'Maintenance';
    if (goals.contains(trimmed)) return trimmed;
    final collapsed = trimmed
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*/\s*'), ' / ')
        .trim();
    if (goals.contains(collapsed)) return collapsed;
    for (final option in goals) {
      if (option.toLowerCase() == collapsed.toLowerCase()) return option;
    }
    final lower = collapsed.toLowerCase();
    if (lower.contains('lose weight') ||
        lower == 'cut' ||
        lower == 'weight loss') {
      return 'Weight Loss';
    }
    if (lower.contains('muscle') ||
        lower.contains('bulk') ||
        lower.contains('gain')) {
      return 'Muscle Gain';
    }
    if (lower.contains('recomp')) return 'Body Recomposition';
    if (lower.contains('maint')) return 'Maintenance';
    // Unknown value: fall back so the dropdown always has exactly one match.
    return 'Maintenance';
  }

  String selectedGoal = normalizeGoal(previousValues?['goal']);
  String? errorMessage;
  bool isLoading = false;

  int calculateMacroCalories() {
    final protein = double.tryParse(proteinController.text) ?? 0;
    final carbs = double.tryParse(carbsController.text) ?? 0;
    final fats = double.tryParse(fatsController.text) ?? 0;
    return (protein * 4 + carbs * 4 + fats * 9).round();
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.close, size: 24, color: AppColors.text),
              ),
              const SizedBox(height: 8),
              const Text(
                'Log Nutrition Plan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Fill in your nutrition plan details below.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Plan Name
              _FormFieldLabel(text: 'Plan Name *', icon: Icons.edit_outlined),
              TextField(
                controller: planNameController,
                decoration: InputDecoration(
                  hintText: 'e.g. My Nutrition Plan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Goal
              _FormFieldLabel(text: 'Goal *', icon: Icons.flag_outlined),
              DropdownButtonFormField<String>(
                // Defensive: never pass a value with zero (or 2+) matches.
                value: goals.contains(selectedGoal)
                    ? selectedGoal
                    : 'Maintenance',
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: goals.map((goal) {
                  return DropdownMenuItem(value: goal, child: Text(goal));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => selectedGoal = value);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Goal Weight
              _FormFieldLabel(
                text: 'Goal Weight (kg)',
                icon: Icons.monitor_weight_outlined,
              ),
              TextField(
                controller: goalWeightController,
                decoration: InputDecoration(
                  hintText: 'e.g. 70',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'kg ',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 20),

              // Macros Group Card
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_outlined,
                            size: 20,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Daily Targets',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Daily Calories
                      _FormFieldLabel(
                        text: 'Daily Calories *',
                        icon: Icons.local_fire_department_outlined,
                      ),
                      TextField(
                        controller: dailyCaloriesController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 2000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixText: 'kcal ',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),

                      // Protein (g)
                      _FormFieldLabel(
                        text: 'Protein (g) *',
                        icon: Icons.egg_outlined,
                      ),
                      TextField(
                        controller: proteinController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 150',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixText: 'g ',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Carbs (g)
                      _FormFieldLabel(text: 'Carbs (g) *', icon: Icons.grain_outlined),
                      TextField(
                        controller: carbsController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 200',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixText: 'g ',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Fats (g)
                      _FormFieldLabel(text: 'Fats (g) *', icon: Icons.opacity_outlined),
                      TextField(
                        controller: fatsController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 70',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixText: 'g ',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),

                      // Live Macro Summary
                      Builder(
                        builder: (context) {
                          final macroCalories = calculateMacroCalories();
                          final targetCalories =
                              int.tryParse(dailyCaloriesController.text);
                          final diff = targetCalories != null
                              ? macroCalories - targetCalories
                              : null;
                          final isOver = diff != null && diff > 0;
                          return Row(
                            children: [
                              Icon(
                                Icons.calculate_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Macros total: ${macroCalories} kcal',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              if (diff != null) ...[
                                const SizedBox(width: 12),
                                Text(
                                  diff == 0
                                      ? '✓ Matches target'
                                      : '${isOver ? '+' : ''}$diff kcal vs target',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: diff == 0
                                            ? Colors.green
                                            : (isOver
                                                ? Colors.orange
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant),
                                      ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Meals per Day
              _FormFieldLabel(
                text: 'Meals per Day *',
                icon: Icons.restaurant_outlined,
              ),
              TextField(
                controller: mealsPerDayController,
                decoration: InputDecoration(
                  hintText: 'e.g. 3',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              // Notes
              _FormFieldLabel(text: 'Notes (optional)', icon: Icons.note_outlined),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'Any additional notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // Error message
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Save button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setModalState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            try {
                              final response = await ApiClient.post(
                                'api_save_nutrition_plan.php',
                                {
                                  'member_id': memberId,
                                  'plan_name': planNameController.text.trim(),
                                  'goal': selectedGoal,
                                  'goal_weight_kg': double.tryParse(
                                    goalWeightController.text,
                                  ),
                                  'daily_calories':
                                      int.tryParse(dailyCaloriesController.text),
                                  'protein_g': double.tryParse(proteinController.text),
                                  'carbs_g': double.tryParse(carbsController.text),
                                  'fats_g': double.tryParse(fatsController.text),
                                  'meals_per_day':
                                      int.tryParse(mealsPerDayController.text),
                                  'notes': notesController.text.trim().isEmpty
                                      ? null
                                      : notesController.text.trim(),
                                },
                              );

                              final data = jsonDecode(response.body);

                              if (!context.mounted) return;

                              if (data['success'] == true) {
                                Navigator.of(context).pop();
                                onSaved?.call();
                              } else {
                                setModalState(() {
                                  isLoading = false;
                                  errorMessage =
                                      data['message'] ??
                                      'Failed to save nutrition plan';
                                });
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              setModalState(() {
                                isLoading = false;
                                errorMessage = 'Could not connect to server';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      foregroundColor: Colors.white,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Save Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FormFieldLabel extends StatelessWidget {
  const _FormFieldLabel({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}