import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';

enum WorkoutType { strength, cardio }

class ExerciseOption {
  final String name;
  final String muscleGroup;
  final WorkoutType type;
  const ExerciseOption(this.name, this.muscleGroup, this.type);
}

const _exerciseOptions = [
  ExerciseOption('Bench Press', 'Chest', WorkoutType.strength),
  ExerciseOption('Incline Bench Press', 'Chest', WorkoutType.strength),
  ExerciseOption('Push Up', 'Chest', WorkoutType.strength),
  ExerciseOption('Chest Fly', 'Chest', WorkoutType.strength),
  ExerciseOption('Squat', 'Legs', WorkoutType.strength),
  ExerciseOption('Leg Press', 'Legs', WorkoutType.strength),
  ExerciseOption('Lunges', 'Legs', WorkoutType.strength),
  ExerciseOption('Calf Raise', 'Legs', WorkoutType.strength),
  ExerciseOption('Deadlift', 'Back', WorkoutType.strength),
  ExerciseOption('Lat Pulldown', 'Back', WorkoutType.strength),
  ExerciseOption('Pull Up', 'Back', WorkoutType.strength),
  ExerciseOption('Bent Over Row', 'Back', WorkoutType.strength),
  ExerciseOption('Shoulder Press', 'Shoulders', WorkoutType.strength),
  ExerciseOption('Lateral Raise', 'Shoulders', WorkoutType.strength),
  ExerciseOption('Front Raise', 'Shoulders', WorkoutType.strength),
  ExerciseOption('Bicep Curl', 'Arms', WorkoutType.strength),
  ExerciseOption('Tricep Extension', 'Arms', WorkoutType.strength),
  ExerciseOption('Hammer Curl', 'Arms', WorkoutType.strength),
  ExerciseOption('Plank', 'Core', WorkoutType.strength),
  ExerciseOption('Sit Up', 'Core', WorkoutType.strength),
  ExerciseOption('Crunches', 'Core', WorkoutType.strength),
  ExerciseOption('Russian Twist', 'Core', WorkoutType.strength),
  ExerciseOption('Running', 'Cardio', WorkoutType.cardio),
  ExerciseOption('Treadmill', 'Cardio', WorkoutType.cardio),
  ExerciseOption('Cycling', 'Cardio', WorkoutType.cardio),
  ExerciseOption('Jump Rope', 'Cardio', WorkoutType.cardio),
  ExerciseOption('Rowing Machine', 'Cardio', WorkoutType.cardio),
  ExerciseOption('Elliptical', 'Cardio', WorkoutType.cardio),
  ExerciseOption(
    'Other',
    'Other',
    WorkoutType.strength,
  ), // special case, handled below
];

const _muscleGroupOptions = [
  'Chest',
  'Back',
  'Legs',
  'Arms',
  'Shoulders',
  'Core',
  'Full Body',
  'Other',
];

