// lib/features/resume/AI/presentation/widgets/ai_loading_overlay.dart
// ✅ AI loading animation — shared across all AI screens

import 'package:flutter/material.dart';

class AILoadingOverlay extends StatefulWidget {
  final String message;
  final String? subtitle;

  const AILoadingOverlay({
    super.key,
    this.message = 'AI is working...',
    this.subtitle,
  });

  @override
  State<AILoadingOverlay> createState() => _AILoadingOverlayState();
}

class _AILoadingOverlayState extends State<AILoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: Transform.rotate(
                  angle: _rotateAnim.value * 6.28318,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ).createShader(bounds),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          ),
        ],
      ),
    );
  }
}