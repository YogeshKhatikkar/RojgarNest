// lib/features/resume/presentation/screens/build_resume_screen.dart
// ✅ AI-BASED MODERN DESIGN - Matches ResumeScreen style
// ✅ Complete with loading animation, glassmorphism, and stats
// ✅ FIXED: Print / Download / Share now exports the EXACT format that was clicked
// ✅ FIXED: Prevents double-tap, shows clear success/failure messages
// ✅ FIXED: _selectedCategory now updates via setState so Quick Actions use the right format
// ✅ FIXED: Profile photo integration — upload popup, header photo, format preview photo
// ✅ FIXED: UserProfileProvider watch → auto-update photo everywhere without refresh
// ✅ FIXED: No more floating ValueListenableBuilder — properly wrapped
// ✅ FIXED: Syncs with ProfileStateService (global source of truth)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/resume/services/resume_pdf_service.dart';
import 'package:rojgarnest/features/resume/services/resume_profile_service.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';
import 'package:rojgarnest/features/resume/presentation/widgets/profile_photo_upload_dialog.dart';
import 'package:rojgarnest/features/resume/presentation/screens/format/resume_format_manager.dart';
import 'package:rojgarnest/features/resume/presentation/screens/format/resume_format_popup.dart';
import 'package:rojgarnest/features/resume/presentation/screens/format/resume_format_base.dart';
import 'package:rojgarnest/features/user/providers/user_profile_provider.dart';

class BuildResumeScreen extends StatefulWidget {
  const BuildResumeScreen({super.key});

  @override
  State<BuildResumeScreen> createState() => _BuildResumeScreenState();
}

