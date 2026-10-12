import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';

Future<void> showLogBodyMetricsSheet(
  BuildContext context, {
  required int userId,
  VoidCallback? onSaved,
  Map<String, dynamic>? previousValues,
}) async {
  final weightController = TextEditingController(
    text: previousValues?['weight_kg'] != null
        ? previousValues!['weight_kg'].toString()
        : '',
  );
  final heightController = TextEditingController(
    text: previousValues?['height_cm'] != null
        ? previousValues!['height_cm'].toString()
        : '',
  );
  final chestController = TextEditingController(
    text: previousValues?['chest_cm'] != null
        ? previousValues!['chest_cm'].toString()
        : '',
  );
  final rightArmController = TextEditingController(
    text: previousValues?['right_arm_cm'] != null
        ? previousValues!['right_arm_cm'].toString()
        : '',
  );
  final leftArmController = TextEditingController(
    text: previousValues?['left_arm_cm'] != null
        ? previousValues!['left_arm_cm'].toString()
        : '',
  );
  final waistNavelController = TextEditingController(
    text: previousValues?['waist_navel_cm'] != null
        ? previousValues!['waist_navel_cm'].toString()
        : '',
  );
  final waistBelowNavelController = TextEditingController(
    text: previousValues?['waist_below_navel_cm'] != null
        ? previousValues!['waist_below_navel_cm'].toString()
        : '',
  );
  final hipsController = TextEditingController(
    text: previousValues?['hips_cm'] != null
        ? previousValues!['hips_cm'].toString()
        : '',
  );
  final rightLegController = TextEditingController(
    text: previousValues?['right_leg_cm'] != null
        ? previousValues!['right_leg_cm'].toString()
        : '',
  );
  final leftLegController = TextEditingController(
    text: previousValues?['left_leg_cm'] != null
        ? previousValues!['left_leg_cm'].toString()
        : '',
  );
  String? errorMessage;
  bool isLoading = false;

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
              const SizedBox(height: 12),
              const Text(
                'Log Body Metrics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Weight and Height are recommended for BMI calculation.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Weight (kg)
              _FormFieldLabel(text: 'Weight (kg) *'),
              TextField(
                controller: weightController,
                decoration: InputDecoration(
                  hintText: 'e.g. 75.5',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'kg ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Height (cm)
              _FormFieldLabel(text: 'Height (cm) *'),
              TextField(
                controller: heightController,
                decoration: InputDecoration(
                  hintText: 'e.g. 180',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Chest (cm)
              _FormFieldLabel(text: 'Chest (cm)'),
              TextField(
                controller: chestController,
                decoration: InputDecoration(
                  hintText: 'e.g. 100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Right Arm (cm)
              _FormFieldLabel(text: 'Right Arm (cm)'),
              TextField(
                controller: rightArmController,
                decoration: InputDecoration(
                  hintText: 'e.g. 35',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Left Arm (cm)
              _FormFieldLabel(text: 'Left Arm (cm)'),
              TextField(
                controller: leftArmController,
                decoration: InputDecoration(
                  hintText: 'e.g. 35',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Waist at Navel (cm)
              _FormFieldLabel(text: 'Waist at Navel (cm)'),
              TextField(
                controller: waistNavelController,
                decoration: InputDecoration(
                  hintText: 'e.g. 85',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Waist Below Navel (cm)
              _FormFieldLabel(text: 'Waist Below Navel (cm)'),
              TextField(
                controller: waistBelowNavelController,
                decoration: InputDecoration(
                  hintText: 'e.g. 90',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Hips (cm)
              _FormFieldLabel(text: 'Hips (cm)'),
              TextField(
                controller: hipsController,
                decoration: InputDecoration(
                  hintText: 'e.g. 100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Right Leg (cm)
              _FormFieldLabel(text: 'Right Leg (cm)'),
              TextField(
                controller: rightLegController,
                decoration: InputDecoration(
                  hintText: 'e.g. 55',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Left Leg (cm)
              _FormFieldLabel(text: 'Left Leg (cm)'),
              TextField(
                controller: leftLegController,
                decoration: InputDecoration(
                  hintText: 'e.g. 55',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: 'cm ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
              SizedBox(
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
                              'api_log_body_metrics.php',
                              {
                                'user_id': userId,
                                'weight_kg': weightController.text.isEmpty
                                    ? null
                                    : double.tryParse(weightController.text),
                                'height_cm': heightController.text.isEmpty
                                    ? null
                                    : double.tryParse(heightController.text),
                                'chest_cm': chestController.text.isEmpty
                                    ? null
                                    : double.tryParse(chestController.text),
                                'right_arm_cm': rightArmController.text.isEmpty
                                    ? null
                                    : double.tryParse(rightArmController.text),
                                'left_arm_cm': leftArmController.text.isEmpty
                                    ? null
                                    : double.tryParse(leftArmController.text),
                                'waist_navel_cm':
                                    waistNavelController.text.isEmpty
                                    ? null
                                    : double.tryParse(waistNavelController.text),
                                'waist_below_navel_cm':
                                    waistBelowNavelController.text.isEmpty
                                    ? null
                                    : double.tryParse(
                                        waistBelowNavelController.text),
                                'hips_cm': hipsController.text.isEmpty
                                    ? null
                                    : double.tryParse(hipsController.text),
                                'right_leg_cm': rightLegController.text.isEmpty
                                    ? null
                                    : double.tryParse(rightLegController.text),
                                'left_leg_cm': leftLegController.text.isEmpty
                                    ? null
                                    : double.tryParse(leftLegController.text),
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
                                    'Failed to log body metrics';
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
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