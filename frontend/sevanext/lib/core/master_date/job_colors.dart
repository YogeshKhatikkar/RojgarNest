// lib/core/master_date/job_colors.dart
// ✅ MASTER DATA FOR JOB COLOR TYPES
// ✅ orderedColorKeys — Blue first, White second, then others
// ✅ shortDescription (for tooltip) + colorSectors (for tooltip list)

import 'package:flutter/material.dart';

class JobColorMasterData {
  /// ✅ ORDERED — Blue first, White second, then the rest
  static const List<String> orderedColorKeys = [
    'blue',
    'white',
    'green',
    'red',
    'orange',
    'purple',
    'teal',
    'pink',
    'indigo',
    'amber',
    'cyan',
    'grey',
  ];

  /// All allowed color type keys — MUST match backend regex
  static const List<String> colorKeys = [
    'blue',
    'green',
    'red',
    'orange',
    'purple',
    'teal',
    'pink',
    'indigo',
    'amber',
    'cyan',
    'grey',
    'white',
  ];

  /// Human-readable labels
  static const Map<String, String> colorLabels = {
    'blue': 'Blue',
    'green': 'Green',
    'red': 'Red',
    'orange': 'Orange',
    'purple': 'Purple',
    'teal': 'Teal',
    'pink': 'Pink',
    'indigo': 'Indigo',
    'amber': 'Amber',
    'cyan': 'Cyan',
    'grey': 'Grey',
    'white': 'White',
  };

  /// ✅ SHORT one-line description (for compact tooltip)
  static const Map<String, String> colorShortDescriptions = {
    'blue': 'Manual labour & skilled trade jobs.',
    'white': 'Office, IT, management & professional jobs.',
    'green': 'Environment, agriculture & sustainability jobs.',
    'red': 'Emergency, defense & high-risk jobs.',
    'orange': 'Construction, mining & heavy industry jobs.',
    'purple': 'Creative, design & media jobs.',
    'teal': 'Healthcare, medical & wellness jobs.',
    'pink': 'Care-giving, beauty & hospitality jobs.',
    'indigo': 'Education, training & academic jobs.',
    'amber': 'Hospitality, tourism & food service jobs.',
    'cyan': 'Water, marine & aviation jobs.',
    'grey': 'General administrative & clerical jobs.',
  };

  /// ✅ SECTORS — compact list for tooltip
  static const Map<String, List<String>> colorSectors = {
    'blue': [
      'Transport & Logistics',
      'Construction',
      'Manufacturing',
      'Warehouse & Packaging',
      'Security Services',
      'Home Services',
      'Automobile & Repair',
      'Delivery & Courier',
      'Cleaning & Housekeeping',
    ],
    'white': [
      'Information Technology (IT)',
      'Banking & Finance',
      'Management & Consulting',
      'Marketing & Sales',
      'Accounting & Auditing',
      'Legal Services',
      'Human Resources',
      'Engineering (Design & R&D)',
      'Government Administration',
      'Data Science & Analytics',
    ],
    'green': [
      'Agriculture & Farming',
      'Horticulture & Nursery',
      'Forestry & Wildlife',
      'Environmental Science',
      'Renewable Energy',
      'Dairy & Poultry',
      'Fisheries',
      'Organic Food Production',
      'Sustainability & Recycling',
    ],
    'red': [
      'Police & Law Enforcement',
      'Fire & Rescue Services',
      'Indian Army',
      'Indian Navy',
      'Indian Air Force',
      'Paramilitary Forces',
      'Emergency Medical Services',
      'Disaster Management',
      'Coast Guard',
    ],
    'orange': [
      'Construction & Infrastructure',
      'Mining & Quarrying',
      'Heavy Machinery Operation',
      'Road & Bridge Construction',
      'Oil & Gas (Field Work)',
      'Power Plant Operations',
      'Steel & Cement Industry',
      'Dams & Tunnels',
      'Excavation & Drilling',
    ],
    'purple': [
      'Graphic & Visual Design',
      'Video & Audio Production',
      'Animation & VFX',
      'Content Writing & Copywriting',
      'Photography & Videography',
      'Fashion Design',
      'Interior Design',
      'UI / UX Design',
      'Advertising & Branding',
      'Social Media Management',
    ],
    'teal': [
      'Hospitals & Clinics',
      'Nursing & Patient Care',
      'Pharmacy',
      'Medical Lab Technology',
      'Physiotherapy & Rehab',
      'Radiology & Imaging',
      'Dentistry',
      'Paramedical Services',
      'Yoga & Wellness',
      'Nutrition & Dietetics',
    ],
    'pink': [
      'Beauty & Cosmetology',
      'Hair Styling & Makeup',
      'Spa & Massage Therapy',
      'Childcare & Nanny Services',
      'Elderly Care',
      'Housekeeping & Domestic Help',
      'Pet Grooming & Care',
      'Social Care & Counselling',
      'Wedding & Event Planning',
    ],
    'indigo': [
      'Schools & Primary Education',
      'Colleges & Universities',
      'Coaching & Tuition',
      'Training Institutes',
      'Online Education (EdTech)',
      'Library & Documentation',
      'Research & Academics',
      'Career Counselling',
      'Special Education',
    ],
    'amber': [
      'Hotels & Resorts',
      'Restaurants & Cafes',
      'Bakery & Confectionery',
      'Travel & Tourism',
      'Tour Guiding',
      'Event & Banquet Management',
      'Front Office & Reception',
      'Food & Beverage Service',
      'Quick Service Restaurants',
    ],
    'cyan': [
      'Shipping & Marine Engineering',
      'Port & Dock Operations',
      'Fishing & Seafood Industry',
      'Aviation (Pilot, Crew, Ground)',
      'Airport Management',
      'Water Treatment & Supply',
      'Diving & Underwater Services',
      'Naval Services (Civil)',
      'Marine Logistics',
    ],
    'grey': [
      'Data Entry & Back Office',
      'Clerical & Filing',
      'Reception & Front Desk',
      'Office Administration',
      'Documentation & Records',
      'Secretarial Services',
      'Printing & Stationery',
      'Dispatch & Mailing',
      'Inventory & Stock Keeping',
    ],
  };