Future<void> showLogWorkoutSheet(
  BuildContext context, {
  required int userId,
  VoidCallback? onSaved,
}) async {
  final customExerciseController = TextEditingController();
  final setsController = TextEditingController(text: '1');
  final repsController = TextEditingController(text: '10');
  final weightController = TextEditingController(text: '0');
  final durationController = TextEditingController();
  ExerciseOption? selectedExercise;
  String? selectedMuscleGroup;
  String? errorMessage;
  bool isLoading = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final isOther = selectedExercise?.name == 'Other';
        final isCardio =
            selectedExercise != null &&
            !isOther &&
            selectedExercise!.type == WorkoutType.cardio;

        return Padding(
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
                const SizedBox(height: 12),
                const Text(
                  'Log Workout',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 20),

                // Exercise dropdown
                _FormFieldLabel(text: 'Exercise'),
                DropdownButtonFormField<ExerciseOption>(
                  initialValue: selectedExercise,
                  decoration: InputDecoration(
                    hintText: 'Select exercise',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: _exerciseOptions.map((option) {
                    return DropdownMenuItem<ExerciseOption>(
                      value: option,
                      child: Text(option.name),
                    );
                  }).toList(),
                  onChanged: (ExerciseOption? value) {
                    setModalState(() {
                      selectedExercise = value;
                      if (value != null && value.name != 'Other') {
                        selectedMuscleGroup = value.muscleGroup;
                      } else {
                        // "Other" (or cleared): require a manual muscle-group pick.
                        selectedMuscleGroup = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Auto-derived muscle group (read-only) for known exercises.
                if (selectedExercise != null && !isOther)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text('Target: ${selectedExercise!.muscleGroup}'),
                    ),
                  ),
                if (selectedExercise != null && !isOther)
                  const SizedBox(height: 4),

                // Custom exercise name + manual muscle group for "Other".
                if (isOther) ...[
                  const SizedBox(height: 12),
                  _FormFieldLabel(text: 'Custom Exercise'),
                  TextField(
                    controller: customExerciseController,
                    decoration: InputDecoration(
                      hintText: 'Enter exercise name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormFieldLabel(text: 'Muscle Group'),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMuscleGroup,
                    decoration: InputDecoration(
                      hintText: 'Select muscle group',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: _muscleGroupOptions.map((String group) {
                      return DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setModalState(() => selectedMuscleGroup = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a muscle group';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 12),

                if (isCardio) ...[
                  // Duration (cardio only)
                  _FormFieldLabel(text: 'Duration (minutes)'),
                  TextField(
                    controller: durationController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 30',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Sets
                  _FormFieldLabel(text: 'Sets'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsController,
                          decoration: InputDecoration(
                            hintText: '1',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sets',
                        style: TextStyle(fontSize: 12, color: AppColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reps
                  _FormFieldLabel(text: 'Reps'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: repsController,
                          decoration: InputDecoration(
                            hintText: '10',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Reps',
                        style: TextStyle(fontSize: 12, color: AppColors.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weight in kg
                  _FormFieldLabel(text: 'Weight (kg)'),
                  TextField(
                    controller: weightController,
                    decoration: InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      prefixText: 'kg ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                ],

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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (selectedExercise == null) {
                              setModalState(
                                () =>
                                    errorMessage = 'Please select an exercise',
                              );
                              return;
                            }

                            final bool isOtherSelected =
                                selectedExercise!.name == 'Other';
                            final bool isCardioSelected =
                                !isOtherSelected &&
                                selectedExercise!.type == WorkoutType.cardio;

                            final String finalExercise;
                            if (isOtherSelected) {
                              finalExercise = customExerciseController.text
                                  .trim();
                              if (finalExercise.isEmpty) {
                                setModalState(
                                  () => errorMessage =
                                      'Please enter an exercise name',
                                );
                                return;
                              }
                            } else {
                              finalExercise = selectedExercise!.name;
                            }

                            final String? finalMuscleGroup = isOtherSelected
                                ? selectedMuscleGroup
                                : selectedExercise!.muscleGroup;
                            if (finalMuscleGroup == null ||
                                finalMuscleGroup.isEmpty) {
                              setModalState(
                                () => errorMessage =
                                    'Please select a muscle group',
                              );
                              return;
                            }

                            int? durationMinutes;
                            int sets = 1;
                            int reps = 10;
                            double weight = 0;
                            if (isCardioSelected) {
                              durationMinutes = int.tryParse(
                                durationController.text.trim(),
                              );
                              if (durationMinutes == null ||
                                  durationMinutes <= 0) {
                                setModalState(
                                  () => errorMessage = 'Please enter a valid duration in minutes',
                                );
                                return;
                              }
                            } else {
                              sets = int.tryParse(setsController.text) ?? 1;
                              reps = int.tryParse(repsController.text) ?? 10;
                              weight =
                                  double.tryParse(weightController.text) ?? 0;
                            }

                            setModalState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            try {
                              final Map<String, dynamic> payload;
                              if (isCardioSelected) {
                                payload = {
                                  'user_id': userId,
                                  'exercise': finalExercise,
                                  'muscle_group': finalMuscleGroup,
                                  'type': 'cardio',
                                  'duration_minutes': durationMinutes,
                                  'sets': 0,
                                  'reps': 0,
                                  'weight_kg': 0,
                                };
                              } else {
                                payload = {
                                  'user_id': userId,
                                  'exercise': finalExercise,
                                  'sets': sets,
                                  'reps': reps,
                                  'weight_kg': weight,
                                  'muscle_group': finalMuscleGroup,
                                  'type': 'strength',
                                };
                              }

                              final response = await ApiClient.post(
                                'api_log_workout.php',
                                payload,
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
                                      'Failed to log workout';
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                        : const Text('Save'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _FormFieldLabel extends StatelessWidget {
  const _FormFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
