// lib/features/common/widgets/internet_checker.dart
// ✅ INTERNET CONNECTION CHECKER - Shows Offline Message

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnest/features/auth/presentation/controllers/auth_controller.dart';

class InternetChecker extends StatefulWidget {
  const InternetChecker({super.key});

  @override
  State<InternetChecker> createState() => _InternetCheckerState();
}

class _InternetCheckerState extends State<InternetChecker> {
  bool _isConnected = true;
  bool _isChecking = true;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _startListening();
  }

  Future<void> _checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final bool isConnected = result != ConnectivityResult.none;
      
      _updateConnectionState(isConnected);
    } catch (e) {
      debugPrint('❌ Connectivity check error: $e');
      _updateConnectionState(true);
    }
  }

  void _updateConnectionState(bool isConnected) {
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
        _isChecking = false;
      });
      
      // Update AuthController
      final authController = Provider.of<AuthController>(context, listen: false);
      authController.setConnected(isConnected);
      
      debugPrint('🌐 Internet connection: ${isConnected ? "Connected" : "Disconnected"}');
    }
  }

  void _startListening() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
      if (mounted) {
        _updateConnectionState(isConnected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const SizedBox.shrink();
    }

    if (_isConnected) {
      return const SizedBox.shrink();
    }

    // ✅ SHOW OFFLINE MESSAGE
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.red, Colors.redAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            "📡 No Internet Connection",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Please check your network",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _checkConnection,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}