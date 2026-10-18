// lib/core/services/profile_state_service.dart
// ✅ INSTANT PHOTO LOAD FROM CACHE
// ✅ SAVES PHOTO TO CACHE AFTER FETCH
// ✅ ZERO DELAY ON APP START / LOGIN

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/core/network/dio_client.dart';

class ProfileStateService {
  static final ProfileStateService _instance =
      ProfileStateService._internal();
  factory ProfileStateService() => _instance;
  ProfileStateService._internal();

  // ============================================================
  // ✅ CACHE KEYS
  // ============================================================
  static const String _photoUrlKey = 'cached_profile_photo_url';
  static const String _publicIdKey = 'cached_profile_photo_public_id';
  static const String _photoTimeKey = 'cached_profile_photo_time';

  final ValueNotifier<String?> profilePhotoUrl =
      ValueNotifier<String?>(null);

  final ValueNotifier<String?> profilePhotoPublicId =
      ValueNotifier<String?>(null);

  final ValueNotifier<int> profileDataVersion = ValueNotifier<int>(0);

  final ValueNotifier<bool> hasInitialPhotoLoaded =
      ValueNotifier<bool>(false);

  final ValueNotifier<bool> isLoadingPhoto = ValueNotifier<bool>(false);

  bool _isFetching = false;

  String? get currentPhotoUrl => profilePhotoUrl.value;
  String? get currentPublicId => profilePhotoPublicId.value;
  bool get hasPhoto => (profilePhotoUrl.value ?? '').isNotEmpty;

  // ============================================================
  // ✅ NEW: LOAD FROM CACHE INSTANTLY (synchronous-ish)
  // Call this ONCE at app start BEFORE any UI renders
  // ============================================================
  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString(_photoUrlKey);
      final cachedPublicId = prefs.getString(_publicIdKey);

