// lib/features/payment/presentation/widgets/application_success_dialog.dart
// ✅ Reusable success dialog shown after payment for Job / Service / Scheme
// ✅ Shows Application Number (human-readable) + all key details
// ✅ Works on Web + Mobile
// ✅ Copy-to-clipboard for the Application Number
// ✅ FIXED: Never pops a route that is not a dialog — safely guarded with mounted checks
// ✅ FIXED: Added optional onDone callback so callers can control post-dialog flow
//           without this dialog accidentally popping the entire route stack.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ApplicationSuccessDialog extends StatelessWidget {
  final String applicationNumber;
  final String title;        // Job title / Service name / Scheme name
  final String subtitle;     // Organization / Sub-service / Scheme level
  final String paymentType;  // "Job" | "Service" | "Scheme"
  final int amountPaid;
  final String? paymentId;
  final String? status;
  final VoidCallback? onViewApplications;

  /// ✅ NEW: Optional callback fired when the user taps "Done".
  /// The dialog ALWAYS closes itself first, then runs this callback.
  /// This lets the parent decide what happens next (stay, go back, refresh, etc.)
  final VoidCallback? onDone;

  const ApplicationSuccessDialog({
    super.key,
    required this.applicationNumber,
    required this.title,
    required this.subtitle,
    required this.paymentType,
    required this.amountPaid,
    this.paymentId,
    this.status,
    this.onViewApplications,
    this.onDone,
  });

  static Future<void> show(
    BuildContext context, {
    required String applicationNumber,
    required String title,
    required String subtitle,
    required String paymentType,
    required int amountPaid,
    String? paymentId,
    String? status,
    VoidCallback? onViewApplications,
    VoidCallback? onDone,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApplicationSuccessDialog(
        applicationNumber: applicationNumber,
        title: title,
        subtitle: subtitle,
        paymentType: paymentType,
        amountPaid: amountPaid,
        paymentId: paymentId,
        status: status,
        onViewApplications: onViewApplications,
        onDone: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---------------- Success Icon ----------------
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 46,
                ),
              ),
              const SizedBox(height: 18),

              // ---------------- Title ----------------
              const Text(
                "Application Submitted!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Your $paymentType application was submitted successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),

              // ---------------- Application Number Box ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.12),
                      const Color(0xFFFF6588).withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number,
                          size: 18,
                          color: Color(0xFF6C63FF),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "APPLICATION NUMBER",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C63FF),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: applicationNumber),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Application number copied"),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy,
                              size: 16,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      applicationNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        fontFamily: 'monospace',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- Detail Rows ----------------
              _buildDetailRow(Icons.work_outline, paymentType, title),
              if (subtitle.isNotEmpty)
                _buildDetailRow(Icons.business, "Organization", subtitle),
              _buildDetailRow(
                Icons.currency_rupee,
                "Amount Paid",
                "₹$amountPaid",
                valueColor: Colors.green,
              ),
              if (paymentId != null && paymentId!.isNotEmpty)
                _buildDetailRow(
                  Icons.receipt_long,
                  "Payment ID",
                  paymentId!,
                  isMono: true,
                ),
              if (status != null && status!.isNotEmpty)
                _buildDetailRow(
                  Icons.info_outline,
                  "Status",
                  status!.toUpperCase(),
                  valueColor: Colors.blue,
                ),
              _buildDetailRow(
                Icons.calendar_today,
                "Date",
                _formatNow(),
              ),

              const SizedBox(height: 20),

              // ---------------- Info Banner ----------------
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Save this Application Number for future reference.",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ---------------- Actions ----------------
              Row(
                children: [
                  if (onViewApplications != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // ✅ FIX: Capture navigator BEFORE closing dialog
                          //         to avoid using a stale BuildContext later.
                          final navigator = Navigator.of(context);
                          if (navigator.canPop()) navigator.pop();
                          // Small delay to let the dialog finish closing
                          Future.microtask(() {
                            onViewApplications!();
                          });
                        },
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text("View Applications"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6C63FF),
                          side: const BorderSide(
                            color: Color(0xFF6C63FF),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (onViewApplications != null) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // ✅ FIX: Safely close ONLY the dialog.
                        //         This never pops the parent route.
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                        // ✅ NEW: Let the caller decide what to do next.
                        //         Jobs/Services don't pass onDone → nothing extra runs.
                        //         Schemes pass onDone → resets form state safely.
                        if (onDone != null) {
                          Future.microtask(() {
                            onDone!();
                          });
                        }
                      },
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text("Done"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool isMono = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF111827),
                fontFamily: isMono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNow() {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    return '${now.day}/${now.month}/${now.year} • '
        '${h.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')} $ampm';
  }
}