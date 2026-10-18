// lib/features/resume/services/resume_profile_service.dart
// ============================================================
// ✅ COMPLETE RESUME PROFILE SERVICE
// ✅ FIXED: Added getProfilePhotoUrl() and getProfilePhotoPublicId()
// ✅ Adds common professional summary and career objective when empty
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/features/resume/utils/resume_defaults.dart';

class ResumeProfileService {
  // ============================================================
  // ✅ NEW: GET PROFILE PHOTO URL
  // ============================================================
  static Future<String?> getProfilePhotoUrl() async {
    try {
      debugPrint("📸 ResumeProfileService: Fetching profile photo URL...");
      final response = await DioClient.dio.get('/user/full-profile');

      if (response.data is Map) {
        final data = response.data;
        Map<String, dynamic> profile;

        if (data.containsKey('data') && data['data'] is Map) {
          profile = Map<String, dynamic>.from(data['data']);
        } else {
          profile = Map<String, dynamic>.from(data);
        }

        // Check additional_details first
        final additional = profile['additional_details'] as Map?;
        if (additional != null) {
          final photoUrl = additional['profile_photo_url']?.toString();
          if (photoUrl != null && photoUrl.trim().isNotEmpty) {
            debugPrint("✅ Found profile photo in additional_details");
            return photoUrl.trim();
          }
        }

        // Check top-level
        final topLevelUrl = profile['profile_photo_url']?.toString();
        if (topLevelUrl != null && topLevelUrl.trim().isNotEmpty) {
          debugPrint("✅ Found profile photo in top-level");
          return topLevelUrl.trim();
        }
      }
      debugPrint("ℹ️ No profile photo found");
      return null;
    } catch (e) {
      debugPrint("❌ ResumeProfileService: Error fetching profile photo: $e");
      return null;
    }
  }

  // ============================================================
  // ✅ NEW: GET PROFILE PHOTO PUBLIC ID
  // ============================================================
  static Future<String?> getProfilePhotoPublicId() async {
    try {
      debugPrint("📸 ResumeProfileService: Fetching profile photo public ID...");
      final response = await DioClient.dio.get('/user/full-profile');

      if (response.data is Map) {
        final data = response.data;
        Map<String, dynamic> profile;

        if (data.containsKey('data') && data['data'] is Map) {
          profile = Map<String, dynamic>.from(data['data']);
        } else {
          profile = Map<String, dynamic>.from(data);
        }

        // Check additional_details first
        final additional = profile['additional_details'] as Map?;
        if (additional != null) {
          final publicId = additional['profile_photo_public_id']?.toString();
          if (publicId != null && publicId.trim().isNotEmpty) {
            debugPrint("✅ Found public ID in additional_details");
            return publicId.trim();
          }
        }

        // Check top-level
        final topLevelId = profile['profile_photo_public_id']?.toString();
        if (topLevelId != null && topLevelId.trim().isNotEmpty) {
          debugPrint("✅ Found public ID in top-level");
          return topLevelId.trim();
        }
      }
      debugPrint("ℹ️ No profile photo public ID found");
      return null;
    } catch (e) {
      debugPrint("❌ ResumeProfileService: Error fetching public ID: $e");
      return null;
    }
  }

  // ============================================================
  // ✅ FETCH FULL PROFILE
  // ============================================================
  static Future<Map<String, dynamic>> fetchFullProfile() async {
    try {
      debugPrint("📋 ResumeProfileService: Fetching full profile...");
      final response = await DioClient.dio.get('/user/full-profile');

      if (response.data is Map) {
        final data = response.data;
        Map<String, dynamic> profile;

        if (data.containsKey('data') && data['data'] is Map) {
          profile = Map<String, dynamic>.from(data['data']);
        } else {
          profile = Map<String, dynamic>.from(data);
        }

        // ✅ Ensure summary and objective are never empty
        return _ensureSummaryAndObjective(profile);
      }
      return {};
    } catch (e) {
      debugPrint("❌ ResumeProfileService: Error fetching profile: $e");
      return {};
    }
  }

