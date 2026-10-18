// lib/core/services/cloudinary_service.dart
// ✅ COMPLETE FIXED VERSION - Works for ALL Document Types

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnest/core/config/api_config.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

class CloudinaryService {
  /// Upload job advertisement
  static Future<Map<String, dynamic>> uploadJobAdvertisement({
    required Uint8List fileBytes,
    required String fileName,
    required String jobTitle,
    required String organization,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      throw Exception("No authentication token found");
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/admin/add-job-with-advertisement',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(_getMimeType(fileName)),
    );
    request.files.add(multipartFile);

    final jobData = {
      'post_name': jobTitle,
      'organization': organization,
      'post_date': DateTime.now().toIso8601String().split('T')[0],
      'job_type': 'private',
      'description': 'Job posted via app',
    };

    request.fields['job_data'] = jsonEncode(jobData);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception("Upload failed: ${response.statusCode}");
    }
  }

  /// Upload user document (resume, application document)
  static Future<Map<String, dynamic>> uploadUserDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String applicationId,
    required String endpoint,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      throw Exception("No authentication token found");
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(_getMimeType(fileName)),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception("Upload failed: ${response.statusCode}");
    }
  }

  /// Upload resume
  static Future<Map<String, dynamic>> uploadResume({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      throw Exception("No authentication token found");
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/resume/upload-resume');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(_getMimeType(fileName)),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception("Upload failed: ${response.statusCode}");
    }
  }

  /// Upload application document with notes
  static Future<Map<String, dynamic>> uploadApplicationDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String applicationId,
    required String notes,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      throw Exception("No authentication token found");
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/customadmin/applications/$applicationId/submit-with-document',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(_getMimeType(fileName)),
    );
    request.files.add(multipartFile);

    if (notes.isNotEmpty) {
      request.fields['notes'] = notes;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception("Upload failed: ${response.statusCode}");
    }
  }

  /// ✅ FIXED: Upload payment screenshot
  static Future<Map<String, dynamic>> uploadPaymentScreenshot({
    required Uint8List fileBytes,
    required String fileName,
    required String username,
    required String paymentId,
  }) async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      throw Exception("No authentication token found");
    }

    // ✅ CORRECT ENDPOINT for payment screenshots
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/payment/upload-screenshot',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(_getMimeType(fileName)),
    );
    request.files.add(multipartFile);
    
    request.fields['username'] = username;
    request.fields['payment_id'] = paymentId;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception("Upload failed: ${response.statusCode}");
    }
  }

  static String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}