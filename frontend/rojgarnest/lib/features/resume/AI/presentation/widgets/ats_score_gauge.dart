// lib/features/resume/AI/presentation/widgets/ats_score_gauge.dart
// ✅ Big animated circular gauge for overall ATS score

import 'dart:math' as math;
import 'package:flutter/material.dart';

class ATSScoreGauge extends StatefulWidget {
  final double score; // 0-100
  final String grade;
  final double size;

  const ATSScoreGauge({
    super.key,
    required this.score,
    required this.grade,
    this.size = 180,
  });

  @override
  State<ATSScoreGauge> createState() => _ATSScoreGaugeState();
}

class _ATSScoreGaugeState extends State<ATSScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _scoreColor(double score) {
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(widget.score);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final displayScore = _animation.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.25),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _GaugePainter(
                  progress: displayScore / 100.0,
                  color: color,
                  backgroundColor: Colors.grey.shade200,
                  strokeWidth: 14,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: widget.size * 0.26,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -1.5,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: widget.size * 0.09,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.grade.split('(').first.trim(),
                      style: TextStyle(
                        fontSize: widget.size * 0.075,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + (2 * math.pi * progress),
        colors: [
          color.withOpacity(0.6),
          color,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}