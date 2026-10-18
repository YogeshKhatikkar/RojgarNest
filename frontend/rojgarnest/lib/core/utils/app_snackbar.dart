// lib/core/utils/app_snackbar.dart
// ✅ Safe way to show SnackBar with mounted check and error handling

import 'package:flutter/material.dart';

/// Safe way to show SnackBar with mounted check and error handling
void showMessage(BuildContext context, String message, {bool isError = false}) {
  // CRITICAL FIX: Check if context is still mounted and valid
  if (!context.mounted) {
    return;
  }

  // Additional safety check for Scaffold
  final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  if (scaffoldMessenger == null) {
    return;
  }

  // Remove any existing SnackBars
  try {
    scaffoldMessenger.removeCurrentSnackBar();
  } catch (e) {
    // Ignore errors when removing
  }

  // Show new SnackBar
  try {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    // Fallback: print to console if SnackBar fails
    debugPrint("SnackBar Error: $message");
  }
}

/// Safe alternative using Builder to get fresh context
class SafeSnackBar {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    // Use addPostFrameCallback to ensure widget tree is stable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showMessage(context, message, isError: isError);
      }
    });
  }
}

/// Global snackbar key for use outside of BuildContext
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Show snackbar using global key (safe from any context)
void showGlobalSnackBar(String message, {bool isError = false}) {
  if (rootScaffoldMessengerKey.currentState != null) {
    rootScaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  } else {
    debugPrint("Global SnackBar: $message");
  }
}