  // ============================================================
  // ✅ ENSURE SUMMARY AND OBJECTIVE ARE NEVER EMPTY
  // ============================================================
  static Map<String, dynamic> _ensureSummaryAndObjective(
      Map<String, dynamic> profile) {
    // Calculate experience years
    final experienceList = profile['experience'] as List? ?? [];
    final totalExperience = experienceList.length;
    final isFresher = profile['is_fresher'] == true || totalExperience == 0;

    // ✅ Get or generate summary
    final existingSummary = profile['summary']?.toString();
    final summary = ResumeDefaults.getProfessionalSummary(
      existingSummary: existingSummary,
      experienceYears: totalExperience,
      isFresher: isFresher,
    );
    profile['summary'] = summary;

    // ✅ Get or generate career objective
    final existingObjective = profile['career_objective']?.toString();
    final objective = ResumeDefaults.getCareerObjective(
      existingObjective: existingObjective,
      experienceYears: totalExperience,
      isFresher: isFresher,
    );
    profile['career_objective'] = objective;

    debugPrint("✅ ResumeProfileService: Summary and Objective ensured");
    debugPrint("   Summary length: ${summary.length}");
    debugPrint("   Objective length: ${objective.length}");

    return profile;
  }

  // ============================================================
  // ✅ GET PROFILE SUMMARY (Short version)
  // ============================================================
  static String getProfileSummary(Map<String, dynamic> profile) {
    final existingSummary = profile['summary']?.toString();
    return ResumeDefaults.getShortProfessionalSummary(
      existingSummary: existingSummary,
    );
  }

  // ============================================================
  // ✅ GET CAREER OBJECTIVE (Short version)
  // ============================================================
  static String getCareerObjective(Map<String, dynamic> profile) {
    final existingObjective = profile['career_objective']?.toString();
    return ResumeDefaults.getShortCareerObjective(
      existingObjective: existingObjective,
    );
  }

  // ============================================================
  // ✅ BUILD RESUME DATA (Complete)
  // ============================================================
  static Future<Map<String, dynamic>> buildResumeData() async {
    final profile = await fetchFullProfile();

    if (profile.isEmpty) {
      debugPrint("⚠️ ResumeProfileService: Empty profile returned");
      return _getEmptyResumeData();
    }

    // Calculate experience
    final experienceList = profile['experience'] as List? ?? [];
    final totalExperience = experienceList.length;
    final isFresher = profile['is_fresher'] == true || totalExperience == 0;

    return {
      // Personal Info
      'full_name': profile['full_name'] ?? '',
      'email': profile['email'] ?? '',
      'phone': profile['phone'] ?? '',
      'dob': profile['dob'] ?? '',
      'gender': profile['gender'] ?? '',
      'category': profile['category'] ?? 'General/UR',
      'nationality': profile['nationality'] ?? 'Indian',

      // ✅ Summary & Objective (NEVER EMPTY)
      'summary': ResumeDefaults.getProfessionalSummary(
        existingSummary: profile['summary']?.toString(),
        experienceYears: totalExperience,
        isFresher: isFresher,
      ),
      'career_objective': ResumeDefaults.getCareerObjective(
        existingObjective: profile['career_objective']?.toString(),
        experienceYears: totalExperience,
        isFresher: isFresher,
      ),

      // Address
      'current_address': profile['current_address'] ?? {},
      'permanent_address': profile['permanent_address'] ?? {},

      // Education
      'academic_records': profile['academic_records'] ?? [],

      // Experience
      'experience': experienceList,
      'is_fresher': isFresher,
      'total_experience_years': totalExperience,

      // Skills
      'skills': profile['skills'] ?? [],

      // Certifications
      'certifications': profile['certifications'] ?? [],

      // Projects
      'projects': profile['projects'] ?? [],

      // Languages
      'languages': profile['languages'] ?? [],
      'languages_known': profile['languages_known'] ?? [],

      // Social Links
      'social_links': profile['social_links'] ?? {},

      // Disability
      'disability': profile['disability'] ?? {},

      // Documents
      'profile_photo_url': profile['profile_photo_url'] ?? '',
      'resume_url': profile['resume_url'] ?? '',

      // Additional
      'additional_details': profile['additional_details'] ?? {},
      'references': profile['references'] ?? {},
    };
  }

  // ============================================================
  // ✅ EMPTY RESUME DATA (Fallback)
  // ============================================================
  static Map<String, dynamic> _getEmptyResumeData() {
    return {
      'full_name': '',
      'email': '',
      'phone': '',
      'dob': '',
      'gender': '',
      'category': 'General/UR',
      'nationality': 'Indian',
      'summary': ResumeDefaults.commonProfessionalSummary,
      'career_objective': ResumeDefaults.commonCareerObjective,
      'current_address': {},
      'permanent_address': {},
      'academic_records': [],
      'experience': [],
      'is_fresher': true,
      'total_experience_years': 0,
      'skills': [],
      'certifications': [],
      'projects': [],
      'languages': [],
      'languages_known': [],
      'social_links': {},
      'disability': {},
      'profile_photo_url': '',
      'resume_url': '',
      'additional_details': {},
      'references': {},
    };
  }
}