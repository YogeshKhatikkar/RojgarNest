// lib/features/resume/presentation/screens/resume_screen.dart
// ✅ COMPLETE FIXED VERSION
// ✅ Profile photo ALWAYS shows on Resume Screen (from DB or ProfileStateService)
// ✅ Auto-loads photo from DB if not in memory
// ✅ Listens to BOTH ProfileStateService AND UserProfileProvider
// ✅ Forces refresh on screen open if photo is null
// ✅ No lines skipped

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/resume/services/resume_profile_service.dart';
import 'package:rojgarnest/features/resume/presentation/widgets/profile_photo_upload_dialog.dart';
import 'package:rojgarnest/features/user/providers/user_profile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';
import 'package:rojgarnest/features/resume/utils/resume_defaults.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _resumeData = {};
  String? _errorMessage;

  /// ✅ Prevents repeated popup in same screen session
  bool _photoDialogShown = false;

  /// ✅ Track if we've triggered the initial photo load
  bool _photoLoadTriggered = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String CACHE_KEY = 'resume_data_cache';
  static const String CACHE_TIMESTAMP = 'resume_cache_timestamp';
  static const int CACHE_DURATION = 5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ✅ CRITICAL FIX: Load photo FIRST (from ProfileStateService),
    // then load provider, then resume data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeScreenData();
      }
    });
  }

  // ============================================================
  // ✅ INITIALIZATION — STRICT ORDER:
  //    1. ProfileStateService.loadPhotoFromBackend()
  //    2. UserProfileProvider.fetchProfile()
  //    3. Load resume data
  // ============================================================
  Future<void> _initializeScreenData() async {
    if (_photoLoadTriggered) return;
    _photoLoadTriggered = true;

    // ✅ STEP 1: Load photo from ProfileStateService (DB source of truth)
    try {
      final service = ProfileStateService();
      if (!service.hasInitialPhotoLoaded.value ||
          service.profilePhotoUrl.value == null ||
          service.profilePhotoUrl.value!.isEmpty) {
        debugPrint("📸 ResumeScreen: Loading photo from backend...");
        await service.loadPhotoFromBackend(forceRefresh: true);
      }
      debugPrint(
          "📸 ResumeScreen: Photo = ${service.profilePhotoUrl.value}");
    } catch (e) {
      debugPrint("⚠️ ResumeScreen: Photo load failed: $e");
    }

    if (!mounted) return;

    // ✅ STEP 2: Sync UserProfileProvider
    try {
      final provider =
          Provider.of<UserProfileProvider>(context, listen: false);
      final globalUrl = ProfileStateService().profilePhotoUrl.value;

      if (globalUrl != null && globalUrl.isNotEmpty) {
        // Only set if different
        if (provider.profilePhotoUrl != globalUrl) {
          provider.setProfilePhoto(url: globalUrl);
        }
      } else {
        await provider.fetchProfile();
      }
    } catch (e) {
      debugPrint("⚠️ ResumeScreen: Provider sync failed: $e");
    }

    if (!mounted) return;

    // ✅ STEP 3: Load resume data
    await _loadResumeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ SINGLE SOURCE OF TRUTH — Priority order:
  //    1. ProfileStateService (global, from DB)
  //    2. UserProfileProvider (local cache)
  //    3. Resume data (from /resume/profile-resume)
  // ============================================================
  String? get _effectivePhotoUrl {
    // 1. ProfileStateService — DB source of truth
    try {
      final globalUrl = ProfileStateService().profilePhotoUrl.value;
      if (globalUrl != null && globalUrl.trim().isNotEmpty) {
        return globalUrl;
      }
    } catch (_) {}

    // 2. UserProfileProvider fallback
    try {
      final url = Provider.of<UserProfileProvider>(context, listen: false)
          .profilePhotoUrl;
      if (url != null && url.trim().isNotEmpty) return url;
    } catch (_) {}

    // 3. Resume data fallback
    try {
      final userInfo = _resumeData['user_info'] as Map<String, dynamic>?;
      final url = userInfo?['profile_photo_url']?.toString();
      if (url != null && url.trim().isNotEmpty) return url;
    } catch (_) {}

    return null;
  }

  // ============================================================
  // FAST LOADING — CACHE FIRST
  // ============================================================
  Future<void> _loadResumeData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cachedData = await _loadFromCache();
      if (cachedData != null && mounted) {
        _resumeData = cachedData;
        setState(() => _isLoading = false);
        _animationController.forward();
        _pulseController.stop();
      }
      await _fetchFreshData();
    } catch (e) {
      if (!mounted) return;
      if (_resumeData.isEmpty) {
        _errorMessage = 'Failed to load resume';
        showMessage(context, _errorMessage!, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _pulseController.stop();
      }
    }
  }

  Future<Map<String, dynamic>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(CACHE_TIMESTAMP);
      if (timestamp != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (elapsed / (1000 * 60) > CACHE_DURATION) return null;
      }
      final cachedJson = prefs.getString(CACHE_KEY);
      if (cachedJson != null) {
        return Map<String, dynamic>.from(
          jsonDecode(cachedJson) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
    return null;
  }

  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CACHE_KEY, jsonEncode(data));
      await prefs.setInt(
          CACHE_TIMESTAMP, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  Future<void> _fetchFreshData() async {
    try {
      // ✅ CRITICAL: Sync BOTH providers with server truth
      try {
        final photoUrl = await ResumeProfileService.getProfilePhotoUrl();
        final publicId = await ResumeProfileService.getProfilePhotoPublicId();

        if (!mounted) return;

        final provider =
            Provider.of<UserProfileProvider>(context, listen: false);

        if (photoUrl != null && photoUrl.isNotEmpty) {
          provider.setProfilePhoto(url: photoUrl, publicId: publicId);
          ProfileStateService().setPhoto(url: photoUrl, publicId: publicId);
          debugPrint('📸 ResumeScreen: Synced photo → $photoUrl');
        } else {
          // ✅ Only clear if BOTH sources are empty
          final globalUrl = ProfileStateService().profilePhotoUrl.value;
          if (globalUrl == null || globalUrl.isEmpty) {
            provider.clearProfilePhoto();
            ProfileStateService().clearPhoto();
            debugPrint('📸 ResumeScreen: No photo found, cleared');
          }
        }
      } catch (e) {
        debugPrint('⚠️ ResumeScreen: Could not sync profile photo: $e');
      }

      final response = await DioClient.dio.get('/resume/profile-resume');
      if (!mounted) return;

      if (response.data['success'] == true) {
        final data = response.data as Map<String, dynamic>;
        data['user_info'] = data['user_info'] ?? {};
        data['contact_info'] = data['contact_info'] ?? {};
        data['education'] = data['education'] ?? [];
        data['experience'] = data['experience'] ?? [];
        data['skills'] = data['skills'] ?? {'all': []};
        data['certifications'] = data['certifications'] ?? [];
        data['projects'] = data['projects'] ?? [];
        data['languages'] = data['languages'] ?? [];
        data['social_links'] = data['social_links'] ?? {};
        data['statistics'] = data['statistics'] ?? {};

        // ✅ Inject current photo URL into resume data
        final photoUrl = _effectivePhotoUrl;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          final userInfo = data['user_info'] as Map<String, dynamic>;
          userInfo['profile_photo_url'] = photoUrl;
          final additional =
              data['additional_details'] as Map<String, dynamic>? ?? {};
          additional['profile_photo_url'] = photoUrl;
          data['additional_details'] = additional;
        }

        setState(() {
          _resumeData = data;
        });
        await _saveToCache(data);

        if (_animationController.status == AnimationStatus.dismissed) {
          _animationController.forward();
        }
      } else if (_resumeData.isEmpty) {
        _errorMessage = response.data['message'] ?? 'Failed to load resume';
        if (mounted) showMessage(context, _errorMessage!, isError: true);
      }
    } catch (e) {
      debugPrint('Fresh data fetch error: $e');
      if (_resumeData.isEmpty && mounted) {
        _errorMessage = 'Network error, please retry';
      }
    }
  }

  // ✅ Auto-popup (only once)
  void _maybeShowPhotoPopup() {
    if (_photoDialogShown || !mounted) return;
    if (_effectivePhotoUrl != null) return;
    _photoDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showProfilePhotoDialog();
    });
  }

  Future<void> _showProfilePhotoDialog() async {
    if (!mounted) return;
    final uploadedUrl = await ProfilePhotoUploadDialog.show(
      context,
      currentPhotoUrl: _effectivePhotoUrl,
    );
    if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
      // ✅ Sync to BOTH providers
      ProfileStateService().setPhoto(url: uploadedUrl);
      try {
        Provider.of<UserProfileProvider>(context, listen: false)
            .setProfilePhoto(url: uploadedUrl);
      } catch (_) {}

      debugPrint('✅ Photo uploaded via dialog: $uploadedUrl');
    }
  }

  Future<void> _refreshResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CACHE_KEY);
      await prefs.remove(CACHE_TIMESTAMP);
    } catch (_) {}
    _animationController.reset();
    _pulseController.repeat(reverse: true);
    _photoDialogShown = false;
    _photoLoadTriggered = false;

    // ✅ Force refresh ProfileStateService too
    await ProfileStateService().forceRefresh();

    await _initializeScreenData();
  }

  // ============================================================
  // LOADING SCREEN
  // ============================================================
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ).createShader(bounds),
              child: const Text(
                "AI is loading your resume...",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 24),
            const Opacity(
              opacity: 0.6,
              child: Text(
                "Please wait while we prepare your resume",
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6B80)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    // ✅ Watch provider — any photo change anywhere rebuilds this screen
    context.watch<UserProfileProvider>();

    if (_isLoading && _resumeData.isEmpty) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null && _resumeData.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline,
                    size: 50, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              const Text(
                "Failed to load resume",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D3F),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF6B6B80), fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshResume,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Trigger popup AFTER first build if no photo
    _maybeShowPhotoPopup();

    final userInfo = _resumeData['user_info'] as Map<String, dynamic>? ?? {};
    final contactInfo =
        _resumeData['contact_info'] as Map<String, dynamic>? ?? {};
    final summary = _resumeData['professional_summary'] as String? ?? '';
    final objective = _resumeData['career_objective'] as String? ?? '';
    final education = _resumeData['education'] as List<dynamic>? ?? [];
    final experience = _resumeData['experience'] as List<dynamic>? ?? [];
    final skills = _resumeData['skills'] as Map<String, dynamic>? ?? {};
    final certifications = _resumeData['certifications'] as List<dynamic>? ?? [];
    final projects = _resumeData['projects'] as List<dynamic>? ?? [];
    final languages = _resumeData['languages'] as List<dynamic>? ?? [];
    final socialLinks =
        _resumeData['social_links'] as Map<String, dynamic>? ?? {};
    final statistics =
        _resumeData['statistics'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshResume,
        color: const Color(0xFF6C63FF),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(userInfo, contactInfo),
                const SizedBox(height: 20),
                _buildStatsRow(statistics),
                const SizedBox(height: 20),
                if (summary.isNotEmpty)
                  _buildSectionCard(
                    title: "Professional Summary",
                    icon: Icons.description,
                    color: const Color(0xFF6C63FF),
                    child: Text(
                      summary,
                      style: const TextStyle(
                          height: 1.6,
                          fontSize: 14,
                          color: Color(0xFF2D2D3F)),
                    ),
                  ),
                if (summary.isNotEmpty) const SizedBox(height: 16),
                if (objective.isNotEmpty)
                  _buildSectionCard(
                    title: "Career Objective",
                    icon: Icons.track_changes,
                    color: const Color(0xFFFF6B6B),
                    child: Text(
                      objective,
                      style: const TextStyle(
                          height: 1.6,
                          fontSize: 14,
                          color: Color(0xFF2D2D3F)),
                    ),
                  ),
                if (objective.isNotEmpty) const SizedBox(height: 16),
                if (experience.isNotEmpty)
                  _buildExperienceSection(experience),
                if (experience.isNotEmpty) const SizedBox(height: 16),
                if (education.isNotEmpty) _buildEducationSection(education),
                if (education.isNotEmpty) const SizedBox(height: 16),
                if (skills.isNotEmpty &&
                    skills['all'] != null &&
                    (skills['all'] as List).isNotEmpty)
                  _buildSkillsSection(skills),
                if (skills.isNotEmpty &&
                    skills['all'] != null &&
                    (skills['all'] as List).isNotEmpty)
                  const SizedBox(height: 16),
                if (certifications.isNotEmpty)
                  _buildCertificationsSection(certifications),
                if (certifications.isNotEmpty) const SizedBox(height: 16),
                if (projects.isNotEmpty) _buildProjectsSection(projects),
                if (projects.isNotEmpty) const SizedBox(height: 16),
                if (languages.isNotEmpty) _buildLanguagesSection(languages),
                if (languages.isNotEmpty) const SizedBox(height: 16),
                _buildContactSocialSection(contactInfo, socialLinks),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        "My Resume",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Color(0xFF2D2D3F),
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.photo_camera, color: Color(0xFF6C63FF)),
          onPressed: _showProfilePhotoDialog,
          tooltip: "Change Profile Photo",
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF6C63FF)),
          onPressed: _refreshResume,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> stats) {
    final statsData = [
      {
        'title': 'Experience',
        'value': '${stats['total_experience_years'] ?? 0} yr',
        'icon': Icons.work,
        'color': const Color(0xFF6C63FF),
      },
      {
        'title': 'Skills',
        'value': '${stats['total_skills'] ?? 0}',
        'icon': Icons.build,
        'color': const Color(0xFFFF6B6B),
      },
      {
        'title': 'Projects',
        'value': '${stats['total_projects'] ?? 0}',
        'icon': Icons.code,
        'color': const Color(0xFF4ECDC4),
      },
    ];

    return Row(
      children: statsData.map((stat) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (stat['color'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(stat['icon'] as IconData,
                      color: stat['color'] as Color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  stat['value'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D3F),
                  ),
                ),
                Text(
                  stat['title'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B6B80),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // ✅ HEADER CARD WITH PHOTO — FIXED
  // Uses ValueListenableBuilder + fallback to provider
  // ============================================================
  Widget _buildHeaderCard(
      Map<String, dynamic> userInfo, Map<String, dynamic> contactInfo) {
    final fullName = userInfo['full_name'] ?? 'User';
    final email = contactInfo['email'] ?? '';
    final phone = contactInfo['phone'] ?? '';
    final address =
        contactInfo['current_address'] as Map<String, dynamic>? ?? {};
    final location = address['full_address'] ??
        address['city'] ??
        address['state'] ??
        'India';
    final age = userInfo['age'];
    final gender = userInfo['gender'] ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B83FF), Color(0xFFA8A4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x336C63FF),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ✅ CRITICAL: Listen to BOTH ProfileStateService AND UserProfileProvider
              // Watch provider triggers rebuild, ValueListenableBuilder handles instant global updates
              _buildHeaderPhoto(fullName),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (age != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$age years • $gender",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                if (email.isNotEmpty)
                  _buildHeaderInfoRow(Icons.email, email),
                if (email.isNotEmpty) const SizedBox(height: 8),
                if (phone.isNotEmpty)
                  _buildHeaderInfoRow(Icons.phone, phone),
                if (phone.isNotEmpty) const SizedBox(height: 8),
                _buildHeaderInfoRow(Icons.location_on, location),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ HEADER PHOTO — Always shows photo from DB if available
  // ============================================================
  Widget _buildHeaderPhoto(String fullName) {
    return ValueListenableBuilder<String?>(
      valueListenable: ProfileStateService().profilePhotoUrl,
      builder: (context, globalPhotoUrl, _) {
        // Priority: ProfileStateService → Provider → null
        String? photoUrl = globalPhotoUrl;

        if (photoUrl == null || photoUrl.trim().isEmpty) {
          try {
            final providerUrl =
                Provider.of<UserProfileProvider>(context, listen: false)
                    .profilePhotoUrl;
            if (providerUrl != null && providerUrl.trim().isNotEmpty) {
              photoUrl = providerUrl;
            }
          } catch (_) {}
        }

        // Final fallback: resume data
        if (photoUrl == null || photoUrl.trim().isEmpty) {
          final userInfo = _resumeData['user_info'] as Map<String, dynamic>?;
          final resumePhoto = userInfo?['profile_photo_url']?.toString();
          if (resumePhoto != null && resumePhoto.trim().isNotEmpty) {
            photoUrl = resumePhoto;
          }
        }

        final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

        if (hasPhoto) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                key: ValueKey(photoUrl),
                imageUrl: photoUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.white24,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white24,
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
          );
        }

        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.white, Colors.white70],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10),
            ],
          ),
          child: Center(
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6C63FF),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection(List<dynamic> experience) {
    return _buildSectionCard(
      title: "Work Experience",
      icon: Icons.work,
      color: const Color(0xFFFF6B6B),
      child: Column(
        children: experience.asMap().entries.map((entry) {
          final index = entry.key;
          final exp = entry.value;
          final isLast = index == experience.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp['role'] ?? 'Position',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D3F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exp['company'] ?? 'Company',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B6B80),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Color(0xFF6B6B80)),
                            const SizedBox(width: 6),
                            Text(
                              "${exp['start_date'] ?? ''} - ${exp['end_date'] ?? 'Present'}",
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B6B80)),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFF6B6B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                exp['duration'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFF6B6B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          exp['description'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF2D2D3F),
                          ),
                        ),
                        if (exp['achievements'] != null &&
                            (exp['achievements'] as List).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            "Key Achievements",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF2D2D3F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...(exp['achievements'] as List).map(
                            (ach) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF6B6B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ach.toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2D2D3F),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast) const SizedBox(height: 20),
              if (!isLast) const Divider(height: 1),
              if (!isLast) const SizedBox(height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEducationSection(List<dynamic> education) {
    return _buildSectionCard(
      title: "Education",
      icon: Icons.school,
      color: const Color(0xFF4ECDC4),
      child: Column(
        children: education.asMap().entries.map((entry) {
          final index = entry.key;
          final edu = entry.value;
          final isLast = index == education.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ECDC4), Color(0xFF6EDDD5)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          edu['degree'] ?? edu['level'] ?? 'Education',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D3F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          edu['institute'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B6B80),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Color(0xFF6B6B80)),
                            const SizedBox(width: 6),
                            Text(
                              edu['year_of_passing']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B6B80)),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF4ECDC4).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                edu['result_display'] ?? 'Completed',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4ECDC4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (edu['subjects'] != null &&
                            (edu['subjects'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (edu['subjects'] as List)
                                .map((subj) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4ECDC4)
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        subj.toString(),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF4ECDC4)),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast) const SizedBox(height: 20),
              if (!isLast) const Divider(height: 1),
              if (!isLast) const SizedBox(height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkillsSection(Map<String, dynamic> skills) {
    final expertSkills = skills['expert'] as List? ?? [];
    final advancedSkills = skills['advanced'] as List? ?? [];
    final intermediateSkills = skills['intermediate'] as List? ?? [];

    return _buildSectionCard(
      title: "Skills",
      icon: Icons.build,
      color: const Color(0xFF6C63FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expertSkills.isNotEmpty) ...[
            Row(
              children: const [
                Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                SizedBox(width: 6),
                Text(
                  "Expert",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFFFB800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: expertSkills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB800), Color(0xFFFFD233)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          skill['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (advancedSkills.isNotEmpty) ...[
            Row(
              children: const [
                Icon(Icons.auto_awesome, size: 16, color: Color(0xFF6C63FF)),
                SizedBox(width: 6),
                Text(
                  "Advanced",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: advancedSkills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          skill['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (intermediateSkills.isNotEmpty) ...[
            Row(
              children: const [
                Icon(Icons.trending_up, size: 16, color: Color(0xFF4ECDC4)),
                SizedBox(width: 6),
                Text(
                  "Intermediate",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF4ECDC4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: intermediateSkills
                  .map((skill) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF4ECDC4).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          skill['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4ECDC4),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertificationsSection(List<dynamic> certifications) {
    return _buildSectionCard(
      title: "Certifications",
      icon: Icons.verified,
      color: const Color(0xFFFF6B6B),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: certifications.map((cert) {
          return Container(
            padding: const EdgeInsets.all(12),
            width: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B6B).withOpacity(0.08),
                  const Color(0xFFFF6B6B).withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified,
                      size: 16, color: Color(0xFFFF6B6B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D3F),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${cert['issuer'] ?? ''} (${cert['year'] ?? ''})",
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B6B80)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectsSection(List<dynamic> projects) {
    return _buildSectionCard(
      title: "Projects",
      icon: Icons.code,
      color: const Color(0xFF6C63FF),
      child: Column(
        children: projects.asMap().entries.map((entry) {
          final index = entry.key;
          final project = entry.value;
          final isLast = index == projects.length - 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.05),
                      const Color(0xFF6C63FF).withOpacity(0.01),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project['title'] ?? 'Project',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D3F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (project['technologies'] != null &&
                        (project['technologies'] as List).isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (project['technologies'] as List)
                            .map((tech) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C63FF)
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    tech.toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      project['description'] ?? '',
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF2D2D3F)),
                    ),
                  ],
                ),
              ),
              if (!isLast) const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLanguagesSection(List<dynamic> languages) {
    return _buildSectionCard(
      title: "Languages",
      icon: Icons.language,
      color: const Color(0xFF4ECDC4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: languages.map((lang) {
          final proficiency = lang['proficiency'] ?? 'Professional';
          Color color;
          switch (proficiency.toLowerCase()) {
            case 'native':
              color = const Color(0xFF6C63FF);
              break;
            case 'fluent':
              color = const Color(0xFF4ECDC4);
              break;
            case 'professional':
              color = const Color(0xFFFFB800);
              break;
            default:
              color = const Color(0xFFFF6B6B);
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: color),
                const SizedBox(width: 8),
                Text(
                  "${lang['name'] ?? ''} - $proficiency",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactSocialSection(
      Map<String, dynamic> contactInfo, Map<String, dynamic> socialLinks) {
    final emergencyContact =
        contactInfo['emergency_contact'] as Map<String, dynamic>? ?? {};

    return _buildSectionCard(
      title: "Contact & Social",
      icon: Icons.contact_mail,
      color: const Color(0xFF6C63FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Emergency Contact",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2D2D3F),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                    Icons.person, "Name", emergencyContact['name'] ?? ''),
                if ((emergencyContact['name'] ?? '').isNotEmpty)
                  const SizedBox(height: 6),
                _buildInfoRow(Icons.people, "Relationship",
                    emergencyContact['relationship'] ?? ''),
                if ((emergencyContact['relationship'] ?? '').isNotEmpty)
                  const SizedBox(height: 6),
                _buildInfoRow(
                    Icons.phone, "Phone", emergencyContact['phone'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            "Social Profiles",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2D2D3F),
            ),
          ),
          const SizedBox(height: 10),
          if ((socialLinks['linkedin'] ?? '').isNotEmpty)
            _buildLinkRow(
                Icons.linked_camera, "LinkedIn", socialLinks['linkedin']),
          if ((socialLinks['github'] ?? '').isNotEmpty)
            _buildLinkRow(Icons.code, "GitHub", socialLinks['github']),
          if ((socialLinks['portfolio'] ?? '').isNotEmpty)
            _buildLinkRow(Icons.web, "Portfolio", socialLinks['portfolio']),
          if ((socialLinks['personal_website'] ?? '').isNotEmpty)
            _buildLinkRow(
                Icons.public, "Website", socialLinks['personal_website']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox();
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B6B80)),
        const SizedBox(width: 8),
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6B80),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D2D3F),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow(IconData icon, String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final uri =
              Uri.parse(url.startsWith('http') ? url : 'https://$url');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  url,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C63FF),
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.open_in_new,
                  size: 14, color: Color(0xFF6C63FF)),
            ],
          ),
        ),
      ),
    );
  }
}