class _BuildResumeScreenState extends State<BuildResumeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isDialogOpen = false;
  bool _isGenerating = false;
  String _selectedCategory = 'classic';
  Map<String, dynamic> _resumeData = {};
  String? _errorMessage;

  // ==================== PROFILE PHOTO STATE ====================
  String? _profilePhotoUrl;
  bool _hasShownPhotoDialog = false;

  // ==================== RESUME DATA FIELDS ====================
  String _fullName = '';
  String _firstName = '';
  String _lastName = '';
  String _dateOfBirth = '';
  String _gender = '';
  String _email = '';
  String _phone = '';
  String _location = '';
  String _professionalSummary = '';
  String _careerObjective = '';
  List<Map<String, dynamic>> _education = [];
  List<Map<String, dynamic>> _experience = [];
  List<String> _skills = [];
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _languages = [];
  Map<String, String> _socialLinks = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ✅ Load from ProfileStateService FIRST, then load resume data
    _loadProfilePhoto();
    _loadResumeData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ==================== EFFECTIVE PHOTO URL ====================
  /// ✅ Priority: local state → ProfileStateService → UserProfileProvider → null
  String? get _effectivePhotoUrl {
    // 1. Local state (just-uploaded from this screen)
    if (_profilePhotoUrl != null && _profilePhotoUrl!.trim().isNotEmpty) {
      return _profilePhotoUrl;
    }

    // 2. ProfileStateService (global source of truth)
    try {
      final globalUrl = ProfileStateService().profilePhotoUrl.value;
      if (globalUrl != null && globalUrl.trim().isNotEmpty) {
        return globalUrl;
      }
    } catch (_) {}

    // 3. UserProfileProvider
    try {
      final providerUrl =
          Provider.of<UserProfileProvider>(context, listen: false)
              .profilePhotoUrl;
      if (providerUrl != null && providerUrl.trim().isNotEmpty) {
        return providerUrl;
      }
    } catch (_) {}

    return null;
  }

  // ==================== LOAD PROFILE PHOTO ====================
  Future<void> _loadProfilePhoto() async {
    try {
      final service = ProfileStateService();

      if (!service.hasInitialPhotoLoaded.value) {
        debugPrint("📸 BuildResume: Loading profile photo...");
        await service.loadPhotoFromBackend();
      }

      final photoUrl = service.profilePhotoUrl.value;
      debugPrint("📸 BuildResume: Photo = $photoUrl");

      if (mounted) {
        setState(() {
          _profilePhotoUrl = photoUrl;
        });

        // Also push to UserProfileProvider
        try {
          if (photoUrl != null && photoUrl.isNotEmpty) {
            Provider.of<UserProfileProvider>(context, listen: false)
                .setProfilePhoto(url: photoUrl);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("⚠️ BuildResume: Photo load failed: $e");
    }
  }

  // ==================== LOAD RESUME DATA ====================
  Future<void> _loadResumeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ✅ STEP 1: Ensure ProfileStateService is loaded
      final globalService = ProfileStateService();
      if (!globalService.hasInitialPhotoLoaded.value) {
        debugPrint("📸 BuildResume: Loading profile photo from backend...");
        await globalService.loadPhotoFromBackend();
      }

      // ✅ STEP 2: Read the photo URL from global service
      _profilePhotoUrl = globalService.profilePhotoUrl.value;
      debugPrint("📸 BuildResume: Global photo = $_profilePhotoUrl");

      // ✅ STEP 3: Also sync UserProfileProvider
      if (mounted) {
        try {
          final provider =
              Provider.of<UserProfileProvider>(context, listen: false);
          if (_profilePhotoUrl != null &&
              _profilePhotoUrl!.isNotEmpty) {
            provider.setProfilePhoto(url: _profilePhotoUrl!);
          } else {
            provider.clearProfilePhoto();
          }
        } catch (_) {}
      }

      // ✅ STEP 4: Fetch resume profile data
      final response = await DioClient.dio.get('/resume/profile-resume');

      if (!mounted) return;

      if (response.data['success'] == true) {
        final data = response.data as Map<String, dynamic>;

        final userInfo = data['user_info'] as Map<String, dynamic>? ?? {};
        _fullName = userInfo['full_name']?.toString() ?? '';
        _firstName = userInfo['first_name']?.toString() ?? '';
        _lastName = userInfo['last_name']?.toString() ?? '';
        _dateOfBirth = userInfo['date_of_birth']?.toString() ??
            userInfo['dob']?.toString() ??
            '';
        _gender = userInfo['gender']?.toString() ?? '';

        final contactInfo =
            data['contact_info'] as Map<String, dynamic>? ?? {};
        _email = contactInfo['email']?.toString() ?? '';
        _phone = contactInfo['phone']?.toString() ?? '';

        final address =
            contactInfo['current_address'] as Map<String, dynamic>? ?? {};
        final city = address['city']?.toString() ?? '';
        final state = address['state']?.toString() ?? '';
        _location = city.isNotEmpty
            ? (state.isNotEmpty ? '$city, $state' : city)
            : (state.isNotEmpty ? state : 'India');

        _professionalSummary =
            data['professional_summary']?.toString() ?? '';
        _careerObjective = data['career_objective']?.toString() ?? '';

        final educationList = data['education'] as List<dynamic>? ?? [];
        _education = educationList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final experienceList = data['experience'] as List<dynamic>? ?? [];
        _experience = experienceList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final skillsData = data['skills'] as Map<String, dynamic>? ?? {};
        final allSkills = skillsData['all'] as List<dynamic>? ?? [];
        _skills = allSkills
            .map((s) => (s as Map)['name']?.toString() ?? s.toString())
            .toList();

        final certList = data['certifications'] as List<dynamic>? ?? [];
        _certifications = certList
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();

        final projectList = data['projects'] as List<dynamic>? ?? [];
        _projects = projectList
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();

        final langList = data['languages'] as List<dynamic>? ?? [];
        _languages = langList
            .map((l) => Map<String, dynamic>.from(l as Map))
            .toList();

        final social = data['social_links'] as Map<String, dynamic>? ?? {};
        _socialLinks = {};
        social.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            _socialLinks[key] = value.toString();
          }
        });

        _buildResumeData();
        setState(() => _isLoading = false);

        // ✅ Trigger profile photo dialog if missing
        if (_effectivePhotoUrl == null && mounted && !_hasShownPhotoDialog) {
          _hasShownPhotoDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showProfilePhotoDialog();
          });
        }
      } else {
        _errorMessage =
            response.data['message'] ?? 'Failed to load resume data';
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading resume data: $e');
      _errorMessage = e.toString();
      setState(() => _isLoading = false);
    }
  }

  // ==================== PROFILE PHOTO DIALOG ====================
  Future<void> _showProfilePhotoDialog() async {
    if (!mounted) return;

    final uploadedUrl = await ProfilePhotoUploadDialog.show(
      context,
      currentPhotoUrl: _effectivePhotoUrl,
    );

    if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
      setState(() => _profilePhotoUrl = uploadedUrl);

      // ✅ Sync to BOTH providers
      ProfileStateService().setPhoto(url: uploadedUrl);
      try {
        Provider.of<UserProfileProvider>(context, listen: false)
            .setProfilePhoto(url: uploadedUrl);
      } catch (_) {}

      _buildResumeData();
      showMessage(context, "✅ Profile photo uploaded successfully!");
    }
  }

  void _buildResumeData() {
    final photo = _effectivePhotoUrl ?? '';
    _resumeData = {
      'user_info': {
        'full_name': _fullName,
        'first_name': _firstName,
        'last_name': _lastName,
        'age': _getAge(),
        'gender': _gender,
        'email': _email,
        'date_of_birth': _dateOfBirth,
        'profile_photo_url': photo,
      },
      'additional_details': {
        'profile_photo_url': photo,
      },
      'contact_info': {
        'email': _email,
        'phone': _phone,
        'profile_photo_url': photo,
        'current_address': {
          'city': _location.split(', ').first,
          'state': _location.contains(', ') ? _location.split(', ').last : '',
          'full_address': _location,
        },
        'location': _location,
        'emergency_contact': {},
      },
      'professional_summary': _professionalSummary,
      'career_objective': _careerObjective,
      'education': _education,
      'experience': _experience,
      'skills': {
        'all': _skills.map((s) => {'name': s}).toList(),
        'expert': _skills.take(3).map((s) => {'name': s}).toList(),
        'advanced': _skills.length > 3
            ? _skills.skip(3).take(3).map((s) => {'name': s}).toList()
            : [],
        'intermediate': _skills.length > 6
            ? _skills.skip(6).map((s) => {'name': s}).toList()
            : [],
      },
      'certifications': _certifications,
      'projects': _projects,
      'languages': _languages,
      'social_links': _socialLinks,
      'statistics': {
        'total_experience_years': _experience.length,
        'total_skills': _skills.length,
        'total_projects': _projects.length,
        'total_certifications': _certifications.length,
        'profile_completion': _getProfileCompletion(),
      },
    };
  }

  // ==================== HELPER METHODS ====================
  String _getFullName() => _fullName;
  String _getFirstName() => _firstName;
  String _getLastName() => _lastName;
  String _getDateOfBirth() => _dateOfBirth;
  String _getGender() => _gender;
  String _getEmail() => _email;
  String _getPhone() => _phone;
  String _getLocation() => _location;

  Map<String, dynamic> _getCurrentAddress() {
    return {
      'city': _location.split(', ').first,
      'state': _location.contains(', ') ? _location.split(', ').last : '',
      'full_address': _location,
    };
  }

  String _getProfessionalSummary() => _professionalSummary;
  String _getCareerObjective() => _careerObjective;
  List<Map<String, dynamic>> _getEducation() => _education;
  List<Map<String, dynamic>> _getExperience() => _experience;
  List<String> _getSkills() => _skills;
  List<Map<String, dynamic>> _getCertifications() => _certifications;
  List<Map<String, dynamic>> _getProjects() => _projects;
  List<Map<String, dynamic>> _getLanguages() => _languages;
  Map<String, String> _getSocialLinks() => _socialLinks;

  int _getProfileCompletion() {
    int completed = 0;
    int total = 7;

    if (_fullName.isNotEmpty) completed++;
    if (_email.isNotEmpty && _email != 'Not provided') completed++;
    if (_phone.isNotEmpty && _phone != 'Not provided') completed++;
    if (_location.isNotEmpty && _location != 'India') completed++;
    if (_education.isNotEmpty) completed++;
    if (_experience.isNotEmpty) completed++;
    if (_skills.isNotEmpty) completed++;

    return total > 0 ? (completed / total * 100).round() : 0;
  }

  int _getTotalExperience() => _experience.length;

  Map<String, dynamic> _getSkillsData() {
    return {
      'all': _skills.map((s) => {'name': s}).toList(),
      'expert': _skills.take(3).map((s) => {'name': s}).toList(),
      'advanced': _skills.length > 3
          ? _skills.skip(3).take(3).map((s) => {'name': s}).toList()
          : [],
      'intermediate': _skills.length > 6
          ? _skills.skip(6).map((s) => {'name': s}).toList()
          : [],
    };
  }

  String _getAge() {
    if (_dateOfBirth.isNotEmpty) {
      try {
        final birth = DateTime.parse(_dateOfBirth);
        final now = DateTime.now();
        var age = now.year - birth.year;
        if (now.month < birth.month ||
            (now.month == birth.month && now.day < birth.day)) {
          age--;
        }
        return age.toString();
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  // ==================== SHOW RESUME PREVIEW ====================
  void _showResumePreview(String category) {
    if (_isDialogOpen) {
      debugPrint('⚠️ Dialog already open, skipping');
      return;
    }

    debugPrint('📄 Showing resume preview for: $category');

    final format = ResumeFormatManager.getFormatById(category.toLowerCase());
    if (format == null) {
      debugPrint('❌ Format not found: $category');
      showMessage(context, 'Format not found: $category', isError: true);
      return;
    }

    // ✅ Ensure photo URL is embedded
    _buildResumeData();

    if (_resumeData.isEmpty) {
      debugPrint('❌ Resume data is empty');
      showMessage(
          context, 'No resume data available. Please complete your profile first.',
          isError: true);
      return;
    }

    // ✅ If no photo yet, prompt upload first
    if (_effectivePhotoUrl == null || _effectivePhotoUrl!.isEmpty) {
      _showProfilePhotoDialog().then((_) {
        if (mounted) {
          _openResumePopup(format);
        }
      });
      return;
    }

    _openResumePopup(format);
  }

  void _openResumePopup(ResumeFormatBase format) {
    _isDialogOpen = true;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        _isDialogOpen = false;
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (BuildContext dialogContext) {
          return ResumeFormatPopup(
            format: format,
            resumeData: _resumeData,
            profilePhotoUrl: _effectivePhotoUrl,
            onClose: () {
              debugPrint('📄 Resume popup closed');
              _isDialogOpen = false;
            },
          );
        },
      ).then((_) {
        debugPrint('📄 Resume popup dismissed');
        _isDialogOpen = false;
      }).catchError((error) {
        debugPrint('❌ Error showing resume popup: $error');
        _isDialogOpen = false;
        if (mounted) {
          showMessage(context, 'Error showing resume preview: $error',
              isError: true);
        }
      });
    });
  }

  // ==================== ACTIONS: PRINT / DOWNLOAD / SHARE ====================

  ResumeFormatBase get _currentFormat =>
      ResumeFormatManager.getFormatById(_selectedCategory) ??
      ResumeFormatManager.defaultFormat;

  String get _fileNameBase =>
      _fullName.isNotEmpty
          ? _fullName.replaceAll(RegExp(r'[^\w]'), '_')
          : 'Resume';

  Future<bool> _ensurePhotoReady() async {
    final url = _effectivePhotoUrl;
    if (url != null && url.isNotEmpty) return true;
    await _showProfilePhotoDialog();
    return _effectivePhotoUrl != null && _effectivePhotoUrl!.isNotEmpty;
  }

  Future<void> _handlePrint() async {
    if (_isGenerating) return;

    try {
      if (_resumeData.isEmpty) {
        showMessage(context, 'No resume data available', isError: true);
        return;
      }

      if (!await _ensurePhotoReady()) return;

      _buildResumeData();

      final format = _currentFormat;
      debugPrint('🖨️ BuildResume — Print clicked → '
          'format=${format.id} styleKey=${format.styleKey} color=${format.color}');

      setState(() => _isGenerating = true);

      await ResumePdfService.print(
        data: _resumeData,
        styleKey: format.styleKey,
        colorHex: format.color,
      );

      if (mounted) {
        showMessage(context, "🖨️ Print dialog opened for ${format.name}");
      }
    } catch (e) {
      debugPrint('❌ Print failed: $e');
      if (mounted) {
        showMessage(context, "❌ Print failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleDownload() async {
    if (_isGenerating) return;

    try {
      if (_resumeData.isEmpty) {
        showMessage(context, 'No resume data available', isError: true);
        return;
      }

      if (!await _ensurePhotoReady()) return;

      _buildResumeData();

      final format = _currentFormat;
      debugPrint('📥 BuildResume — Download clicked → '
          'format=${format.id} styleKey=${format.styleKey} color=${format.color}');

      setState(() => _isGenerating = true);

      await ResumePdfService.download(
        fileNameBase: _fileNameBase,
        data: _resumeData,
        styleKey: format.styleKey,
        colorHex: format.color,
      );

      if (mounted) {
        showMessage(context, "✅ ${format.name} resume downloaded successfully");
      }
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      if (mounted) {
        showMessage(context, "❌ Download failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleShare() async {
    if (_isGenerating) return;

    try {
      if (_resumeData.isEmpty) {
        showMessage(context, 'No resume data available', isError: true);
        return;
      }

      if (!await _ensurePhotoReady()) return;

      _buildResumeData();

      final format = _currentFormat;
      debugPrint('📤 BuildResume — Share clicked → '
          'format=${format.id} styleKey=${format.styleKey} color=${format.color}');

      setState(() => _isGenerating = true);

      await ResumePdfService.share(
        fileNameBase: _fileNameBase,
        data: _resumeData,
        styleKey: format.styleKey,
        colorHex: format.color,
      );

      if (mounted) {
        showMessage(context, "📤 ${format.name} resume ready to share");
      }
    } catch (e) {
      debugPrint('❌ Share failed: $e');
      if (mounted) {
        showMessage(context, "❌ Share failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ==================== BUILD UI ====================
  @override
  Widget build(BuildContext context) {
    // ✅ Watch provider — any photo upload anywhere triggers rebuild
    context.watch<UserProfileProvider>();

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Build Resume'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load resume data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadResumeData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final formats = ResumeFormatManager.allFormats;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Build Resume'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera, color: Colors.white),
            onPressed: _showProfilePhotoDialog,
            tooltip: 'Change Profile Photo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResumeData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== PROFILE SUMMARY CARD ====================
            _buildProfileSummaryCard(),
            const SizedBox(height: 20),

            // ==================== STATS ROW ====================
            _buildStatsRow(),
            const SizedBox(height: 20),

            // ==================== RESUME FORMATS ====================
            const Text(
              'Choose Resume Format',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a format and preview your resume',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: formats.length,
              itemBuilder: (context, index) {
                final format = formats[index];
                return _buildFormatCard(format);
              },
            ),
            const SizedBox(height: 20),

            // ==================== QUICK ACTIONS ====================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentFormat.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.picture_as_pdf,
                          label: 'Download PDF',
                          color: Colors.red,
                          onTap: _isGenerating ? null : _handleDownload,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.share,
                          label: 'Share Resume',
                          color: Colors.blue,
                          onTap: _isGenerating ? null : _handleShare,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _handlePrint,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined, size: 18),
                      label: Text(
                          _isGenerating ? "Generating..." : "Print Resume"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '💡 Tip: Tap any format card above to preview that specific layout. '
                    'Quick Actions always use the last previewed format.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==================== AI LOADING SCREEN ====================
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
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 40,
                  ),
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
            Opacity(
              opacity: 0.6,
              child: const Text(
                "Please wait while we prepare your resume data",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6B80),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildProfileSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ✅ CRITICAL FIX: Wrap in ValueListenableBuilder properly
          ValueListenableBuilder<String?>(
            valueListenable: ProfileStateService().profilePhotoUrl,
            builder: (context, photoUrl, child) {
              final hasPhoto =
                  photoUrl != null && photoUrl.trim().isNotEmpty;

              return Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipOval(
                      child: hasPhoto
                          ? CachedNetworkImage(
                              key: ValueKey(photoUrl),
                              imageUrl: photoUrl,
                              width: 70,
                              height: 70,
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
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  _fullName.isNotEmpty
                                      ? _fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                _fullName.isNotEmpty
                                    ? _fullName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6C63FF),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _showProfilePhotoDialog,
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName.isNotEmpty ? _fullName : 'User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isNotEmpty ? _email : 'No email provided',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _location.isNotEmpty ? _location : 'India',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_effectivePhotoUrl == null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "⚠️ Tap camera to upload photo",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Experience',
            value: '${_experience.length} yr',
            icon: Icons.work,
            color: const Color(0xFFFF6B6B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Skills',
            value: '${_skills.length}',
            icon: Icons.build,
            color: const Color(0xFF4ECDC4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Projects',
            value: '${_projects.length}',
            icon: Icons.code,
            color: const Color(0xFF6C63FF),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard(ResumeFormatBase format) {
    final colorHex = format.color.replaceAll('#', '');
    final color = Color(int.parse('FF$colorHex', radix: 16));

    final isSelected = _selectedCategory == format.id;

    return Card(
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategory = format.id);
          debugPrint('🎯 Format selected: ${format.id} (${format.name})');
          _showResumePreview(format.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    format.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                format.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  format.badgeText.isNotEmpty ? format.badgeText : 'Preview',
                  style: TextStyle(
                    fontSize: 8,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}