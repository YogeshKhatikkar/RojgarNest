// lib/features/resume/AI/presentation/widgets/ats_keyword_chips.dart
// ✅ Matched / Missing keyword chips display

import 'package:flutter/material.dart';

class ATSKeywordChips extends StatelessWidget {
  final List<String> matched;
  final List<String> missing;
  final List<String> priorityMissing;

  const ATSKeywordChips({
    super.key,
    required this.matched,
    required this.missing,
    required this.priorityMissing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (priorityMissing.isNotEmpty) ...[
          _buildHeader(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFEF4444),
            label: 'Top Priority Missing (${priorityMissing.length})',
            subtitle: 'Add these to your resume FIRST',
          ),
          const SizedBox(height: 10),
          _buildChips(
              priorityMissing, const Color(0xFFEF4444), Icons.priority_high),
          const SizedBox(height: 20),
        ],
        if (matched.isNotEmpty) ...[
          _buildHeader(
            icon: Icons.check_circle,
            color: const Color(0xFF10B981),
            label: 'Matched Keywords (${matched.length})',
          ),
          const SizedBox(height: 10),
          _buildChips(matched, const Color(0xFF10B981), Icons.check),
          const SizedBox(height: 20),
        ],
        if (missing.isNotEmpty) ...[
          _buildHeader(
            icon: Icons.info_outline,
            color: const Color(0xFFF59E0B),
            label: 'Other Missing Keywords (${missing.length})',
          ),
          const SizedBox(height: 10),
          _buildChips(missing, const Color(0xFFF59E0B), Icons.add),
        ],
        if (matched.isEmpty && missing.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paste a Job Description above to see keyword match analysis.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader({
    required IconData icon,
    required Color color,
    required String label,
    String? subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChips(List<String> items, Color color, IconData icon) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((kw) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 5),
              Text(
                kw,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}