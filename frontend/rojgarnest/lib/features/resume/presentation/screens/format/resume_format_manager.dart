// lib/features/resume/presentation/screens/format/resume_format_manager.dart
import 'resume_format_base.dart';
import 'formats/classic_format.dart';
import 'formats/executive_format.dart';
import 'formats/fresher_format.dart';
import 'formats/government_format.dart';
import 'formats/modern_format.dart';
import 'formats/tech_format.dart';

class ResumeFormatManager {
  static final List<ResumeFormatBase> _formats = [
    ClassicFormat(),
    ModernFormat(),
    TechFormat(),
    ExecutiveFormat(),
    GovernmentFormat(),
    FresherFormat(),
  ];

  static List<ResumeFormatBase> get allFormats => _formats;

  static ResumeFormatBase? getFormatById(String id) {
    try {
      return _formats.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  static ResumeFormatBase get defaultFormat => _formats.first;
}