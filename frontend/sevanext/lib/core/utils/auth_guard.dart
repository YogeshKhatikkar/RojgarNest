import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SecureStorage.getToken(),
      builder: (context, snapshot) {
        // ✅ LOADING
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final token = snapshot.data;

        // ❗ IMPORTANT FIX
        if (token == null || token.isEmpty) {
          return child; // ❗ ALLOW FLOW (forgot password ke liye)
        }

        return child;
      },
    );
  }
}
