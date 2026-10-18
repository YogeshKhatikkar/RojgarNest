// lib/core/services/geocoding_service.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class GeocodingService {
  static const String _base = "/location";

  static Future<Map<String, dynamic>?> geocodeAddress(String address) async {
    if (address.isEmpty) return null;

    try {
      final response = await DioClient.dio.post(
        '$_base/geocode',
        data: {'address': address},
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint("Geocoding error: ${DioClient.extractErrorMessage(e)}");
      }
      return null;
    }
  }
}
