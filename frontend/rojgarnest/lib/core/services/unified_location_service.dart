// lib/core/services/unified_location_service.dart
// FINAL - USES UNIVERSAL LOCATION SERVICE

import 'package:flutter/foundation.dart';
import 'package:rojgarnest/core/services/universal_location_service.dart';

class UnifiedLocationService {
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Use universal location service - works for ALL users
      final location = await UniversalLocationService.getUniversalLocation();

      debugPrint('=' * 60);
      debugPrint('✅ FINAL LOCATION RESULT:');
      debugPrint('   Device: ${location['platform']}');
      debugPrint('   Method: ${location['source']}');
      debugPrint('   Confidence: ${location['confidence']}');
      debugPrint(
          '   Coordinates: ${location['latitude']}, ${location['longitude']}');
      debugPrint('   Location: ${location['location_name']}');
      debugPrint('   Accuracy: ${location['accuracy']} meters');
      debugPrint('=' * 60);

      return location;
    } catch (e) {
      debugPrint('❌ Location error: $e');
      rethrow;
    }
  }
}
