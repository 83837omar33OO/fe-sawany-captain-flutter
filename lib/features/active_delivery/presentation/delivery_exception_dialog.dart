import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_strings.dart';

class DeliveryExceptionDialog extends StatefulWidget {
  final Function(String reason, String details) onSubmit;

  const DeliveryExceptionDialog({super.key, required this.onSubmit});

  @override
  State<DeliveryExceptionDialog> createState() => _DeliveryExceptionDialogState();
}

class _DeliveryExceptionDialogState extends State<DeliveryExceptionDialog> {
  String _selectedReason = AppStrings.exceptionCustomerUnreachable;
  final _detailsController = TextEditingController();

  final List<String> _reasons = [
    AppStrings.exceptionCustomerUnreachable,
    AppStrings.exceptionCustomerRefused,
    AppStrings.exceptionStoreIssue,
    AppStrings.exceptionVehicleBreakdown,
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            SizedBox(width: 8),
            Text(
              "الإبلاغ عن تعثر الطلب",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "اختر سبب تعثر التوصيل لتحويله للمشرف الميداني:",
                style: TextStyle(fontSize: 12, color: AppColors.slateLight),
              ),
              const SizedBox(height: 12),
              ..._reasons.map((reason) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: Text(
                      reason,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReason = val);
                    },
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: "أضف تفاصيل إضافية للمشرف (اختياري)...",
                  hintStyle: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: AppColors.slateLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(110, 42),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onSubmit(_selectedReason, _detailsController.text.trim());
            },
            child: const Text("إرسال البلاغ"),
          ),
        ],
      ),
    );
  }
}
