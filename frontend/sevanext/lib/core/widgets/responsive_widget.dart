// lib/core/widgets/responsive_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? web;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.web,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Web detection
        if (kIsWeb) {
          return web ?? desktop ?? tablet ?? mobile;
        }
        
        // Desktop detection
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          return desktop ?? tablet ?? mobile;
        }
        
        // Tablet detection
        if (constraints.maxWidth > 600) {
          return tablet ?? mobile;
        }
        
        // Mobile
        return mobile;
      },
    );
  }

  // Static helper methods
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600 && !kIsWeb;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 900 && !kIsWeb;
  }

  static bool isDesktop(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.of(context).size.width >= 900;
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool isWebPlatform() => kIsWeb;

  static double getResponsiveWidth(BuildContext context, {
    double mobileWidth = double.infinity,
    double tabletWidth = 0.8,
    double desktopWidth = 0.6,
    double webWidth = 0.5,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (kIsWeb) return webWidth * width;
    if (isDesktop(context)) return desktopWidth * width;
    if (isTablet(context)) return tabletWidth * width;
    return mobileWidth;
  }

  static EdgeInsets getResponsivePadding(BuildContext context, {
    EdgeInsets? mobilePadding,
    EdgeInsets? tabletPadding,
    EdgeInsets? desktopPadding,
    EdgeInsets? webPadding,
  }) {
    if (kIsWeb) return webPadding ?? const EdgeInsets.all(40);
    if (isDesktop(context)) return desktopPadding ?? const EdgeInsets.all(30);
    if (isTablet(context)) return tabletPadding ?? const EdgeInsets.all(24);
    return mobilePadding ?? const EdgeInsets.all(16);
  }
}
