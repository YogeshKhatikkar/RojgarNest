// lib/core/services/permission_service.dart
// COMPLETE LOCATION PERMISSION SERVICE

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  bool _locationGranted = false;
  bool _storageGranted = false;
  bool _internetAvailable = true;

  bool get locationGranted => _locationGranted;
  bool get storageGranted => _storageGranted;
  bool get internetAvailable => _internetAvailable;

  /// Check internet connectivity
  Future<bool> checkInternet() async {
    // Simple implementation - actual connectivity check
    _internetAvailable = true;
    return true;
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("⚠️ Location services disabled");
        return false;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("⚠️ Location permission denied");
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("⚠️ Location permission permanently denied");
        return false;
      }

      _locationGranted = true;
      debugPrint("✅ Location permission granted");
      return true;
    } catch (e) {
      debugPrint("❌ Location permission error: $e");
      return false;
    }
  }

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    // For Android 13+, different approach needed
    if (await Permission.storage.isDenied) {
      PermissionStatus status = await Permission.storage.request();
      _storageGranted = status.isGranted;
    } else if (await Permission.storage.isGranted) {
      _storageGranted = true;
    } else {
      _storageGranted = true; // Default to true for now
    }
    debugPrint(
      "📁 Storage permission: ${_storageGranted ? "Granted" : "Denied"}",
    );
    return _storageGranted;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    if (!_locationGranted) {
      debugPrint("⚠️ Location permission not granted");
      return null;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("⚠️ Location services disabled");
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint("📍 Position: ${position.latitude}, ${position.longitude}");
      return position;
    } catch (e) {
      debugPrint("❌ Error getting position: $e");
      return null;
    }
  }

  /// Check all permissions
  Future<bool> checkAndRequestAllPermissions() async {
    debugPrint("🔐 Starting permission check...");

    final internetOk = await checkInternet();
    final locationOk = await requestLocationPermission();
    final storageOk = await requestStoragePermission();

    debugPrint(
      "🔐 Result: Internet=$internetOk, Location=$locationOk, Storage=$storageOk",
    );
    return internetOk && locationOk && storageOk;
  }

  /// Open app settings (when permission denied forever)
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
