// lib/core/widgets/base_page.dart - CORRECTED
import 'package:flutter/material.dart';

class BasePage extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showAppBar;

  const BasePage({
    super.key,
    required this.title,
    required this.child,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              elevation: 0,
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            )
          : null,
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}