      if (cachedUrl != null && cachedUrl.isNotEmpty && _isValidUrl(cachedUrl)) {
        profilePhotoUrl.value = cachedUrl;
        profilePhotoPublicId.value = cachedPublicId;
        hasInitialPhotoLoaded.value = true;
        debugPrint("⚡ ProfileStateService: Loaded photo from CACHE → $cachedUrl");
      } else {
        debugPrint("ℹ️ ProfileStateService: No cached photo found");
      }
    } catch (e) {
      debugPrint("⚠️ ProfileStateService: Cache load error: $e");
    }
  }

  // ============================================================
  // ✅ NEW: SAVE PHOTO TO CACHE
  // Call this EVERY time photo is updated (login / upload / fetch)
  // ============================================================
  Future<void> _saveToCache(String? url, String? publicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url != null && url.isNotEmpty) {
        await prefs.setString(_photoUrlKey, url);
        if (publicId != null) {
          await prefs.setString(_publicIdKey, publicId);
        } else {
          await prefs.remove(_publicIdKey);
        }
        await prefs.setInt(
            _photoTimeKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint("💾 ProfileStateService: Photo saved to CACHE → $url");
      } else {
        await prefs.remove(_photoUrlKey);
        await prefs.remove(_publicIdKey);
        await prefs.remove(_photoTimeKey);
        debugPrint("🗑️ ProfileStateService: Photo removed from CACHE");
      }
    } catch (e) {
      debugPrint("⚠️ ProfileStateService: Cache save error: $e");
    }
  }

  // ============================================================
  // ✅ URL VALIDATOR
  // ============================================================
  bool _isValidUrl(String? url) {
    if (url == null) return false;

    final trimmed = url.trim();

    if (trimmed.isEmpty) return false;
    if (trimmed.length < 10) return false;

    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        !trimmed.startsWith('file:') &&
        !trimmed.startsWith('blob:')) {
      return false;
    }

    final lower = trimmed.toLowerCase();

    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == 'none' ||
        lower == '-' ||
        lower == 'false' ||
        lower == 'true' ||
        lower == '0' ||
        lower == 'not found' ||
        lower == 'notfound' ||
        lower == 'not_found' ||
        lower == 'deleted' ||
        lower == 'removed' ||
        lower == 'empty' ||
        lower == '{}' ||
        lower == '[]') {
      return false;
    }

    if (lower.contains('placeholder') ||
        lower.contains('not-found') ||
        lower.contains('notfound') ||
        lower.contains('example.com/dummy') ||
        lower.contains('undefined')) {
      return false;
    }

    return true;
  }

  // ============================================================
  // ✅ NORMALIZE CLOUDINARY URL
  // ============================================================
  String _normalizeCloudinaryUrl(String url) {
    try {
      final lower = url.toLowerCase();

      if (!lower.contains('cloudinary.com')) return url;

      if (lower.contains('/image/upload/') ||
          lower.contains('/video/upload/')) {
        return url;
      }

      if (lower.contains('/raw/upload/')) {
        final fixed = url.replaceFirst('/raw/upload/', '/image/upload/');
        debugPrint('🔄 ProfileStateService: Converted raw URL → image URL');
        return fixed;
      }

      return url;
    } catch (e) {
      debugPrint('⚠️ ProfileStateService: URL normalize error: $e');
      return url;
    }
  }

  // ============================================================
  // ✅ UPDATE PHOTO URL — NOW ALSO SAVES TO CACHE
  // ============================================================
  void updatePhotoUrl(String? url, {String? publicId}) {
    String? normalized;

    if (url != null && url.trim().isNotEmpty && _isValidUrl(url)) {
      normalized = _normalizeCloudinaryUrl(url.trim());
    } else {
      normalized = null;
    }

    final changed = profilePhotoUrl.value != normalized ||
        profilePhotoPublicId.value != publicId;

    if (!changed) {
      debugPrint("📸 ProfileStateService: URL unchanged, skipping update");
      hasInitialPhotoLoaded.value = true;
      return;
    }

    profilePhotoUrl.value = normalized;
    profilePhotoPublicId.value = publicId;
    hasInitialPhotoLoaded.value = true;

    // ✅ Save to cache
    _saveToCache(normalized, publicId);

    debugPrint("=" * 70);
    debugPrint("📸 ProfileStateService: ✅ Photo updated");
    debugPrint("   New URL: $normalized");
    debugPrint("   Public ID: $publicId");
    debugPrint("=" * 70);
  }

  // ============================================================
  // ✅ LOAD PHOTO FROM BACKEND (kept as fallback)
  // ============================================================
  Future<void> loadPhotoFromBackend({bool forceRefresh = false}) async {
    if (_isFetching) {
      debugPrint("📸 ProfileStateService: Already fetching, skipping");
      return;
    }

    // ✅ If cache has photo and not forcing refresh, skip API call
    if (!forceRefresh &&
        profilePhotoUrl.value != null &&
        profilePhotoUrl.value!.isNotEmpty) {
      debugPrint("📸 ProfileStateService: Photo already in memory, skipping API");
      hasInitialPhotoLoaded.value = true;
      return;
    }

    _isFetching = true;
    isLoadingPhoto.value = true;

    try {
      debugPrint("=" * 70);
      debugPrint("📸 ProfileStateService: Loading photo from backend...");
      debugPrint("=" * 70);

      final response = await DioClient.dio.get('/user/full-profile');

      String? photoUrl;
      String? publicId;

      if (response.data is Map) {
        final data = response.data;

        Map<String, dynamic> profile;

        if (data.containsKey('data') && data['data'] is Map) {
          profile = Map<String, dynamic>.from(data['data'] as Map);
        } else {
          profile = Map<String, dynamic>.from(data);
        }

        debugPrint(
            "📸 ProfileStateService: Profile keys = ${profile.keys.toList()}");

        // ✅ PRIORITY 1: Check additional_details.profile_photo_url
        final additional = profile['additional_details'] as Map?;
        if (additional != null) {
          debugPrint(
              "📸 ProfileStateService: additional_details keys = ${additional.keys.toList()}");

          final addPhotoUrl = additional['profile_photo_url']?.toString();
          if (addPhotoUrl != null && addPhotoUrl.trim().isNotEmpty) {
            photoUrl = addPhotoUrl;
            debugPrint("📸 Found in additional_details.profile_photo_url");
          }

          if (photoUrl == null || photoUrl.trim().isEmpty) {
            final addPictureUrl =
                additional['profile_picture_url']?.toString();
            if (addPictureUrl != null && addPictureUrl.trim().isNotEmpty) {
              photoUrl = addPictureUrl;
              debugPrint("📸 Found in additional_details.profile_picture_url");
            }
          }

          publicId = additional['profile_photo_public_id']?.toString() ??
              additional['public_id']?.toString();
        }

        // ✅ PRIORITY 2: Fallback to top-level profile_photo_url
        if (photoUrl == null || photoUrl.trim().isEmpty) {
          photoUrl = profile['profile_photo_url']?.toString() ??
              profile['photo_url']?.toString();
          if (photoUrl != null && photoUrl.trim().isNotEmpty) {
            debugPrint("📸 Found in top-level profile_photo_url");
          }
        }

        // ✅ PRIORITY 3: Fallback to public_id at top level
        if (publicId == null) {
          publicId = profile['profile_photo_public_id']?.toString();
        }
      }

      debugPrint("=" * 70);
      debugPrint("📸 ProfileStateService: FINAL photo URL = $photoUrl");
      debugPrint("=" * 70);

      // ✅ Only update if valid URL found — otherwise keep existing
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        updatePhotoUrl(photoUrl, publicId: publicId);
      } else if (profilePhotoUrl.value == null) {
        // Only clear if we have nothing
        debugPrint("📸 No photo in backend and no cache → clearing");
        updatePhotoUrl(null);
      } else {
        debugPrint("📸 No photo in backend but cache has one → keeping cache");
        hasInitialPhotoLoaded.value = true;
      }
    } catch (e) {
      debugPrint("❌ ProfileStateService: Failed to load photo: $e");
      // ✅ CRITICAL: Don't clear existing photo on error
      hasInitialPhotoLoaded.value = true;
    } finally {
      _isFetching = false;
      isLoadingPhoto.value = false;
    }
  }

  // ============================================================
  // ✅ SET PHOTO FROM EXTERNAL SOURCE (Login / Upload)
  // ============================================================
  void setPhoto({required String url, String? publicId}) {
    debugPrint("📸 ProfileStateService: setPhoto called → $url");
    updatePhotoUrl(url, publicId: publicId);
    bumpVersion();
  }

  // ============================================================
  // ✅ CLEAR PHOTO
  // ============================================================
  void clearPhoto() {
    profilePhotoUrl.value = null;
    profilePhotoPublicId.value = null;
    hasInitialPhotoLoaded.value = true;
    // ✅ Also clear cache
    _saveToCache(null, null);
    bumpVersion();
    debugPrint("📸 ProfileStateService: Photo cleared");
  }

  // ============================================================
  // ✅ BUMP VERSION
  // ============================================================
  void bumpVersion() {
    profileDataVersion.value = profileDataVersion.value + 1;
    debugPrint(
        "📸 ProfileStateService: Version bumped to ${profileDataVersion.value}");
  }

  // ============================================================
  // ✅ RESET (on logout)
  // ============================================================
  void reset() {
    profilePhotoUrl.value = null;
    profilePhotoPublicId.value = null;
    hasInitialPhotoLoaded.value = false;
    isLoadingPhoto.value = false;
    profileDataVersion.value = 0;
    _isFetching = false;
    // ✅ Also clear cache on logout
    _saveToCache(null, null);
    debugPrint("📸 ProfileStateService: Reset complete");
  }

  // ============================================================
  // ✅ FORCE REFRESH
  // ============================================================
  Future<void> forceRefresh() async {
    debugPrint("📸 ProfileStateService: Force refresh requested");
    hasInitialPhotoLoaded.value = false;
    await loadPhotoFromBackend(forceRefresh: true);
  }
}