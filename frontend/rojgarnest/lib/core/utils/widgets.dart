import 'package:flutter/material.dart';

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const ModernButton({
    required this.text,
    required this.onTap,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        backgroundColor: Colors.blueAccent,
      ),
      onPressed: isLoading ? null : onTap,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
