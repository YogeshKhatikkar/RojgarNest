// lib/features/user/presentation/controllers/user_profile_controller.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';

class UserProfileController extends ChangeNotifier {
  bool isLoading = false;
  bool isSaving = false;

  // Profile Data Cache
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _contactInfo;

  Map<String, dynamic>? get profileData => _profileData;
  Map<String, dynamic>? get contactInfo => _contactInfo;

  String? get userEmail => _contactInfo?['email'];
  String? get userMobile => _contactInfo?['mobile'];
  String? get userName => _contactInfo?['name'];

  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }

  void _setSaving(bool val) {
    isSaving = val;
    notifyListeners();
  }

  // ================= FETCH CONTACT INFO FROM AUTH =================
  Future<Map<String, dynamic>?> fetchContactInfo() async {
    _setLoading(true);
    try {
      final response = await DioClient.dio.get('/user/contact-info');
      final data = response.data;

      // Store in cache
      _contactInfo = {
        'email': data['email'] ?? '',
        'mobile': data['mobile'] ?? '',
        'name': data['name'] ?? '',
      };

      // Also save to secure storage for easy access
      if (_contactInfo!['email']!.isNotEmpty) {
        await SecureStorage.setEmail(_contactInfo!['email']!);
      }
      if (_contactInfo!['mobile']!.isNotEmpty) {
        await SecureStorage.setMobile(_contactInfo!['mobile']!);
      }

      notifyListeners();
      return _contactInfo;
    } catch (e) {
      debugPrint("Error fetching contact info: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ================= FETCH FULL PROFILE =================
  Future<Map<String, dynamic>?> fetchFullProfile() async {
    _setLoading(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        await fetchContactInfo();
      }

      final userEmail = await SecureStorage.getEmail();
      if (userEmail == null || userEmail.isEmpty) {
        return null;
      }

      final profileResponse = await DioClient.dio.get(
        '/user/full-profile',
        queryParameters: {'email': userEmail},
      );

      _profileData = profileResponse.data;
      notifyListeners();
      return _profileData;
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ================= SAVE ALL PROFILE DATA =================
  Future<bool> saveAllProfileData(Map<String, dynamic> data) async {
    _setSaving(true);
    try {
      // Ensure email is present
      final email = await SecureStorage.getEmail();
      if (email != null && email.isNotEmpty) {
        data['email'] = email;
      }

      await DioClient.dio.post('/user/save-all', data: data);
      _profileData = data;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error saving profile: $e");
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ================= SAVE BASIC DETAILS =================
  Future<bool> saveBasicDetails(Map<String, dynamic> data) async {
    return saveAllProfileData(data);
  }

  // ================= ADD EDUCATION =================
  Future<Map<String, dynamic>?> addEducation(
    Map<String, dynamic> educationData,
  ) async {
    _setSaving(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        return null;
      }

      final addResponse = await DioClient.dio.post(
        '/user/education',
        queryParameters: {'email': email},
        data: educationData,
      );

      // Refresh profile data
      await fetchFullProfile();
      return addResponse.data;
    } catch (e) {
      debugPrint("Error adding education: $e");
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ================= UPDATE EDUCATION =================
  Future<bool> updateEducation(
    String id,
    Map<String, dynamic> educationData,
  ) async {
    _setSaving(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        return false;
      }

      await DioClient.dio.put(
        '/user/education/$id',
        queryParameters: {'email': email},
        data: educationData,
      );

      await fetchFullProfile();
      return true;
    } catch (e) {
      debugPrint("Error updating education: $e");
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ================= DELETE EDUCATION =================
  Future<bool> deleteEducation(String id) async {
    _setSaving(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        return false;
      }

      await DioClient.dio.delete(
        '/user/education/$id',
        queryParameters: {'email': email},
      );

      await fetchFullProfile();
      return true;
    } catch (e) {
      debugPrint("Error deleting education: $e");
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ================= ADD EXPERIENCE =================
  Future<Map<String, dynamic>?> addExperience(
    Map<String, dynamic> experienceData,
  ) async {
    _setSaving(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        return null;
      }

      final addResponse = await DioClient.dio.post(
        '/user/experience',
        queryParameters: {'email': email},
        data: experienceData,
      );

      await fetchFullProfile();
      return addResponse.data;
    } catch (e) {
      debugPrint("Error adding experience: $e");
      return null;
    } finally {
      _setSaving(false);
    }
  }

  // ================= UPDATE EXPERIENCE =================
  Future<bool> updateExperience(
    String id,
    Map<String, dynamic> experienceData,
  ) async {
    _setSaving(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        return false;
      }

      await DioClient.dio.put(
        '/user/experience/$id',
        queryParameters: {'email': email},
        data: experienceData,
      );

      await fetchFullProfile();
      return true;
    } catch (e) {
      debugPrint("Error updating experience: $e");
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // ================= DELETE EXPERIENCE =================
  Future<bool> deleteExperience(String id) async {
    _setSaving(true);
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) {
        return false;
      }

      await DioClient.dio.delete(
        '/user/experience/$id',
        queryParameters: {'email': email},
      );

      await fetchFullProfile();
      return true;
    } catch (e) {
      debugPrint("Error deleting experience: $e");
      return false;
    } finally {
      _setSaving(false);
    }
  }

  // Clear cache on logout
  void clearCache() {
    _profileData = null;
    _contactInfo = null;
    notifyListeners();
  }
}
