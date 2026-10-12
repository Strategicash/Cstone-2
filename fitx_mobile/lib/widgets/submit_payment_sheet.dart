import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../config/api_client.dart';
import '../theme/app_theme.dart';
import 'membership_plans_carousel.dart';

Future<void> showSubmitPaymentSheet(
  BuildContext context, {
  required int userId,
  MembershipPlan? selectedPlan,
  VoidCallback? onSaved,
}) async {
  final amountController = TextEditingController();
  final referenceNumberController = TextEditingController();
  String selectedMethod = 'GCash';
  String referenceNumber = '';
  XFile? pickedImage;
  String? errorMessage;
  bool isLoading = false;
  double uploadProgress = 0.0;

  final methods = ['GCash', 'Bank Transfer', 'Cash'];

  if (selectedPlan != null) {
    amountController.text = selectedPlan.price.toStringAsFixed(2);
  }

  String buildDescription(String method) {
    final now = DateTime.now();
    final monthYear = DateFormat('MMMM yyyy').format(now);
    if (selectedPlan != null) {
      return '${selectedPlan.planName} Membership — $monthYear ($method)';
    }
    return 'Membership — $monthYear ($method)';
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
              const SizedBox(height: 12),
              const Text(
                'Submit Payment',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 20),

              // Amount
              _FormFieldLabel(text: 'Amount (₱) *'),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  hintText: 'e.g. 1500.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  prefixText: '₱ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              // Payment Method
              _FormFieldLabel(text: 'Payment Method *'),
              DropdownButtonFormField<String>(
                initialValue: selectedMethod,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: methods.map((method) {
                  return DropdownMenuItem<String>(
                    value: method,
                    child: Text(method),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => selectedMethod = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Reference Number (primary proof of payment)
              _FormFieldLabel(text: 'GCash/Bank Reference Number *'),
              TextField(
                controller: referenceNumberController,
                decoration: InputDecoration(
                  hintText: 'e.g. 1234567890123',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  setModalState(() => referenceNumber = value);
                },
              ),
              const SizedBox(height: 12),

              // Proof of Payment Image Picker (optional supporting evidence)
              _FormFieldLabel(text: 'Proof of Payment (Optional)'),
              InkWell(
                onTap: () async {
                  final picker = ImagePicker();
                  final image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxWidth: 1920,
                  );
                  if (image != null) {
                    setModalState(() => pickedImage = image);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: pickedImage == null
                          ? Theme.of(context).dividerColor
                          : AppColors.accent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: pickedImage == null
                        ? Colors.transparent
                        : AppColors.accent.withValues(alpha: 0.05),
                  ),
                  child: pickedImage == null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to add supporting receipt image (optional)',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pickedImage!.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      setModalState(() => pickedImage = null),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Remove'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(pickedImage!.path),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
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

              // Upload progress
              if (isLoading && uploadProgress > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: uploadProgress,
                        backgroundColor: AppColors.accent.withValues(
                          alpha: 0.2,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uploading... ${(uploadProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isLoading || referenceNumber.trim().isEmpty)
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            amountController.text.trim(),
                          );
                          if (amount == null || amount <= 0) {
                            setModalState(
                              () =>
                                  errorMessage = 'Please enter a valid amount',
                            );
                            return;
                          }
                          final refNumber = referenceNumberController.text
                              .trim();
                          if (refNumber.isEmpty) {
                            setModalState(
                              () => errorMessage = 'Please enter the GCash/Bank reference number',
                            );
                            return;
                          }

                          setModalState(() {
                            isLoading = true;
                            uploadProgress = 0.0;
                            errorMessage = null;
                          });

                          try {
                            // Multipart upload (proof image) can't go through
                            // ApiClient.post, so iterate its base URLs here.
                            http.StreamedResponse? streamedResponse;
                            Object? lastError;
                            for (final baseUrl in ApiClient.baseUrls) {
                              try {
                                final uri = Uri.parse(
                                  '$baseUrl/api_submit_payment.php',
                                );
                                final request = http.MultipartRequest(
                                  'POST',
                                  uri,
                                );

                                request.fields['user_id'] = userId.toString();
                                request.fields['description'] =
                                    buildDescription(selectedMethod);
                                request.fields['amount'] = amount.toString();
                                request.fields['reference_number'] = refNumber;

                                if (pickedImage != null) {
                                  final file =
                                      await http.MultipartFile.fromPath(
                                        'proof',
                                        pickedImage!.path,
                                        contentType: MediaType(
                                          'image',
                                          pickedImage!.mimeType ?? 'jpeg',
                                        ),
                                      );
                                  request.files.add(file);
                                }

                                streamedResponse = await request.send();
                                break;
                              } catch (e) {
                                lastError = e;
                              }
                            }

                            if (streamedResponse == null) {
                              throw lastError ??
                                  Exception('Could not reach any server');
                            }

                            if (!context.mounted) return;

                            setModalState(() => uploadProgress = 1.0);

                            final response = await http.Response.fromStream(
                              streamedResponse,
                            );
                            final data = response.body.isNotEmpty
                                ? jsonDecode(response.body)
                                : {
                                    'success': false,
                                    'message': 'Empty response',
                                  };

                            if (!context.mounted) return;

                            if (data['success'] == true) {
                              Navigator.of(context).pop();
                              onSaved?.call();
                            } else {
                              setModalState(() {
                                isLoading = false;
                                uploadProgress = 0.0;
                                errorMessage =
                                    data['message'] ??
                                    'Failed to submit payment';
                              });
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            setModalState(() {
                              isLoading = false;
                              uploadProgress = 0.0;
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
                      : const Text('Submit Payment'),
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
