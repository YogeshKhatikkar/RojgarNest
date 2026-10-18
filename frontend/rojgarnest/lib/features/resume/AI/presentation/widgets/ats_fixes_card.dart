// lib/features/resume/AI/presentation/widgets/ats_fixes_card.dart
// ✅ Prioritized fix list — P1 / P2 / P3

import 'package:flutter/material.dart';
import 'package:rojgarnest/features/resume/AI/data/models/ats_report_model.dart';

class ATSFixesCard extends StatelessWidget {
  final List<ATSFix> fixes;

  const ATSFixesCard({super.key, required this.fixes});

  Color _priorityColor(int p) {
    if (p == 1) return const Color(0xFFEF4444);
    if (p == 2) return const Color(0xFFF59E0B);
    return const Color(0xFF3B82F6);
  }

  String _priorityLabel(int p) {
    if (p == 1) return 'CRITICAL';
    if (p == 2) return 'IMPORTANT';
    return 'NICE TO HAVE';
  }

  @override
  Widget build(BuildContext context) {
    if (fixes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Perfect! No critical issues found. 🎉',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fixes.map((fix) {
        final color = _priorityColor(fix.priority);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _priorityLabel(fix.priority),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fix.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    fix.impact == 'High'
                        ? Icons.trending_up
                        : fix.impact == 'Medium'
                            ? Icons.trending_flat
                            : Icons.trending_down,
                    size: 16,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                fix.issue,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fix.fix,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}