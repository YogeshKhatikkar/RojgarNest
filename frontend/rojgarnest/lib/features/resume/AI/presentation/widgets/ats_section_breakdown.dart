// lib/features/resume/AI/presentation/widgets/ats_section_breakdown.dart
// ✅ Section-wise ATS score bars

import 'package:flutter/material.dart';

class ATSSectionBreakdown extends StatelessWidget {
  final Map<String, int> sectionScores;

  const ATSSectionBreakdown({super.key, required this.sectionScores});

  static const Map<String, Map<String, dynamic>> _sectionMeta = {
    'keywords': {
      'label': 'Keyword Match',
      'icon': Icons.vpn_key,
      'color': Color(0xFF6C63FF)
    },
    'experience': {
      'label': 'Experience',
      'icon': Icons.work,
      'color': Color(0xFF10B981)
    },
    'skills': {
      'label': 'Skills',
      'icon': Icons.build,
      'color': Color(0xFF3B82F6)
    },
    'formatting': {
      'label': 'Formatting',
      'icon': Icons.description,
      'color': Color(0xFFF59E0B)
    },
    'summary': {
      'label': 'Summary',
      'icon': Icons.subject,
      'color': Color(0xFF8B5CF6)
    },
    'education': {
      'label': 'Education',
      'icon': Icons.school,
      'color': Color(0xFFEC4899)
    },
    'projects': {
      'label': 'Projects',
      'icon': Icons.code,
      'color': Color(0xFF06B6D4)
    },
    'certifications': {
      'label': 'Certifications',
      'icon': Icons.verified,
      'color': Color(0xFFF97316)
    },
    'contact': {
      'label': 'Contact Info',
      'icon': Icons.contact_mail,
      'color': Color(0xFF14B8A6)
    },
  };

  @override
  Widget build(BuildContext context) {
    final entries = sectionScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((e) {
        final meta = _sectionMeta[e.key] ??
            {'label': e.key, 'icon': Icons.star, 'color': Colors.grey};
        return _buildBar(
          label: meta['label'] as String,
          icon: meta['icon'] as IconData,
          color: meta['color'] as Color,
          value: e.value,
        );
      }).toList(),
    );
  }

  Widget _buildBar({
    required String label,
    required IconData icon,
    required Color color,
    required int value,
  }) {
    final isGood = value >= 70;
    final isMid = value >= 50 && value < 70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                '$value%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isGood
                      ? const Color(0xFF10B981)
                      : isMid
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, _) {
                return LinearProgressIndicator(
                  value: animValue,
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade200,
                  color: color,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}