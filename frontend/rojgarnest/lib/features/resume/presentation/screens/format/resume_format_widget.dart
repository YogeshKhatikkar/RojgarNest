// lib/features/resume/presentation/screens/format/resume_format_widget.dart
import 'package:flutter/material.dart';
import 'resume_format_base.dart';

class ResumeFormatWidget extends StatelessWidget {
  final ResumeFormatBase format;
  final Map<String, dynamic> resumeData;

  const ResumeFormatWidget({
    super.key,
    required this.format,
    required this.resumeData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: format.buildPreview(context, resumeData),
    );
  }
}