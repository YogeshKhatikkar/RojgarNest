// lib/features/user/providers/user_profile_provider.dart
// ✅ SINGLE SOURCE OF TRUTH for profile photo
// ✅ FIXED: No notifyListeners() in constructor
// ✅ FIXED: Handles authenticated Cloudinary URLs via signed URL fetch
// ✅ FIXED: Never clears photo on transient errors
// ✅ FIXED: displayPhotoUrl getter returns best loadable URL

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';

class UserProfileProvider extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  String? _profilePhotoUrl;
  String? _profilePhotoPublicId;
  int _version = 0;
  bool _isDisposed = false;

  // ✅ Cache of signed URLs (key: original authenticated URL)
  final Map<String, String> _signedUrlCache = {};

  // ✅ Prevent concurrent sign requests
  final Set<String> _fetchingSigns = {};

  UserProfileProvider() {
    _profilePhotoUrl = ProfileStateService().profilePhotoUrl.value;
    _profilePhotoPublicId =
        ProfileStateService().profilePhotoPublicId.value;

    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      debugPrint(
          "⚡ UserProfileProvider: Initial photo from cache → $_profilePhotoUrl");
    }

    ProfileStateService().profilePhotoUrl.addListener(_onGlobalPhotoChanged);
    ProfileStateService()
        .profilePhotoPublicId
        .addListener(_onGlobalPublicIdChanged);
  }

  void _safeNotify() {
    if (_isDisposed) return;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) notifyListeners();
      });
    } catch (e) {
      if (!_isDisposed) notifyListeners();
    }
  }

  void _onGlobalPhotoChanged() {
    if (_isDisposed) return;
    final newUrl = ProfileStateService().profilePhotoUrl.value;
    if (_profilePhotoUrl != newUrl) {
      _profilePhotoUrl = newUrl;
      _version++;
      _safeNotify();
      debugPrint('✅ UserProfileProvider: Synced → $_profilePhotoUrl');

      // If new URL is authenticated, fetch signed version
      if (newUrl != null && _isAuthenticatedUrl(newUrl)) {
        fetchSignedUrlIfNeeded();
      }
    }
  }

  void _onGlobalPublicIdChanged() {
    if (_isDisposed) return;
    final newId = ProfileStateService().profilePhotoPublicId.value;
    if (_profilePhotoPublicId != newId) {
      _profilePhotoPublicId = newId;
      _version++;
      _safeNotify();
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================
  Map<String, dynamic>? get profile => _profile;
  String? get profilePhotoUrl => _profilePhotoUrl;
  String? get profilePhotoPublicId => _profilePhotoPublicId;
  bool get hasPhoto => (_profilePhotoUrl ?? '').trim().isNotEmpty;
  int get version => _version;

  /// ✅ Returns best loadable URL:
  /// - Public URL → returns as-is
  /// - Authenticated URL → returns signed URL if cached, else null
  ///   (and triggers a background fetch)
  String? get displayPhotoUrl {
    final url = _profilePhotoUrl;
    if (url == null || url.isEmpty) return null;

    if (!_isAuthenticatedUrl(url)) return url;

    final signed = _signedUrlCache[url];
    if (signed != null && signed.isNotEmpty) return signed;

    // Not yet fetched — trigger fetch & return null (initials will show)
    fetchSignedUrlIfNeeded();
    return null;
  }

  bool _isAuthenticatedUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/image/authenticated/') ||
        lower.contains('/raw/authenticated/') ||
        lower.contains('/video/authenticated/');
  }

  // ============================================================
  // ✅ FETCH SIGNED URL FOR AUTHENTICATED URL
  // ============================================================
  Future<void> fetchSignedUrlIfNeeded() async {
    final url = _profilePhotoUrl;
    if (url == null || url.isEmpty) return;
    if (!_isAuthenticatedUrl(url)) return;
    if (_signedUrlCache.containsKey(url)) return;
    if (_fetchingSigns.contains(url)) return;

    final publicId = _profilePhotoPublicId;
    if (publicId == null || publicId.isEmpty) {
      debugPrint("⚠️ Cannot fetch signed URL — missing public_id");
      return;
    }

    _fetchingSigns.add(url);

    try {
      debugPrint("🔐 Fetching signed URL for: $publicId");

      final response = await DioClient.dio.post(
        '/user/get-signed-photo-url',
        data: {
          'public_id': publicId,
          'resource_type': 'image',
        },
      );

      if (_isDisposed) return;

      String? signedUrl;
      if (response.data is Map) {
        final d = response.data as Map;
        signedUrl = (d['signed_url'] ?? d['url'])?.toString();
      }

      if (signedUrl != null && signedUrl.isNotEmpty) {
        _signedUrlCache[url] = signedUrl;
        _version++;
        _safeNotify();
        debugPrint("✅ Signed URL fetched → $signedUrl");
      } else {
        debugPrint("⚠️ Backend returned empty signed URL");
      }
    } catch (e) {
      debugPrint("❌ Signed URL fetch failed: $e");
    } finally {
      _fetchingSigns.remove(url);
    }
  }

  // ============================================================
  // URL VALIDATOR
  // ============================================================
  bool _isValidImageUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return false;
    }
    final lower = trimmed.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'none' ||
        lower == 'n/a') {
      return false;
    }
    return true;
  }

  String _normalizeCloudinaryUrl(String url) {
    try {
      final lower = url.toLowerCase();
      if (!lower.contains('cloudinary.com')) return url;
      if (lower.contains('/image/upload/') ||
          lower.contains('/image/authenticated/') ||
          lower.contains('/video/upload/') ||
          lower.contains('/video/authenticated/')) {
        return url;
      }
      if (lower.contains('/raw/upload/')) {
        return url.replaceFirst('/raw/upload/', '/image/upload/');
      }
      if (lower.contains('/raw/authenticated/')) {
        return url.replaceFirst(
            '/raw/authenticated/', '/image/authenticated/');
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  // ============================================================
  // SET / CLEAR
  // ============================================================
  void setProfilePhoto({required String url, String? publicId}) {
    if (!_isValidImageUrl(url)) {
      debugPrint('❌ setProfilePhoto: invalid URL → $url');
      return;
    }

    final normalized = _normalizeCloudinaryUrl(url.trim());

    _profilePhotoUrl = normalized;
    _profilePhotoPublicId = publicId;
    _version++;
    _safeNotify();

    ProfileStateService().setPhoto(url: normalized, publicId: publicId);

    if (_isAuthenticatedUrl(normalized)) {
      fetchSignedUrlIfNeeded();
    }
  }

  void updateProfilePhotoFromUrl(String url, {String? publicId}) {
    setProfilePhoto(url: url, publicId: publicId);
  }

  void clearProfilePhoto() {
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    _signedUrlCache.clear();
    _version++;
    _safeNotify();
    ProfileStateService().clearPhoto();
  }

  // ============================================================
  // LOAD
  // ============================================================
  Future<void> loadProfile() async {
    final cachedUrl = ProfileStateService().profilePhotoUrl.value;
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      _profilePhotoUrl = cachedUrl;
      _profilePhotoPublicId =
          ProfileStateService().profilePhotoPublicId.value;
      _version++;
      _safeNotify();
      debugPrint("⚡ UserProfileProvider: Instant cache load → $cachedUrl");

      if (_isAuthenticatedUrl(cachedUrl)) {
        fetchSignedUrlIfNeeded();
      }
    }

    await fetchProfile();
  }

  void clear() {
    _profile = null;
    _profilePhotoUrl = null;
    _profilePhotoPublicId = null;
    _signedUrlCache.clear();
    _fetchingSigns.clear();
    _version++;
    _safeNotify();
    ProfileStateService().reset();
    debugPrint('🗑️ Provider: Full profile state cleared');
  }

  // ============================================================
  // FETCH PROFILE
  // ============================================================
  Future<void> fetchProfile() async {
    if (_isDisposed) return;
    try {
      final response = await DioClient.dio.get('/user/full-profile');
      if (_isDisposed) return;

      Map<String, dynamic> data = {};
      if (response.data is Map) {
        final body = response.data as Map;
        if (body['data'] is Map) {
          data = Map<String, dynamic>.from(body['data']);
        } else {
          data = Map<String, dynamic>.from(body);
        }
      }
      _profile = data;

      final additional = (data['additional_details'] as Map?) ?? {};
      final rawUrl = (additional['profile_photo_url']?.toString() ??
              data['profile_photo_url']?.toString() ??
              data['photo_url']?.toString() ??
              '')
          .trim();

      _profilePhotoPublicId = (additional['profile_photo_public_id'] ??
              data['profile_photo_public_id'])
          ?.toString();

      if (_isValidImageUrl(rawUrl)) {
        final normalized = _normalizeCloudinaryUrl(rawUrl);
        final changed = _profilePhotoUrl != normalized;
        _profilePhotoUrl = normalized;
        if (changed) _version++;

        ProfileStateService()
            .setPhoto(url: normalized, publicId: _profilePhotoPublicId);

        if (_isAuthenticatedUrl(normalized)) {
          await fetchSignedUrlIfNeeded();
        }
      } else {
        if (_profilePhotoUrl == null) {
          _profilePhotoUrl = null;
          _profilePhotoPublicId = null;
          ProfileStateService().clearPhoto();
        }
      }

      _safeNotify();
      debugPrint(
          '✅ Provider profile fetched (v$_version) — photo: $_profilePhotoUrl');
    } catch (e) {
      debugPrint('❌ Provider fetchProfile failed: $e');
    }
  }

  Future<void> refresh() async {
    await fetchProfile();
  }

  void updateProfile(Map<String, dynamic> newProfile) {
    _profile = newProfile;
    final additional = (newProfile['additional_details'] as Map?) ?? {};
    final rawUrl = (additional['profile_photo_url']?.toString() ??
            newProfile['profile_photo_url']?.toString() ??
            '')
        .trim();

    if (_isValidImageUrl(rawUrl)) {
      _profilePhotoUrl = _normalizeCloudinaryUrl(rawUrl);
      ProfileStateService().setPhoto(url: _profilePhotoUrl!);
    }
    _version++;
    _safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      ProfileStateService()
          .profilePhotoUrl
          .removeListener(_onGlobalPhotoChanged);
      ProfileStateService()
          .profilePhotoPublicId
          .removeListener(_onGlobalPublicIdChanged);
    } catch (_) {}
    super.dispose();
  }
}