// lib/core/widgets/platform_aware.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformAware {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;

  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }

  static Color get platformColor {
    if (isWeb) return Colors.blue;
    if (isAndroid) return Colors.green;
    if (isIOS) return Colors.grey[800]!;
    if (isWindows) return Colors.blueGrey;
    if (isLinux) return Colors.orange;
    if (isMacOS) return Colors.grey[700]!;
    return Colors.purple;
  }

  static IconData get platformIcon {
    if (isWeb) return Icons.web;
    if (isAndroid) return Icons.android;
    if (isIOS) return Icons.apple;
    if (isWindows) return Icons.window;
    if (isLinux) return Icons.terminal;
    if (isMacOS) return Icons.apple;
    return Icons.devices;
  }

  static double get platformElevation {
    if (isWeb) return 4.0;
    if (isAndroid || isIOS) return 8.0;
    return 6.0;
  }

  static double get platformTitleSize {
    if (isWeb) return 28;
    if (isAndroid || isIOS) return 22;
    return 26;
  }

  static EdgeInsets get platformPadding {
    if (isWeb) return const EdgeInsets.all(40);
    if (isAndroid || isIOS) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
    return const EdgeInsets.all(30);
  }

  static double get platformCardRadius {
    if (isWeb) return 20;
    if (isAndroid || isIOS) return 12;
    return 16;
  }

  static double get platformButtonRadius {
    if (isWeb) return 30;
    if (isAndroid || isIOS) return 12;
    return 25;
  }
}