  /// Icon for each color
  static const Map<String, IconData> colorIcons = {
    'blue': Icons.engineering,
    'green': Icons.agriculture,
    'red': Icons.local_fire_department,
    'orange': Icons.construction,
    'purple': Icons.palette,
    'teal': Icons.medical_services,
    'pink': Icons.spa,
    'indigo': Icons.school,
    'amber': Icons.restaurant,
    'cyan': Icons.water_drop,
    'grey': Icons.business_center,
    'white': Icons.work,
  };

  /// Primary color for each key
  static const Map<String, Color> primaryColors = {
    'blue': Color(0xFF2563EB),
    'green': Color(0xFF10B981),
    'red': Color(0xFFEF4444),
    'orange': Color(0xFFF59E0B),
    'purple': Color(0xFF8B5CF6),
    'teal': Color(0xFF14B8A6),
    'pink': Color(0xFFEC4899),
    'indigo': Color(0xFF4F46E5),
    'amber': Color(0xFFD97706),
    'cyan': Color(0xFF06B6D4),
    'grey': Color(0xFF6B7280),
    'white': Color(0xFF9CA3AF),
  };

  /// Secondary (lighter) color for gradient
  static const Map<String, Color> secondaryColors = {
    'blue': Color(0xFF60A5FA),
    'green': Color(0xFF34D399),
    'red': Color(0xFFF87171),
    'orange': Color(0xFFFBBF24),
    'purple': Color(0xFFA78BFA),
    'teal': Color(0xFF2DD4BF),
    'pink': Color(0xFFF472B6),
    'indigo': Color(0xFF818CF8),
    'amber': Color(0xFFFCD34D),
    'cyan': Color(0xFF22D3EE),
    'grey': Color(0xFF9CA3AF),
    'white': Color(0xFFE5E7EB),
  };

  /// Background tint color (for chips/cards)
  static const Map<String, Color> tintColors = {
    'blue': Color(0xFFEFF6FF),
    'green': Color(0xFFECFDF5),
    'red': Color(0xFFFEF2F2),
    'orange': Color(0xFFFFFBEB),
    'purple': Color(0xFFF5F3FF),
    'teal': Color(0xFFF0FDFA),
    'pink': Color(0xFFFDF2F8),
    'indigo': Color(0xFFEEF2FF),
    'amber': Color(0xFFFFFBEB),
    'cyan': Color(0xFFECFEFF),
    'grey': Color(0xFFF3F4F6),
    'white': Color(0xFFF9FAFB),
  };

  static Color getPrimary(String? key) {
    if (key == null) return primaryColors['blue']!;
    final k = key.toLowerCase().trim();
    return primaryColors[k] ?? primaryColors['blue']!;
  }

  static Color getSecondary(String? key) {
    if (key == null) return secondaryColors['blue']!;
    final k = key.toLowerCase().trim();
    return secondaryColors[k] ?? secondaryColors['blue']!;
  }

  static Color getTint(String? key) {
    if (key == null) return tintColors['blue']!;
    final k = key.toLowerCase().trim();
    return tintColors[k] ?? tintColors['blue']!;
  }

  static String getLabel(String? key) {
    if (key == null) return 'Blue';
    final k = key.toLowerCase().trim();
    return colorLabels[k] ?? 'Blue';
  }

  /// ✅ Short description for compact tooltip
  static String getShortDescription(String? key) {
    if (key == null) return 'No description available.';
    final k = key.toLowerCase().trim();
    return colorShortDescriptions[k] ?? 'No description available.';
  }

  /// ✅ Sectors for tooltip
  static List<String> getSectors(String? key) {
    if (key == null) return const [];
    final k = key.toLowerCase().trim();
    return colorSectors[k] ?? const [];
  }

  static IconData getIcon(String? key) {
    if (key == null) return colorIcons['blue']!;
    final k = key.toLowerCase().trim();
    return colorIcons[k] ?? colorIcons['blue']!;
  }

  static LinearGradient getGradient(String? key) {
    return LinearGradient(
      colors: [getPrimary(key), getSecondary(key)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static String normalize(String? raw) {
    if (raw == null) return 'blue';
    final k = raw.toLowerCase().trim();
    if (colorKeys.contains(k)) return k;
    if (k == 'gray') return 'grey';
    return 'blue';
  }
}