// lib/features/jobs/presentation/screens/job_detail_screen.dart
// ✅ AI-BASED MODERN DESIGN – Light gradient, glass cards, brand colors
// ✅ ULTRA-FAST – Cached profile, instant load, background refresh
// ✅ AI LOADING ANIMATION with animated auto_awesome icon
// ✅ FULLY FUNCTIONAL – All original logic preserved
// ✅ FIXED: Added ALL missing widget builder methods
// ✅ FIXED: User category properly loaded and passed to payment screen
// ✅ FIXED: Disability check FIRST, then category (PWD priority)
// ✅ NEW: FULL FEE BREAKDOWN shown in Job Detail Screen
// ✅ CRITICAL FIX: Correct fee formula:
//     Subtotal = Application Fee + Service Charge
//     GST      = 18% of Subtotal
//     Total    = Subtotal + GST
//     Example: 3 + 50 = 53, GST = 10, Total = 63
// ✅ CRITICAL FIX: Sends TOTAL + breakdown to backend with use_provided_amount=true
// ✅ CRITICAL FIX: Payment screen receives EXACT SAME TOTAL as Job Detail Screen
// ✅ CRITICAL FIX: Advertisement button now shows correctly
// ✅ CRITICAL FIX: Apply With Us button now shows correctly
// ✅ CRITICAL FIX: Auto-refresh job data to ensure all fields available
// ✅ CRITICAL FIX: Better null/empty handling for all URL fields
// ✅ FIXED: ALL text colors now explicitly set for perfect visibility
// ✅ NEW: isEmbedded mode - when true, no AppBar/Scaffold, just content
// ✅ NEW: onBack callback for embedded mode
// ✅ NEW: onApplicationSubmitted callback preserved
// ✅ NEW: After payment success → shows ApplicationSuccessDialog with Application Number

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnest/features/payment/presentation/screens/payment_screen.dart';
import 'package:rojgarnest/features/payment/presentation/payment.dart'
    show PaymentType;
import 'package:rojgarnest/features/payment/presentation/widgets/application_success_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// AI SERVICE
// ============================================================
class AIJobDetailService {
  static double calculateMatchScore(
      Map<String, dynamic> job, Map<String, dynamic> userProfile) {
    if (userProfile.isEmpty) return 65 + (job['_id'].hashCode % 20);
    double score = 50;
    final userSkills = userProfile['skills'] ?? [];
    final jobSkills = job['required_skills'] ?? [];
    if (userSkills.isNotEmpty && jobSkills.isNotEmpty) {
      final matchCount = userSkills
          .where((s) => jobSkills.any((js) =>
              js['name']?.toString().toLowerCase() ==
              s.toString().toLowerCase()))
          .length;
      score += (matchCount / jobSkills.length) * 20;
    }
    final userExp = userProfile['total_experience_years'] ?? 0;
    final jobExpMin = job['experience_min_years'] ?? 0;
    final jobExpMax = job['experience_max_years'] ?? 99;
    if (userExp >= jobExpMin && userExp <= jobExpMax) score += 10;
    final userEdu =
        userProfile['highest_education']?.toString().toLowerCase() ?? '';
    final jobEdu =
        job['required_qualification']?.toString().toLowerCase() ?? '';
    if (userEdu.isNotEmpty &&
        jobEdu.isNotEmpty &&
        (jobEdu.contains(userEdu) || userEdu.contains(jobEdu))) {
      score += 10;
    }
    return score.clamp(30, 98).toDouble();
  }

  static List<String> getInsights(Map<String, dynamic> job) {
    List<String> insights = [];
    if (job['salary_min'] != null && job['salary_max'] != null) {
      final avg = (job['salary_min'] + job['salary_max']) ~/ 2;
      insights.add("💰 ₹${(avg / 100000).toStringAsFixed(1)}L avg salary");
    }
    if (job['experience_min_years'] != null &&
        job['experience_max_years'] != null) {
      insights.add(
          "🎓 ${job['experience_min_years']}-${job['experience_max_years']} yrs exp");
    }
    if (job['total_posts'] != null) {
      insights.add("👥 ${job['total_posts']} vacancies");
    }
    if (job['required_skills'] != null &&
        (job['required_skills'] as List).isNotEmpty) {
      insights.add("🛠️ ${(job['required_skills'] as List).length} skills");
    }
    if (job['benefits'] != null && (job['benefits'] as List).isNotEmpty) {
      insights.add("🎁 ${(job['benefits'] as List).length} benefits");
    }
    if (job['is_fully_remote'] == true) {
      insights.add("🏠 Remote");
    } else if (job['is_hybrid'] == true) {
      insights.add("🔄 Hybrid");
    }
    return insights;
  }
}

// ============================================================
// FEE BREAKDOWN MODEL
// ✅ CORRECT FORMULA:
//    Subtotal = Application Fee + Service Charge
//    GST      = 18% of Subtotal
//    Total    = Subtotal + GST
// ============================================================
class FeeBreakdown {
  final int applicationFee;
  final int serviceCharge;
  final int subtotal;
  final int gstAmount;
  final int totalFee;

  FeeBreakdown({
    required this.applicationFee,
    required this.serviceCharge,
    required this.subtotal,
    required this.gstAmount,
    required this.totalFee,
  });

  factory FeeBreakdown.calculate({
    required int applicationFee,
    double gstPercent = 18.0,
    int serviceCharge = 50,
  }) {
    final int subtotal = applicationFee + serviceCharge;
    final int gstAmount = ((subtotal * gstPercent) / 100).round();
    final int totalFee = subtotal + gstAmount;

    return FeeBreakdown(
      applicationFee: applicationFee,
      serviceCharge: serviceCharge,
      subtotal: subtotal,
      gstAmount: gstAmount,
      totalFee: totalFee,
    );
  }

  @override
  String toString() {
    return 'FeeBreakdown(app: ₹$applicationFee, service: ₹$serviceCharge, '
        'subtotal: ₹$subtotal, gst: ₹$gstAmount, total: ₹$totalFee)';
  }
}

// ============================================================
// FILE TYPE DETECTOR
// ============================================================
class _JobFileTypeDetector {
  static const Set<String> imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'wbmp', 'ico', 'tiff', 'tif', 'svg',
  };
  static const Set<String> pdfExtensions = {'pdf'};

  static String getExtension(String urlOrName) {
    if (urlOrName.isEmpty) return '';
    try {
      final clean = urlOrName.split('?').first.split('#').first;
      final segments = clean.split('/');
      final last = segments.isNotEmpty ? segments.last : clean;
      if (last.contains('.')) {
        return last.split('.').last.toLowerCase().trim();
      }
    } catch (e) {
      debugPrint('Extension parse error: $e');
    }
    return '';
  }

  static bool isPdf(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (explicitType != null) {
      final t = explicitType.toLowerCase();
      if (t == 'pdf' || t.contains('pdf')) return true;
    }
    final ext = getExtension(url);
    if (pdfExtensions.contains(ext)) return true;
    if (lower.contains('/raw/upload/')) return true;
    if (lower.contains('/raw/authenticated/')) return true;
    if (lower.contains('.pdf')) return true;
    if (lower.contains('application/pdf')) return true;
    if (lower.contains('/pdf/')) return true;
    if (lower.contains('type=pdf')) return true;
    if (lower.contains('format=pdf')) return true;
    if (lower.contains('docs.google.com') && lower.contains('export=pdf')) {
      return true;
    }
    return false;
  }

  static bool isImage(String url, {String? explicitType}) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (explicitType != null) {
      final t = explicitType.toLowerCase();
      if (t == 'image' || t.contains('image')) return true;
    }
    final ext = getExtension(url);
    if (imageExtensions.contains(ext)) return true;
    if (isPdf(url, explicitType: explicitType)) return false;
    if (lower.contains('cloudinary.com') &&
        (lower.contains('/image/upload/') ||
         lower.contains('/image/authenticated/'))) {
      return true;
    }
    if (lower.contains('image/')) return true;
    if (lower.contains('img/')) return true;
    if (lower.contains('photo/')) return true;
    if (lower.contains('picture/')) return true;
    return false;
  }

  static bool isGoogleDrive(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('drive.google.com') ||
        lower.contains('docs.google.com');
  }

  static String detectFileType(String url, {String? explicitType}) {
    if (url.isEmpty) return 'unknown';
    if (isPdf(url, explicitType: explicitType)) return 'pdf';
    if (isImage(url, explicitType: explicitType)) return 'image';
    if (isGoogleDrive(url)) return 'gdrive';
    final ext = getExtension(url);
    if (ext.isNotEmpty) {
      switch (ext) {
        case 'doc':
        case 'docx':
          return 'word';
        case 'xls':
        case 'xlsx':
          return 'excel';
        case 'ppt':
        case 'pptx':
          return 'powerpoint';
        case 'txt':
        case 'log':
        case 'md':
        case 'json':
        case 'xml':
          return 'text';
        case 'mp4':
        case 'avi':
        case 'mkv':
        case 'mov':
          return 'video';
        case 'mp3':
        case 'wav':
        case 'aac':
          return 'audio';
        default:
          return ext;
      }
    }
    return 'unknown';
  }
}

// ============================================================
// MAIN SCREEN
// ✅ NEW: isEmbedded mode
// ✅ NEW: onBack callback
// ============================================================
class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onBack;
  final VoidCallback? onApplicationSubmitted;

  /// ✅ NEW: When true, renders WITHOUT Scaffold/AppBar
  /// so it can be embedded in the right panel of UserDashboard.
  final bool isEmbedded;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.onBack,
    this.onApplicationSubmitted,
    this.isEmbedded = false,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // STATE VARIABLES
  // ============================================================
  bool _isApplyingOnWebsite = false;
  bool _isApplyingWithUs = false;
  bool _isSaved = false;
  bool _hasApplied = false;
  bool _isCheckingApplied = true;
  bool _isPaymentProcessing = false;
  bool _isRefreshingJobData = false;

  String? _officialNotificationUrl;
  String? _advertisementUrl;
  String? _advertisementDownloadUrl;
  bool _hasOfficialNotification = false;
  bool _hasAdvertisement = false;
  bool _isOfficialNotificationPdf = false;
  bool _isAdvertisementPdf = false;
  bool _isImageFile = false;
  bool _isGoogleDriveLink = false;
  bool _isPrivateCloudinaryFile = false;

  bool _hasApplyWithUs = false;
  String? _applyWithUsUrl;

  String? _userCategory;
  bool _isLoadingCategory = true;
  String? _userCategoryDisplayName;

  bool _isDisabled = false;
  String? _disabilityPercentage;
  String? _disabilityCategory;
  bool _isLoadingDisability = true;

  double _matchScore = 0.0;
  List<String> _insights = [];
  Map<String, dynamic> _userProfile = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const double GST_PERCENT = 18.0;
  static const int SERVICE_CHARGE = 50;

  // ============================================================
  // COLOR CONSTANTS
  // ============================================================
  static const Color _kTextPrimary = Color(0xFF111827);
  static const Color _kTextSecondary = Color(0xFF374151);
  static const Color _kTextMuted = Color(0xFF6B7280);
  static const Color _kPrimary = Color(0xFF6C63FF);
  static const Color _kPink = Color(0xFFFF6588);
  static const Color _kBackgroundLight = Color(0xFFF5F7FA);
  static const Color _kBackgroundLighter = Color(0xFFE8ECF1);
  static const Color _kCardWhite = Colors.white;
  static const Color _kBorderLight = Color(0xFFE5E7EB);

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _loadNotificationData();
    _refreshJobData();
    _loadUserProfile();
    _checkIfAlreadyApplied();
    _checkIfSaved();
    _loadUserProfileData();

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ============================================================
  // REFRESH JOB DATA
  // ============================================================
  Future<void> _refreshJobData() async {
    final jobId = widget.job['_id']?.toString();
    if (jobId == null || jobId.isEmpty) {
      debugPrint("⚠️ _refreshJobData: No job ID");
      return;
    }
    if (_isRefreshingJobData) return;
    _isRefreshingJobData = true;
    try {
      final response = await DioClient.dio.get('/jobs/$jobId');
      if (!mounted) return;
      Map<String, dynamic> freshJob = {};
      if (response.data is Map) {
        if (response.data.containsKey('data') && response.data['data'] is Map) {
          freshJob = Map<String, dynamic>.from(response.data['data']);
        } else {
          freshJob = Map<String, dynamic>.from(response.data);
        }
      }
      if (freshJob.isNotEmpty) {
        widget.job.addAll(freshJob);
        _loadNotificationData();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("⚠️ Failed to refresh job data: $e");
    } finally {
      _isRefreshingJobData = false;
    }
  }

  // ============================================================
  // LOAD NOTIFICATION DATA
  // ============================================================
  void _loadNotificationData() {
    final job = widget.job;
    _hasOfficialNotification = false;
    _hasAdvertisement = false;
    _hasApplyWithUs = false;
    _officialNotificationUrl = null;
    _advertisementUrl = null;
    _advertisementDownloadUrl = null;
    _applyWithUsUrl = null;
    _isAdvertisementPdf = false;
    _isImageFile = false;
    _isGoogleDriveLink = false;
    _isPrivateCloudinaryFile = false;

    String? officialUrl = job['official_notification_url']?.toString();
    if (officialUrl == null || officialUrl.trim().isEmpty) {
      officialUrl = job['official_notification_link']?.toString();
    }
    if (_isValidUrl(officialUrl)) {
      _officialNotificationUrl = officialUrl!.trim();
      _hasOfficialNotification = true;
      _isOfficialNotificationPdf = _JobFileTypeDetector.isPdf(
        _officialNotificationUrl!,
        explicitType: 'pdf',
      );
    }

    String? advUrl = job['advertisement_url']?.toString();
    if (_isValidUrl(advUrl)) {
      _advertisementUrl = advUrl!.trim();
      _hasAdvertisement = true;
      final downloadUrl = job['advertisement_download_url']?.toString();
      if (_isValidUrl(downloadUrl)) {
        _advertisementDownloadUrl = downloadUrl!.trim();
      }
      _isPrivateCloudinaryFile = job['advertisement_is_public'] == false &&
          _advertisementUrl!.contains('cloudinary.com');
      if (job['advertisement_is_pdf'] == true) {
        _isAdvertisementPdf = true;
      } else {
        _isAdvertisementPdf = _JobFileTypeDetector.isPdf(_advertisementUrl!);
      }
      _isImageFile = _JobFileTypeDetector.isImage(_advertisementUrl!);
      _isGoogleDriveLink = _JobFileTypeDetector.isGoogleDrive(_advertisementUrl!);
    }

    String? applyUrl = job['apply_with_us_url']?.toString();
    final hasApplyFlag = job['has_apply_with_us'] == true;
    if (_isValidUrl(applyUrl)) {
      _applyWithUsUrl = applyUrl!.trim();
      _hasApplyWithUs = true;
    } else if (hasApplyFlag) {
      final applyLink = job['apply_link']?.toString();
      if (_isValidUrl(applyLink)) {
        _applyWithUsUrl = applyLink!.trim();
        _hasApplyWithUs = true;
      }
    } else {
      final applyLink = job['apply_link']?.toString();
      if (_isValidUrl(applyLink)) {
        _applyWithUsUrl = applyLink!.trim();
        _hasApplyWithUs = true;
      }
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed == '#') return false;
    if (trimmed.toLowerCase() == 'null') return false;
    if (trimmed.toLowerCase() == 'undefined') return false;
    if (trimmed.toLowerCase() == 'n/a') return false;
    if (trimmed.toLowerCase() == 'na') return false;
    if (trimmed.toLowerCase() == 'none') return false;
    if (trimmed.toLowerCase() == '-') return false;
    if (trimmed.length < 5) return false;
    return true;
  }

  // ============================================================
  // LOAD USER PROFILE
  // ============================================================
  Future<void> _loadUserProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCategory = true;
      _isLoadingDisability = true;
    });
    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _isDisabled = false;
            _userCategory = 'general/ur';
            _userCategoryDisplayName = 'General/UR';
            _isLoadingCategory = false;
            _isLoadingDisability = false;
          });
        }
        return;
      }
      final response = await DioClient.dio.get('/user/full-profile');
      if (!mounted) return;
      Map<String, dynamic> profile = {};
      if (response.data is Map) {
        if (response.data.containsKey('data') && response.data['data'] is Map) {
          profile = response.data['data'] as Map<String, dynamic>;
        } else {
          profile = response.data as Map<String, dynamic>;
        }
      }

      bool isDisabled = false;
      String? disabilityPercentage;
      String? disabilityCategory;

      final disabilityObj = profile['disability'] as Map<String, dynamic>?;
      if (disabilityObj != null) {
        final isDisabledValue = disabilityObj['is_disabled'];
        if (isDisabledValue is bool) {
          isDisabled = isDisabledValue;
        } else if (isDisabledValue is String) {
          isDisabled = isDisabledValue.toLowerCase() == 'true' ||
              isDisabledValue == 'yes';
        } else if (isDisabledValue is int) {
          isDisabled = isDisabledValue == 1;
        }
        disabilityPercentage =
            disabilityObj['disability_percentage']?.toString();
        disabilityCategory = disabilityObj['disability_category']?.toString();
      }

      if (!isDisabled) {
        final isDisableTop = profile['is_disable'];
        if (isDisableTop is bool) {
          isDisabled = isDisableTop;
        } else if (isDisableTop is String) {
          isDisabled =
              isDisableTop.toLowerCase() == 'true' || isDisableTop == 'yes';
        } else if (isDisableTop is int) {
          isDisabled = isDisableTop == 1;
        }
        if (disabilityPercentage == null) {
          disabilityPercentage = profile['disability_percentage']?.toString();
        }
        if (disabilityCategory == null) {
          disabilityCategory = profile['disability_category']?.toString();
        }
      }

      String? category = profile['category']?.toString();
      if (category == null || category.isEmpty) {
        final basicDetails = profile['basic_details'] as Map<String, dynamic>?;
        if (basicDetails != null) {
          category = basicDetails['category']?.toString();
        }
      }
      if (category == null || category.isEmpty) {
        final personalInfo = profile['personal_info'] as Map<String, dynamic>?;
        if (personalInfo != null) {
          category = personalInfo['category']?.toString();
        }
      }

      String normalizedCategory = _normalizeCategory(category);
      String displayName = _getCategoryDisplayName(category);

      if (mounted) {
        setState(() {
          _isDisabled = isDisabled;
          _disabilityPercentage = disabilityPercentage;
          _disabilityCategory = disabilityCategory;
          _userCategory = normalizedCategory;
          _userCategoryDisplayName = displayName;
          _isLoadingCategory = false;
          _isLoadingDisability = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading user profile data: $e");
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _userCategory = 'general/ur';
          _userCategoryDisplayName = 'General/UR';
          _isLoadingCategory = false;
          _isLoadingDisability = false;
        });
      }
    }
  }

  String _normalizeCategory(String? category) {
    if (category == null || category.isEmpty) return 'general/ur';
    final lowerCategory = category.toLowerCase().trim();
    if (lowerCategory.contains('general') ||
        lowerCategory == 'ur' ||
        lowerCategory == 'unreserved') {
      return 'general/ur';
    }
    if (lowerCategory.contains('obc')) return 'obc';
    if (lowerCategory.contains('sc') && !lowerCategory.contains('scheduled')) {
      return 'sc';
    }
    if (lowerCategory.contains('st') && !lowerCategory.contains('scheduled')) {
      return 'st';
    }
    if (lowerCategory.contains('ews')) return 'ews';
    if (lowerCategory.contains('pwd') ||
        lowerCategory.contains('ph') ||
        lowerCategory.contains('disabled')) {
      return 'pwd';
    }
    if (lowerCategory.contains('female') || lowerCategory.contains('woman')) {
      return 'female';
    }
    if (lowerCategory.contains('esm') ||
        lowerCategory.contains('ex-serviceman')) {
      return 'esm';
    }
    return 'general/ur';
  }

  String _getCategoryDisplayName(String? category) {
    if (category == null || category.isEmpty) return 'General/UR';
    final lowerCategory = category.toLowerCase().trim();
    if (lowerCategory.contains('general') || lowerCategory == 'ur') {
      return 'General/UR';
    }
    if (lowerCategory.contains('obc')) return 'OBC';
    if (lowerCategory.contains('sc')) return 'SC';
    if (lowerCategory.contains('st')) return 'ST';
    if (lowerCategory.contains('ews')) return 'EWS';
    if (lowerCategory.contains('pwd') || lowerCategory.contains('ph')) {
      return 'PWD';
    }
    if (lowerCategory.contains('female')) return 'Female';
    if (lowerCategory.contains('esm')) return 'ESM';
    return category;
  }

  Future<void> _loadUserProfile() async {
    try {
      final token = await SecureStorage.getToken();
      if (token != null) {
        final response = await DioClient.dio.get('/user/full-profile');
        if (response.data is Map) {
          final data = response.data;
          if (data.containsKey('data') && data['data'] is Map) {
            _userProfile = data['data'];
            _matchScore = AIJobDetailService.calculateMatchScore(
                widget.job, _userProfile);
            _insights = AIJobDetailService.getInsights(widget.job);
            if (mounted) setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile for AI: $e');
    }
  }

  Future<void> _checkIfAlreadyApplied() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _hasApplied = false;
          _isCheckingApplied = false;
        });
      }
      return;
    }
    try {
      final response = await DioClient.dio.get('/jobs/my-applications');
      if (!mounted) return;
      final applications = response.data['applications'] ?? [];
      final jobId = widget.job['_id'].toString();
      final alreadyApplied = applications.any((app) {
        final appJobId = app['job_id']?.toString() ?? '';
        return appJobId == jobId;
      });
      if (mounted) {
        setState(() {
          _hasApplied = alreadyApplied;
          _isCheckingApplied = false;
        });
      }
    } catch (e) {
      debugPrint('Check applied error: $e');
      if (mounted) {
        setState(() {
          _hasApplied = false;
          _isCheckingApplied = false;
        });
      }
    }
  }

  Future<void> _checkIfSaved() async {
    final token = await SecureStorage.getToken();
    if (token == null) return;
    try {
      final response = await DioClient.dio.get('/jobs/my-applications');
      if (mounted) {
        final savedApps = response.data['applications'] ?? [];
        setState(() {
          _isSaved = savedApps.any((app) => app['job_id'] == widget.job['_id']);
        });
      }
    } catch (e) {
      debugPrint('Check saved error: $e');
    }
  }

  // ============================================================
  // FEE HELPERS
  // ============================================================
  String _getEffectivePaymentCategory() {
    if (_isDisabled) return 'pwd';
    return _userCategory ?? 'general/ur';
  }

  String _getEffectivePaymentCategoryDisplay() {
    if (_isDisabled) return 'PWD (Disabled)';
    return _userCategoryDisplayName ?? 'General/UR';
  }

  bool _isPayingAsPwd() => _isDisabled;

  int _getCategoryFee(Map<String, dynamic> fees) {
    if (fees == null || fees.isEmpty) return 0;
    final effectiveCategory = _getEffectivePaymentCategory();
    int? fee;

    if (fees.containsKey(effectiveCategory)) {
      final value = fees[effectiveCategory];
      if (value is int) {
        fee = value;
      } else if (value is String) {
        fee = int.tryParse(value);
      }
    }

    if (fee == null || fee <= 0) {
      final alternativeKeys = _getAlternativeFeeKeys(effectiveCategory);
      for (final altKey in alternativeKeys) {
        if (fees.containsKey(altKey)) {
          final value = fees[altKey];
          if (value is int) {
            fee = value;
          } else if (value is String) {
            fee = int.tryParse(value);
          }
          if (fee != null && fee > 0) break;
        }
      }
    }

    if ((fee == null || fee <= 0) && _isDisabled) {
      final fallbackCategory = _userCategory ?? 'general/ur';
      if (fees.containsKey(fallbackCategory)) {
        final value = fees[fallbackCategory];
        if (value is int) {
          fee = value;
        } else if (value is String) {
          fee = int.tryParse(value);
        }
      }
      if (fee == null || fee <= 0) {
        final altKeys = _getAlternativeFeeKeys(fallbackCategory);
        for (final altKey in altKeys) {
          if (fees.containsKey(altKey)) {
            final value = fees[altKey];
            if (value is int) {
              fee = value;
            } else if (value is String) {
              fee = int.tryParse(value);
            }
            if (fee != null && fee > 0) break;
          }
        }
      }
    }

    if (fee == null || fee <= 0) {
      final generalValue = fees['general/ur'] ??
          fees['general'] ??
          fees['general_ur'] ??
          fees['ur'];
      if (generalValue is int) {
        fee = generalValue;
      } else if (generalValue is String) {
        fee = int.tryParse(generalValue);
      }
    }

    return (fee != null && fee > 0) ? fee : 0;
  }

  List<String> _getAlternativeFeeKeys(String category) {
    switch (category.toLowerCase()) {
      case 'general/ur':
        return ['general', 'ur', 'general_ur', 'unreserved', 'open'];
      case 'obc':
        return ['obc', 'other_backward', 'other_backward_class', 'obc_ncl'];
      case 'sc':
        return ['sc', 'scheduled_caste', 'scheduled caste', 'scheduledcaste'];
      case 'st':
        return ['st', 'scheduled_tribe', 'scheduled tribe', 'scheduledtribe'];
      case 'ews':
        return [
          'ews',
          'economically_weaker',
          'economically_weaker_section',
          'economicallyweakersection'
        ];
      case 'pwd':
        return [
          'pwd',
          'ph',
          'physically_handicapped',
          'disabled',
          'divyangjan',
          'physically_challenged',
          'handicapped',
          'differently_abled',
          'person_with_disability',
          'disability'
        ];
      case 'female':
        return ['female', 'women', 'woman', 'girl'];
      case 'esm':
        return [
          'esm',
          'ex_serviceman',
          'ex-serviceman',
          'exserviceman',
          'ex_service'
        ];
      default:
        return ['general/ur', 'general', 'ur'];
    }
  }

  /// ✅ CORRECT FEE FORMULA:
  ///   Subtotal = Application Fee + Service Charge
  ///   GST      = 18% of Subtotal
  ///   Total    = Subtotal + GST
  /// Example: 3 + 50 = 53, GST = 10, Total = 63
  FeeBreakdown _calculateFeeBreakdown() {
    final hasFees = _hasApplicationFees();
    final fees = _getApplicationFees();
    final applicationFee = hasFees ? _getCategoryFee(fees) : 0;

    if (applicationFee <= 0) {
      final subtotal = SERVICE_CHARGE;
      final gstAmount = ((subtotal * GST_PERCENT) / 100).round();
      return FeeBreakdown(
        applicationFee: 0,
        serviceCharge: SERVICE_CHARGE,
        subtotal: subtotal,
        gstAmount: gstAmount,
        totalFee: subtotal + gstAmount,
      );
    }

    return FeeBreakdown.calculate(
      applicationFee: applicationFee,
      gstPercent: GST_PERCENT,
      serviceCharge: SERVICE_CHARGE,
    );
  }

  // ============================================================
  // DATE FORMATTERS
  // ============================================================
  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatPostedDate() {
    final postDate = widget.job['post_date'];
    if (postDate != null && postDate.toString().isNotEmpty) {
      return _formatDate(postDate);
    }
    final createdAt = widget.job['created_at'];
    if (createdAt != null && createdAt.toString().isNotEmpty) {
      return _formatDate(createdAt);
    }
    return 'Recently';
  }

  // ============================================================
  // GETTER METHODS
  // ============================================================
  String _getJobLocation() {
    final jobLoc = widget.job['job_location'];
    if (jobLoc != null && jobLoc['location_name'] != null) {
      return jobLoc['location_name'].toString();
    }
    if (widget.job['location'] != null &&
        widget.job['location'].toString().isNotEmpty) {
      return widget.job['location'].toString();
    }
    return 'Not specified';
  }

  String _getSalaryDisplay() {
    final minSal = widget.job['salary_min'];
    final maxSal = widget.job['salary_max'];
    if (minSal != null && maxSal != null) {
      return "₹${minSal ~/ 100000}-${maxSal ~/ 100000} LPA";
    }
    if (minSal != null) return "From ₹${minSal ~/ 100000} LPA";
    if (maxSal != null) return "Up to ₹${maxSal ~/ 100000} LPA";
    return 'Not disclosed';
  }

  String _getLastDate() {
    final lastDate = widget.job['last_date'];
    if (lastDate != null && lastDate.toString().isNotEmpty) {
      return _formatDate(lastDate);
    }
    return '';
  }

  String _getApplicationStartDate() {
    if (widget.job['application_start_date'] != null &&
        widget.job['application_start_date'].toString().isNotEmpty) {
      return _formatDate(widget.job['application_start_date']);
    }
    return '';
  }

  String _getApplicationEndDate() {
    if (widget.job['application_end_date'] != null &&
        widget.job['application_end_date'].toString().isNotEmpty) {
      return _formatDate(widget.job['application_end_date']);
    }
    return '';
  }

  String _getQualificationDisplay() {
    final reqQual = widget.job['required_qualification'];
    if (reqQual != null && reqQual.toString().isNotEmpty) {
      return reqQual.toString();
    }
    final qualification = widget.job['qualification'];
    if (qualification != null && qualification.toString().isNotEmpty) {
      return qualification.toString();
    }
    return 'Any Graduate';
  }

  String _getExperience() {
    final minExp = widget.job['experience_min_years'];
    final maxExp = widget.job['experience_max_years'];
    if (minExp != null && maxExp != null) return '$minExp - $maxExp years';
    if (minExp != null) return '$minExp+ years';
    return 'Fresher';
  }

  String _getAgeLimit() {
    final minAge = widget.job['age_min_years'];
    final maxAge = widget.job['age_max_years'];
    if (minAge != null && maxAge != null) return '$minAge - $maxAge years';
    if (minAge != null) return '$minAge+ years';
    if (maxAge != null) return 'Up to $maxAge years';
    return 'Not specified';
  }

  String _getTotalVacancies() {
    if (widget.job['total_posts'] != null) {
      return widget.job['total_posts'].toString();
    }
    return 'Not specified';
  }

  String _getApplicationMode() {
    if (widget.job['application_mode'] != null &&
        widget.job['application_mode'].toString().isNotEmpty) {
      return widget.job['application_mode'].toString();
    }
    return 'Online';
  }

  String _getGenderPreference() {
    if (widget.job['gender_preference'] != null &&
        widget.job['gender_preference'].toString().isNotEmpty) {
      return widget.job['gender_preference'].toString();
    }
    return 'Any';
  }

  String _getWorkSchedule() {
    if (widget.job['work_schedule'] != null &&
        widget.job['work_schedule'].toString().isNotEmpty) {
      return widget.job['work_schedule'].toString();
    }
    return 'Full Time';
  }

  String _getShift() {
    if (widget.job['shift'] != null &&
        widget.job['shift'].toString().isNotEmpty) {
      return widget.job['shift'].toString();
    }
    return 'Day Shift';
  }

  String _getWorkingDays() {
    if (widget.job['working_days'] != null &&
        widget.job['working_days'].toString().isNotEmpty) {
      return widget.job['working_days'].toString();
    }
    return 'Monday to Friday';
  }

  String _getJobLevel() {
    if (widget.job['job_level'] != null &&
        widget.job['job_level'].toString().isNotEmpty) {
      return widget.job['job_level'].toString().toUpperCase();
    }
    return 'MID';
  }

  String _getCategory() {
    if (widget.job['category'] != null &&
        widget.job['category'].toString().isNotEmpty) {
      return widget.job['category'].toString();
    }
    return 'General';
  }

  String _getUrgencyLevel() {
    if (widget.job['urgency_level'] != null &&
        widget.job['urgency_level'].toString().isNotEmpty) {
      return widget.job['urgency_level'].toString();
    }
    return 'Normal';
  }

  bool _hasValidWebsiteUrl() {
    final websiteUrl = widget.job['website_url'];
    if (websiteUrl != null &&
        websiteUrl.toString().isNotEmpty &&
        websiteUrl.toString().trim() != '#' &&
        websiteUrl.toString().trim() != '' &&
        websiteUrl.toString().trim().toLowerCase() != 'null') {
      return true;
    }
    return false;
  }

  bool _hasApplyWithUsLink() {
    return _hasApplyWithUs &&
        _applyWithUsUrl != null &&
        _applyWithUsUrl!.isNotEmpty;
  }

  String _getWebsiteUrl() {
    final websiteUrl = widget.job['website_url'];
    if (websiteUrl != null &&
        websiteUrl.toString().isNotEmpty &&
        websiteUrl.toString().trim() != '#') {
      return websiteUrl.toString().trim();
    }
    return '';
  }

  bool _hasApplicationFees() {
    return widget.job['has_application_fees'] == true &&
        widget.job['application_fees'] != null &&
        (widget.job['application_fees'] as Map).isNotEmpty;
  }

  Map<String, dynamic> _getApplicationFees() {
    if (_hasApplicationFees()) {
      return Map<String, dynamic>.from(widget.job['application_fees']);
    }
    return {};
  }

  bool _hasAnyNotification() {
    return _hasOfficialNotification || _hasAdvertisement;
  }

  Color _getJobTypeColor(String? type) {
    switch (type) {
      case 'private':
        return const Color(0xFF6C63FF);
      case 'remote':
        return Colors.purple;
      case 'government':
        return Colors.green;
      case 'hybrid':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getJobTypeIcon(String? type) {
    switch (type) {
      case 'private':
        return Icons.business_center;
      case 'remote':
        return Icons.wifi;
      case 'government':
        return Icons.account_balance;
      case 'hybrid':
        return Icons.sync;
      default:
        return Icons.work;
    }
  }

  IconData _getAdvertisementIcon() {
    if (_isAdvertisementPdf) return Icons.picture_as_pdf;
    if (_isImageFile) return Icons.image;
    if (_isGoogleDriveLink) return Icons.cloud_queue;
    if (_isPrivateCloudinaryFile) return Icons.lock;
    return Icons.link;
  }

  String _getAdvertisementSubtitle() {
    if (_isAdvertisementPdf) return "PDF Document - Click to view";
    if (_isImageFile) return "Image File - Click to view";
    if (_isGoogleDriveLink) return "Google Drive Link - Click to open";
    if (_isPrivateCloudinaryFile) return "🔒 Secure PDF - Private Document";
    return "External Link - Click to open";
  }

  String _getAdvertisementButtonText() {
    if (_isAdvertisementPdf) return "View Advertisement PDF";
    if (_isImageFile) return "View Advertisement Image";
    if (_isGoogleDriveLink) return "Open Google Drive Link";
    if (_isPrivateCloudinaryFile) return "Open Secure PDF";
    return "Open Advertisement Link";
  }

  List<dynamic> _getMultiplePosts() {
    final posts = widget.job['multiple_posts'];
    if (posts != null && posts is List) return posts;
    return [];
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _applyOnWebsite() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _showSnackBar("Please login to apply", isError: true);
      return;
    }
    setState(() => _isApplyingOnWebsite = true);
    try {
      String applyUrl = _getWebsiteUrl();
      if (applyUrl.isEmpty) {
        _showSnackBar("Apply link not available", isError: true);
        return;
      }
      if (!applyUrl.startsWith('http')) {
        applyUrl = 'https://$applyUrl';
      }
      final Uri url = Uri.parse(applyUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _showSnackBar("Opening application page...");
      } else {
        _showSnackBar("Could not open link", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => _isApplyingOnWebsite = false);
    }
  }

  // ============================================================
  // ✅ CRITICAL FIX: Send TOTAL + breakdown + flag to backend
  // ✅ Payment screen shows EXACT SAME amount
  // ✅ NEW: After payment success → shows ApplicationSuccessDialog
  // ============================================================
  Future<void> _applyWithUs() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _showSnackBar("Please login to apply", isError: true);
      return;
    }
    if (_hasApplied) {
      _showSnackBar("⚠️ Already applied", isError: true);
      return;
    }
    if (_isPaymentProcessing) return;

    setState(() {
      _isApplyingWithUs = true;
      _isPaymentProcessing = true;
    });

    try {
      final jobId = widget.job['_id'].toString();

      // Double-check already applied
      try {
        final checkResponse = await DioClient.dio.get('/jobs/my-applications');
        if (checkResponse.data is Map) {
          final applications = checkResponse.data['applications'] ?? [];
          final alreadyApplied = applications.any(
            (app) => app['job_id'].toString() == jobId,
          );
          if (alreadyApplied) {
            if (mounted) {
              setState(() => _hasApplied = true);
              _showSnackBar("Already applied", isError: true);
            }
            return;
          }
        }
      } catch (e) {
        debugPrint("Error checking application status: $e");
      }

      final feeBreakdown = _calculateFeeBreakdown();

      if (feeBreakdown.applicationFee <= 0) {
        _showSnackBar("Invalid fee amount", isError: true);
        return;
      }

      final categoryKey = _getEffectivePaymentCategory();

      // ============================================================
      // ✅ STEP 1: Create Razorpay order
      // ✅ Send TOTAL as amount + full breakdown + use_provided_amount flag
      // Backend MUST use `amount` directly (no recalc)
      // ============================================================
      debugPrint("=" * 70);
      debugPrint("📤 Creating Razorpay order");
      debugPrint("   Application Fee: ₹${feeBreakdown.applicationFee}");
      debugPrint("   Service Charge:  ₹${feeBreakdown.serviceCharge}");
      debugPrint("   Subtotal:        ₹${feeBreakdown.subtotal}");
      debugPrint("   GST (18%):       ₹${feeBreakdown.gstAmount}");
      debugPrint("   TOTAL (sent):    ₹${feeBreakdown.totalFee}");
      debugPrint("=" * 70);

      final orderResponse = await DioClient.dio.post(
        '/payment/razorpay/create-order',
        data: {
          // ✅ Send TOTAL — backend must use this directly
          "amount": feeBreakdown.totalFee,

          // ✅ Send breakdown so backend can log/validate/store
          "application_fee": feeBreakdown.applicationFee,
          "service_charge": feeBreakdown.serviceCharge,
          "subtotal": feeBreakdown.subtotal,
          "gst_amount": feeBreakdown.gstAmount,
          "total_amount": feeBreakdown.totalFee,

          // ✅ Tell backend NOT to recalculate
          "use_provided_amount": true,

          "payment_type": "job",
          "job_id": jobId,
          "job_title": widget.job['post_name'] ?? 'Job',
          "organization": widget.job['organization'] ?? 'Company',
          "category_used": categoryKey,
        },
      );

      if (!mounted) return;
      setState(() => _isApplyingWithUs = false);

      final responseData = orderResponse.data;
      final orderId = responseData['order_id'] ?? '';
      final keyId = responseData['key_id'] ?? '';

      // ✅ Prefer backend's echo of amount; if backend still returns different,
      // use OUR computed total so UI is consistent
      final dynamic backendAmount = responseData['amount'];
      final int backendTotal = backendAmount is int
          ? backendAmount
          : (backendAmount is num
              ? backendAmount.toInt()
              : feeBreakdown.totalFee);

      debugPrint("✅ Order created: $orderId");
      debugPrint("   Backend returned amount: ₹$backendTotal");
      debugPrint("   Frontend computed total: ₹${feeBreakdown.totalFee}");

      // ⚠️ Warn if backend added extra
      if (backendTotal != feeBreakdown.totalFee) {
        debugPrint("⚠️⚠️ BACKEND MISMATCH: backend=₹$backendTotal, "
            "frontend=₹${feeBreakdown.totalFee}");
        debugPrint("⚠️ Backend is still recalculating! "
            "Fix backend to use provided amount.");
      }

      if (orderId.isEmpty || keyId.isEmpty) {
        _showSnackBar("Payment order failed", isError: true);
        return;
      }

      // ============================================================
      // ✅ STEP 2: Show Payment Screen with FRONTEND total
      //    (so user always sees the same amount they saw in Job Detail)
      //    ✅ NEW: Now returns Map<String, dynamic>? instead of bool?
      // ============================================================
      final paymentResult = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PaymentScreen(
          jobId: jobId,
          jobTitle: widget.job['post_name'] ?? 'Job',
          organization: widget.job['organization'] ?? 'Company',

          // ✅ Use frontend total — always matches Job Detail screen
          amount: feeBreakdown.totalFee,

          categoryUsed: categoryKey,
          paymentId: orderId,
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          onPaymentSuccess: () {
            if (mounted) setState(() => _hasApplied = true);
            if (widget.onApplicationSubmitted != null) {
              widget.onApplicationSubmitted!();
            }
          },
          paymentType: PaymentType.job,
        ),
      );

      if (!mounted) return;

      if (paymentResult != null && paymentResult['success'] == true) {
        debugPrint("✅ Payment successful");

        // ✅ Refresh already-applied state
        await _checkIfAlreadyApplied();

        if (!mounted) return;

        // ✅ NEW: Show full success dialog with Application Number
        final appNumber =
            (paymentResult['application_number'] ?? '').toString();
        await ApplicationSuccessDialog.show(
          context,
          applicationNumber: appNumber.isEmpty ? 'N/A' : appNumber,
          title: widget.job['post_name'] ?? 'Job',
          subtitle: widget.job['organization'] ?? '',
          paymentType: 'Job',
          amountPaid: feeBreakdown.totalFee,
          paymentId: paymentResult['payment_id']?.toString(),
          status: paymentResult['status']?.toString(),
        );

        if (widget.onApplicationSubmitted != null) {
          widget.onApplicationSubmitted!();
        }
      } else if (mounted) {
        debugPrint("❌ Payment cancelled");
        _showSnackBar(
          "Payment cancelled. No application was created.",
          isError: true,
        );
      }
    } catch (apiError) {
      debugPrint("Payment API Error: $apiError");
      if (mounted) {
        final errMsg = apiError.toString();
        if (errMsg.contains("already applied")) {
          setState(() => _hasApplied = true);
          _showSnackBar("Already applied", isError: true);
        } else {
          _showSnackBar("Payment failed: $errMsg", isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingWithUs = false;
          _isPaymentProcessing = false;
        });
      }
    }
  }

  Future<void> _toggleSaveJob() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      _showSnackBar("Please login to save", isError: true);
      return;
    }
    try {
      if (_isSaved) {
        await DioClient.dio.delete('/jobs/save/${widget.job['_id']}');
        setState(() => _isSaved = false);
        _showSnackBar("Removed from saved");
      } else {
        await DioClient.dio.post('/jobs/save/${widget.job['_id']}');
        setState(() => _isSaved = true);
        _showSnackBar("Saved!");
      }
    } catch (e) {
      _showSnackBar("Failed: $e", isError: true);
    }
  }

  void _shareJob() {
    final job = widget.job;
    String notificationInfo = "";
    if (_hasOfficialNotification) {
      notificationInfo +=
          "\n📄 Official Notification: $_officialNotificationUrl";
    }
    if (_hasAdvertisement) {
      notificationInfo += "\n📢 Advertisement: $_advertisementUrl";
    }
    final shareText =
        "📢 *${job['post_name'] ?? 'Job Opportunity'}* at ${job['organization'] ?? 'Company'}\n\n"
        "📍 Location: ${_getJobLocation()}\n"
        "💼 Job Type: ${job['job_type']?.toString().toUpperCase() ?? 'N/A'}\n"
        "🎓 Qualification: ${_getQualificationDisplay()}\n"
        "💰 Salary: ${_getSalaryDisplay()}\n"
        "📅 Last Date: ${_getLastDate()}\n"
        "$notificationInfo\n\n"
        "Apply on RojgarNest App\n\n"
        "Download RojgarNest App for more jobs!";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: _kCardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Share Job",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                shareText,
                style: const TextStyle(
                  height: 1.5,
                  color: _kTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      Navigator.pop(context);
                      _showSnackBar("Copied to clipboard");
                    },
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text(
                      "Copy",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    showMessage(context, message, isError: isError);
  }

  // ============================================================
  // FILE VIEWERS
  // ============================================================
  void _showFilePopup(
    String url,
    String title, {
    String? downloadUrl,
    String? fileType,
  }) {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) {
      _showSnackBar("No file URL available", isError: true);
      return;
    }
    if (!finalUrl.startsWith('http') &&
        !finalUrl.startsWith('file') &&
        !finalUrl.startsWith('blob:')) {
      finalUrl = 'https://$finalUrl';
    }
    String effectiveFileType = fileType ?? 'unknown';
    if (effectiveFileType == 'unknown' || effectiveFileType.isEmpty) {
      effectiveFileType = _JobFileTypeDetector.detectFileType(
        finalUrl,
        explicitType: fileType,
      );
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.95,
          height: MediaQuery.of(dialogContext).size.height * 0.9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _kCardWhite,
          ),
          child: FileViewerScreen(
            url: finalUrl,
            title: title,
            downloadUrl: downloadUrl ?? finalUrl,
            fileType: effectiveFileType,
            fileName: title,
          ),
        ),
      ),
    );
  }

  void _viewOfficialNotification() {
    if (_officialNotificationUrl == null || _officialNotificationUrl!.isEmpty) {
      _showSnackBar("No notification link", isError: true);
      return;
    }
    final fileType = _isOfficialNotificationPdf
        ? 'pdf'
        : _JobFileTypeDetector.detectFileType(_officialNotificationUrl!);
    _showFilePopup(
      _officialNotificationUrl!,
      widget.job['post_name'] ?? "Official Notification",
      fileType: fileType,
    );
  }

  void _viewAdvertisement() {
    if (_advertisementUrl == null || _advertisementUrl!.isEmpty) {
      _showSnackBar("No advertisement", isError: true);
      return;
    }
    final fileType = _JobFileTypeDetector.detectFileType(_advertisementUrl!);
    _showFilePopup(
      _advertisementUrl!,
      widget.job['post_name'] ?? "Job Advertisement",
      downloadUrl: _advertisementDownloadUrl,
      fileType: fileType,
    );
  }

  // ============================================================
  // DESIGN HELPERS
  // ============================================================
  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kBackgroundLight, _kBackgroundLighter],
      ),
    );
  }

  BoxDecoration _buildGlassContainerDecoration() {
    return BoxDecoration(
      color: _kCardWhite,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kBorderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.12),
          blurRadius: 12,
          spreadRadius: 2,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildGlassCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildGlassContainerDecoration(),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    final headerColor = color ?? _kPrimary;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [headerColor, headerColor.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: headerColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _kTextPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          width: 30,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [headerColor, headerColor.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
    bool isLongText = false,
    bool isLink = false,
  }) {
    if (value.isEmpty || value == 'Not specified' || value == 'Not provided') {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (color ?? _kPrimary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color ?? _kPrimary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: _kTextMuted,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isLink
                ? InkWell(
                    onTap: () async {
                      final uri = Uri.parse(
                          value.startsWith('http') ? value : 'https://$value');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: color ?? _kTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: isLongText ? 1.5 : 1.3,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
    bool isLink = false,
  }) {
    if (value.isEmpty || value == 'Not specified' || value == 'Not provided') {
      return const SizedBox();
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (color ?? _kPrimary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color ?? _kPrimary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: _kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: isLink
              ? InkWell(
                  onTap: () async {
                    final uri = Uri.parse(
                        value.startsWith('http') ? value : 'https://$value');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color ?? _kTextPrimary,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPrimary, _kPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // APPLICATION TIMELINE SECTION
  // ============================================================
  Widget _buildApplicationTimelineSection() {
    final startDate = _getApplicationStartDate();
    final endDate = _getApplicationEndDate();
    List<Widget> children = [];
    if (startDate.isNotEmpty) {
      children.add(_buildInfoRow(
        Icons.play_circle_outline,
        "Start Date",
        startDate,
        color: Colors.green,
      ));
    }
    if (endDate.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
        Icons.stop_circle_outlined,
        "End Date",
        endDate,
        color: Colors.red,
      ));
    }
    if (children.isEmpty) {
      children.add(const Text(
        "Application timeline not specified",
        style: TextStyle(fontSize: 13, color: _kTextMuted),
      ));
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Application Timeline", Icons.timeline,
              color: Colors.teal),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // AI LOADING SCREEN
  // ============================================================
  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            duration: const Duration(seconds: 2),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kPink],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome,
                        color: Colors.white, size: 32),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "AI is loading job details...",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ✅ NEW: isEmbedded mode - no Scaffold/AppBar
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final jobType = job['job_type'] ?? 'private';
    final typeColor = _getJobTypeColor(jobType);
    final postedDate = _formatPostedDate();
    final lastDate = _getLastDate();
    final hasValidWebsiteUrl = _hasValidWebsiteUrl();
    final hasApplyWithUsLink = _hasApplyWithUsLink();
    final showApplyButtons = hasValidWebsiteUrl || hasApplyWithUsLink;
    final multiplePosts = _getMultiplePosts();
    final hasMultiplePosts = multiplePosts.isNotEmpty;
    final hasAnyNotification = _hasAnyNotification();
    final hasApplicationFees = _hasApplicationFees();
    final applicationFees = _getApplicationFees();
    final feeBreakdown = _calculateFeeBreakdown();

    // ✅ Build the main content
    final Widget content = (_isLoadingCategory || _isLoadingDisability)
        ? _buildLoadingScreen()
        : FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAIHeaderCard(job, typeColor, postedDate, lastDate),
                  const SizedBox(height: 16),
                  if (_isDisabled) _buildDisabilityBanner(),
                  if (_isDisabled) const SizedBox(height: 16),
                  if (_insights.isNotEmpty) _buildAIInsightsRow(),
                  if (_insights.isNotEmpty) const SizedBox(height: 16),
                  _buildKeyInfoSection(job),
                  const SizedBox(height: 16),
                  if (_getApplicationStartDate().isNotEmpty ||
                      _getApplicationEndDate().isNotEmpty)
                    _buildApplicationTimelineSection(),
                  if (_getApplicationStartDate().isNotEmpty ||
                      _getApplicationEndDate().isNotEmpty)
                    const SizedBox(height: 16),
                  if (hasApplicationFees && applicationFees.isNotEmpty)
                    _buildApplicationFeesSection(
                      applicationFees,
                      feeBreakdown,
                    ),
                  if (hasApplicationFees && applicationFees.isNotEmpty)
                    const SizedBox(height: 16),
                  if (_getAgeLimit() != 'Not specified')
                    _buildAgeLimitSection(),
                  if (_getAgeLimit() != 'Not specified')
                    const SizedBox(height: 16),
                  if (job['exam_cities'] != null &&
                      (job['exam_cities'] as List).isNotEmpty)
                    _buildExamCitiesSection(job['exam_cities']),
                  if (job['exam_cities'] != null &&
                      (job['exam_cities'] as List).isNotEmpty)
                    const SizedBox(height: 16),
                  _buildWorkDetailsSection(),
                  const SizedBox(height: 16),
                  if (job['benefits'] != null &&
                      (job['benefits'] as List).isNotEmpty)
                    _buildBenefitsSection(job['benefits']),
                  if (job['benefits'] != null &&
                      (job['benefits'] as List).isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['languages_required'] != null &&
                      (job['languages_required'] as List).isNotEmpty)
                    _buildLanguagesSection(job['languages_required']),
                  if (job['languages_required'] != null &&
                      (job['languages_required'] as List).isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['education_details'] != null &&
                      job['education_details'].toString().isNotEmpty)
                    _buildEducationDetailsSection(job['education_details']),
                  if (job['education_details'] != null &&
                      job['education_details'].toString().isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['experience_details'] != null &&
                      job['experience_details'].toString().isNotEmpty)
                    _buildExperienceDetailsSection(
                        job['experience_details']),
                  if (job['experience_details'] != null &&
                      job['experience_details'].toString().isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['physical_eligibility'] != null)
                    _buildPhysicalEligibilitySection(
                        job['physical_eligibility']),
                  if (job['physical_eligibility'] != null)
                    const SizedBox(height: 16),
                  if (job['interview_venue'] != null ||
                      job['interview_link'] != null ||
                      job['interview_date'] != null ||
                      job['interview_time'] != null)
                    _buildInterviewSection(),
                  if (job['interview_venue'] != null ||
                      job['interview_link'] != null ||
                      job['interview_date'] != null ||
                      job['interview_time'] != null)
                    const SizedBox(height: 16),
                  if (job['selection_stages'] != null &&
                      (job['selection_stages'] as List).isNotEmpty)
                    _buildSelectionProcessSection(
                        job['selection_stages'],
                        job['selection_process_details']),
                  if (job['selection_stages'] != null &&
                      (job['selection_stages'] as List).isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['contact_person'] != null ||
                      job['contact_email'] != null ||
                      job['contact_phone'] != null)
                    _buildContactInformationSection(),
                  if (job['contact_person'] != null ||
                      job['contact_email'] != null ||
                      job['contact_phone'] != null)
                    const SizedBox(height: 16),
                  if (job['important_notes'] != null &&
                      job['important_notes'].toString().isNotEmpty)
                    _buildImportantNotesSection(job['important_notes']),
                  if (job['important_notes'] != null &&
                      job['important_notes'].toString().isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['terms_conditions'] != null &&
                      job['terms_conditions'].toString().isNotEmpty)
                    _buildTermsConditionsSection(job['terms_conditions']),
                  if (job['terms_conditions'] != null &&
                      job['terms_conditions'].toString().isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['admit_card_date'] != null ||
                      job['exam_date'] != null ||
                      job['result_date'] != null)
                    _buildImportantDatesSection(
                      job['admit_card_date'],
                      job['exam_date'],
                      job['result_date'],
                    ),
                  if (job['admit_card_date'] != null ||
                      job['exam_date'] != null ||
                      job['result_date'] != null)
                    const SizedBox(height: 16),
                  if (job['helpline_number'] != null ||
                      job['helpline_email'] != null ||
                      job['whatsapp_number'] != null ||
                      job['telegram_channel'] != null)
                    _buildHelplineSection(),
                  if (job['helpline_number'] != null ||
                      job['helpline_email'] != null ||
                      job['whatsapp_number'] != null ||
                      job['telegram_channel'] != null)
                    const SizedBox(height: 16),
                  if (job['description'] != null &&
                      job['description'].toString().isNotEmpty)
                    _buildDescriptionSection(job['description']),
                  if (job['description'] != null &&
                      job['description'].toString().isNotEmpty)
                    const SizedBox(height: 16),
                  if (job['required_skills'] != null &&
                      (job['required_skills'] as List).isNotEmpty)
                    _buildSkillsSection(job['required_skills']),
                  if (job['required_skills'] != null &&
                      (job['required_skills'] as List).isNotEmpty)
                    const SizedBox(height: 16),
                  if (hasMultiplePosts)
                    _buildMultiplePostsTable(multiplePosts),
                  if (hasMultiplePosts) const SizedBox(height: 16),
                  if (_hasOfficialNotification)
                    _buildOfficialNotificationSection(),
                  if (_hasOfficialNotification) const SizedBox(height: 16),
                  if (_hasAdvertisement) _buildAdvertisementSection(),
                  if (_hasAdvertisement) const SizedBox(height: 16),
                  if (hasAnyNotification) _buildInfoNote(),
                  if (hasAnyNotification) const SizedBox(height: 16),
                  if (!_isCheckingApplied) _buildSaveAndShareButtons(),
                  if (!_isCheckingApplied) const SizedBox(height: 16),
                  if (_isCheckingApplied)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_kPrimary),
                      ),
                    )
                  else if (showApplyButtons)
                    _buildApplyButtons(
                      hasApplyWithUsLink,
                      hasValidWebsiteUrl,
                      feeBreakdown,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );

    // ✅ EMBEDDED MODE: No Scaffold, no AppBar, no back button
    if (widget.isEmbedded) {
      return Container(
        decoration: _buildGradientBackground(),
        child: content,
      );
    }

    // ✅ FULL SCREEN MODE: With Scaffold and AppBar
    return Scaffold(
      backgroundColor: _kBackgroundLight,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildGradientBackground(),
        child: content,
      ),
    );
  }

  // ============================================================
  // DISABILITY BANNER
  // ============================================================
  Widget _buildDisabilityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.amber],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.accessible, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "PWD Category Detected",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "PRIORITY",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "You will be charged the PWD (Divyangjan) application fee.",
                  style: TextStyle(fontSize: 12, color: _kTextSecondary),
                ),
                if (_disabilityPercentage != null &&
                    _disabilityPercentage!.isNotEmpty)
                  Text(
                    "Disability: $_disabilityPercentage%" +
                        (_disabilityCategory != null &&
                                _disabilityCategory!.isNotEmpty
                            ? " ($_disabilityCategory)"
                            : ""),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR (only used in fullscreen mode)
  // ============================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Job Details",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => widget.onBack != null
            ? widget.onBack!()
            : Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: Colors.white,
          ),
          onPressed: _toggleSaveJob,
          tooltip: "Save Job",
        ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: _shareJob,
          tooltip: "Share",
        ),
      ],
    );
  }

  // ============================================================
  // AI HEADER CARD
  // ============================================================
  Widget _buildAIHeaderCard(
    Map<String, dynamic> job,
    Color typeColor,
    String postedDate,
    String lastDate,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCardWhite, typeColor.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: typeColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor, typeColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: typeColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getJobTypeIcon(job['job_type']),
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['post_name'] ?? 'Job Title',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['organization'] ?? 'Company Name',
                      style: const TextStyle(
                        fontSize: 15,
                        color: _kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: typeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            job['job_type']?.toString().toUpperCase() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _matchScore >= 75
                                  ? [Colors.green, Colors.lightGreen]
                                  : _matchScore >= 50
                                      ? [Colors.orange, Colors.yellow]
                                      : [Colors.red, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (_matchScore >= 75
                                        ? Colors.green
                                        : _matchScore >= 50
                                            ? Colors.orange
                                            : Colors.red)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${_matchScore.round()}% AI',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHeaderInfo(
                    Icons.location_on, "Location", _getJobLocation()),
              ),
              Expanded(
                child: _buildHeaderInfo(
                    Icons.calendar_today, "Posted", postedDate),
              ),
            ],
          ),
          if (lastDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.event, size: 16, color: Colors.red),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Deadline:",
                      style: TextStyle(
                        fontSize: 13,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lastDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: _kPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _kTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AI INSIGHTS ROW
  // ============================================================
  Widget _buildAIInsightsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary.withOpacity(0.08), _kPink.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kPrimary, _kPink]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                "AI Insights",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _insights.map((insight) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kCardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _kTextPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KEY INFO SECTION
  // ============================================================
  Widget _buildKeyInfoSection(Map<String, dynamic> job) {
    List<Widget> children = [
      _buildKeyInfoRow(Icons.work, "Job Level", _getJobLevel()),
      const SizedBox(height: 12),
      _buildKeyInfoRow(Icons.category, "Category", _getCategory()),
      const SizedBox(height: 12),
      _buildKeyInfoRow(Icons.work_history, "Experience", _getExperience()),
    ];
    if (job['total_posts'] != null) {
      children.add(const SizedBox(height: 12));
      children.add(_buildKeyInfoRow(
          Icons.people, "Vacancies", _getTotalVacancies()));
    }
    if (_getAgeLimit() != 'Not specified') {
      children.add(const SizedBox(height: 12));
      children.add(
          _buildKeyInfoRow(Icons.calendar_today, "Age Limit", _getAgeLimit()));
    }
    if (_getGenderPreference() != 'Any') {
      children.add(const SizedBox(height: 12));
      children.add(_buildKeyInfoRow(
          Icons.people, "Gender", _getGenderPreference()));
    }
    if (_getUrgencyLevel() != 'Normal') {
      children.add(const SizedBox(height: 12));
      children.add(_buildKeyInfoRow(
          Icons.priority_high, "Urgency", _getUrgencyLevel(),
          color: Colors.orange));
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Key Information", Icons.info_outline),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // APPLICATION FEES SECTION - FULL BREAKDOWN
  // ✅ Formula: Subtotal = App Fee + Service Charge
  //            GST      = 18% of Subtotal
  //            Total    = Subtotal + GST
  // ============================================================
  Widget _buildApplicationFeesSection(
    Map<String, dynamic> fees,
    FeeBreakdown feeBreakdown,
  ) {
    final effectiveCategory = _getEffectivePaymentCategory();
    final effectiveDisplay = _getEffectivePaymentCategoryDisplay();
    final isPwd = _isPayingAsPwd();

    List<Widget> feeChildren = [];

    fees.entries.forEach((entry) {
      final entryKey = entry.key.toLowerCase();
      final isEffectiveCategory = entryKey == effectiveCategory.toLowerCase() ||
          _getAlternativeFeeKeys(effectiveCategory).contains(entryKey);
      final isPwdEntry = entryKey == 'pwd' ||
          _getAlternativeFeeKeys('pwd').contains(entryKey);
      final isHighlighted = isEffectiveCategory || (isPwd && isPwdEntry);

      feeChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 110,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? (isPwd
                          ? Colors.orange.shade100
                          : Colors.green.shade100)
                      : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: isHighlighted
                      ? Border.all(
                          color: isPwd ? Colors.orange : Colors.green,
                          width: 2,
                        )
                      : Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHighlighted)
                      Icon(
                        isPwd ? Icons.accessible : Icons.check_circle,
                        size: 14,
                        color: isPwd ? Colors.orange : Colors.green,
                      ),
                    if (isHighlighted) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.key.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isHighlighted
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isHighlighted
                              ? (isPwd
                                  ? Colors.orange.shade900
                                  : Colors.green.shade900)
                              : _kTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "₹${entry.value}",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isHighlighted ? FontWeight.bold : FontWeight.w600,
                    color: isHighlighted
                        ? (isPwd
                            ? Colors.orange.shade900
                            : Colors.green.shade900)
                        : _kTextPrimary,
                  ),
                ),
              ),
              if (isHighlighted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPwd ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPwd ? "PWD RATE" : "YOUR RATE",
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });

    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Application Fees", Icons.currency_rupee,
              color: Colors.teal),
          const SizedBox(height: 16),
          if (isPwd)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade100, Colors.amber.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade400),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.accessible,
                        color: Colors.orange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You are paying as: $effectiveDisplay",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          "PWD (Divyangjan) category fee applies to you",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person,
                        color: Colors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "You are paying as: $effectiveDisplay",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Category-wise Fees:",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ...feeChildren,
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),
          // Application Fee
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Application Fee",
                  style: TextStyle(fontSize: 14, color: _kTextSecondary),
                ),
              ),
              Text(
                "₹${feeBreakdown.applicationFee}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Service Charge
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Service Charge",
                  style: TextStyle(fontSize: 14, color: _kTextSecondary),
                ),
              ),
              Text(
                "₹${feeBreakdown.serviceCharge}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Subtotal
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Subtotal",
                  style: TextStyle(
                    fontSize: 14,
                    color: _kTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "₹${feeBreakdown.subtotal}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // GST on subtotal
          Row(
            children: [
              Expanded(
                child: Text(
                  "GST (${GST_PERCENT.toInt()}% on ₹${feeBreakdown.subtotal})",
                  style: const TextStyle(fontSize: 14, color: _kTextSecondary),
                ),
              ),
              Text(
                "₹${feeBreakdown.gstAmount}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.shade300, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment,
                      color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Total Payable",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
                Text(
                  "₹${feeBreakdown.totalFee}",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AGE LIMIT SECTION
  // ============================================================
  Widget _buildAgeLimitSection() {
    final job = widget.job;
    final calcDate = job['age_calculation_date'];
    final relaxation = job['age_relaxation_details'];
    final relaxationByCategory = job['age_relaxation_by_category'];

    List<Widget> children = [
      _buildInfoRow(Icons.cake, "Age Limit", _getAgeLimit(),
          color: Colors.orange),
    ];
    if (calcDate != null && calcDate.toString().isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(Icons.calendar_today, "Age as on",
          _formatDate(calcDate.toString())));
    }
    if (relaxationByCategory != null &&
        relaxationByCategory is Map &&
        relaxationByCategory.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    "Category-wise Age Relaxation:",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...(relaxationByCategory as Map).entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${entry.key}: +${entry.value} years",
                          style: const TextStyle(
                              fontSize: 13, color: _kTextPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }
    if (relaxation != null && relaxation.toString().isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            relaxation.toString(),
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: _kTextPrimary),
          ),
        ),
      );
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Age Limit", Icons.calendar_today,
              color: Colors.orange),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // EXAM CITIES SECTION
  // ============================================================
  Widget _buildExamCitiesSection(List<dynamic> cities) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Exam Cities", Icons.location_city,
              color: Colors.blue),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cities.map((city) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      city.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WORK DETAILS SECTION
  // ============================================================
  Widget _buildWorkDetailsSection() {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Work Details", Icons.work_outline),
          const SizedBox(height: 16),
          _buildKeyInfoRow(
              Icons.schedule, "Work Schedule", _getWorkSchedule()),
          const SizedBox(height: 12),
          _buildKeyInfoRow(Icons.access_time, "Shift", _getShift()),
          const SizedBox(height: 12),
          _buildKeyInfoRow(
              Icons.calendar_view_week, "Working Days", _getWorkingDays()),
          if (widget.job['is_fully_remote'] == true) ...[
            const SizedBox(height: 12),
            _buildKeyInfoRow(Icons.home, "Remote", "Fully Remote",
                color: Colors.green),
          ],
          if (widget.job['is_hybrid'] == true) ...[
            const SizedBox(height: 12),
            _buildKeyInfoRow(Icons.sync, "Hybrid", "Hybrid Work",
                color: Colors.orange),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BENEFITS SECTION
  // ============================================================
  Widget _buildBenefitsSection(List<dynamic> benefits) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Benefits & Perks", Icons.card_giftcard,
              color: Colors.pink),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: benefits.map((benefit) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: Colors.pink),
                    const SizedBox(width: 6),
                    Text(
                      benefit.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LANGUAGES SECTION
  // ============================================================
  Widget _buildLanguagesSection(List<dynamic> languages) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Languages Required", Icons.language,
              color: Colors.indigo),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: languages.map((lang) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Text(
                  lang.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              );
            }).toList(),
          ),
          if (widget.job['other_languages'] != null &&
              widget.job['other_languages'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Other: ${widget.job['other_languages']}",
              style: const TextStyle(fontSize: 13, color: _kTextSecondary),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EDUCATION DETAILS SECTION
  // ============================================================
  Widget _buildEducationDetailsSection(String details) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Education Details", Icons.school,
              color: Colors.teal),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              details,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: _kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXPERIENCE DETAILS SECTION
  // ============================================================
  Widget _buildExperienceDetailsSection(String details) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Experience Details", Icons.work_history,
              color: Colors.deepOrange),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              details,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: _kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PHYSICAL ELIGIBILITY SECTION
  // ============================================================
  Widget _buildPhysicalEligibilitySection(Map physical) {
    List<Widget> children = [];
    if (physical['min_height_cm'] != null) {
      children.add(_buildInfoRow(Icons.height, "Min Height (Male)",
          "${physical['min_height_cm']} cm", color: Colors.blue));
    }
    if (physical['min_height_female_cm'] != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(Icons.height, "Min Height (Female)",
          "${physical['min_height_female_cm']} cm", color: Colors.pink));
    }
    if (physical['min_chest_cm'] != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(Icons.straighten, "Min Chest",
          "${physical['min_chest_cm']} cm", color: Colors.orange));
    }
    if (physical['max_weight_kg'] != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(Icons.monitor_weight, "Max Weight",
          "${physical['max_weight_kg']} kg", color: Colors.green));
    }
    if (physical['relaxation'] != null &&
        physical['relaxation'].toString().isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Text(
            "Relaxation: ${physical['relaxation']}",
            style: const TextStyle(fontSize: 13, color: _kTextPrimary),
          ),
        ),
      );
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Physical Eligibility", Icons.fitness_center,
              color: Colors.red),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // INTERVIEW SECTION
  // ============================================================
  Widget _buildInterviewSection() {
    final job = widget.job;
    final venue = job['interview_venue'];
    final link = job['interview_link'];
    final date = job['interview_date'];
    final time = job['interview_time'];
    final documents = job['interview_documents'];
    final isOnline = job['is_interview_online'] == true;

    List<Widget> children = [];
    if (isOnline && link != null) {
      children.add(_buildInfoRow(Icons.video_call, "Mode", "Online Interview",
          color: Colors.green));
      children.add(const SizedBox(height: 8));
      children.add(
          _buildInfoRow(Icons.link, "Link", link.toString(), isLink: true));
    } else if (venue != null && venue.toString().isNotEmpty) {
      children.add(_buildInfoRow(Icons.location_on, "Venue", venue.toString()));
    }
    if (date != null && date.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.calendar_today, "Date", _formatDate(date.toString())));
    }
    if (time != null && time.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(Icons.access_time, "Time", time.toString()));
    }
    if (documents != null && documents is List && documents.isNotEmpty) {
      children.add(const SizedBox(height: 16));
      children.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.description, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    "Documents Required:",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: documents.map((doc) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      doc.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Interview Details", Icons.people_alt,
              color: Colors.purple),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // SELECTION PROCESS SECTION
  // ============================================================
  Widget _buildSelectionProcessSection(
      List<dynamic> stages, dynamic details) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Selection Process", Icons.timeline,
              color: Colors.deepPurple),
          const SizedBox(height: 16),
          ...stages.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurple, Colors.purple],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "${entry.key + 1}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (details != null && details.toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                details.toString(),
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: _kTextPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CONTACT INFORMATION SECTION
  // ============================================================
  Widget _buildContactInformationSection() {
    final job = widget.job;
    List<Widget> children = [];
    if (job['contact_person'] != null &&
        job['contact_person'].toString().isNotEmpty) {
      children.add(_buildInfoRow(
          Icons.person, "Contact Person", job['contact_person'].toString(),
          color: Colors.cyan));
    }
    if (job['contact_designation'] != null &&
        job['contact_designation'].toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(Icons.badge, "Designation",
          job['contact_designation'].toString(),
          color: Colors.cyan));
    }
    if (job['contact_email'] != null &&
        job['contact_email'].toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.email, "Email", job['contact_email'].toString(),
          isLink: true, color: Colors.cyan));
    }
    if (job['contact_phone'] != null &&
        job['contact_phone'].toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.phone, "Phone", job['contact_phone'].toString(),
          color: Colors.cyan));
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Contact Information", Icons.contact_phone,
              color: Colors.cyan),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // IMPORTANT NOTES SECTION
  // ============================================================
  Widget _buildImportantNotesSection(String notes) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Important Notes", Icons.note,
              color: Colors.amber),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              notes,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: _kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TERMS & CONDITIONS SECTION
  // ============================================================
  Widget _buildTermsConditionsSection(String terms) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Terms & Conditions", Icons.gavel,
              color: Colors.brown),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              terms,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: _kTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // IMPORTANT DATES SECTION
  // ============================================================
  Widget _buildImportantDatesSection(
      dynamic admitCardDate, dynamic examDate, dynamic resultDate) {
    List<Widget> children = [];
    if (admitCardDate != null && admitCardDate.toString().isNotEmpty) {
      children.add(_buildInfoRow(Icons.confirmation_number, "Admit Card",
          _formatDate(admitCardDate.toString()),
          color: Colors.blue));
    }
    if (examDate != null && examDate.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.event, "Exam Date", _formatDate(examDate.toString()),
          color: Colors.red));
    }
    if (resultDate != null && resultDate.toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.emoji_events, "Result Date", _formatDate(resultDate.toString()),
          color: Colors.green));
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Important Dates", Icons.event,
              color: Colors.indigo),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // HELPLINE SECTION
  // ============================================================
  Widget _buildHelplineSection() {
    final job = widget.job;
    List<Widget> children = [];
    if (job['helpline_number'] != null &&
        job['helpline_number'].toString().isNotEmpty) {
      children.add(_buildInfoRow(
          Icons.support_agent, "Helpline", job['helpline_number'].toString(),
          color: Colors.green));
    }
    if (job['helpline_email'] != null &&
        job['helpline_email'].toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.email, "Email", job['helpline_email'].toString(),
          isLink: true, color: Colors.green));
    }
    if (job['whatsapp_number'] != null &&
        job['whatsapp_number'].toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.chat, "WhatsApp", job['whatsapp_number'].toString(),
          color: Colors.green));
    }
    if (job['telegram_channel'] != null &&
        job['telegram_channel'].toString().isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(_buildInfoRow(
          Icons.telegram, "Telegram", job['telegram_channel'].toString(),
          isLink: true, color: Colors.green));
    }
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Helpline & Support", Icons.headset_mic,
              color: Colors.green),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // DESCRIPTION SECTION
  // ============================================================
  Widget _buildDescriptionSection(String description) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Job Description", Icons.description),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              description,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: _kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SKILLS SECTION
  // ============================================================
  Widget _buildSkillsSection(List<dynamic> skills) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Required Skills", Icons.build,
              color: Colors.blue),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: skills.map((skill) {
              final skillName = skill is Map
                  ? (skill['name'] ?? skill['skill'] ?? skill.toString())
                  : skill.toString();
              final minProf = skill is Map ? skill['min_proficiency'] : null;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      skillName.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    if (minProf != null)
                      Text(
                        minProf.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MULTIPLE POSTS TABLE
  // ============================================================
  Widget _buildMultiplePostsTable(List<dynamic> posts) {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Multiple Posts Details", Icons.list_alt,
              color: Colors.teal),
          const SizedBox(height: 16),
          ...posts.asMap().entries.map((entry) {
            final index = entry.key;
            final post = entry.value as Map;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.teal, Colors.tealAccent],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Post ${index + 1}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          post['post_name']?.toString() ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (post['total_posts'] != null)
                        _buildMiniInfoChip(
                          Icons.people,
                          "${post['total_posts']} posts",
                          color: Colors.blue,
                        ),
                      if (post['qualification'] != null)
                        _buildMiniInfoChip(
                          Icons.school,
                          post['qualification'].toString(),
                          color: Colors.purple,
                        ),
                      if (post['age_min'] != null || post['age_max'] != null)
                        _buildMiniInfoChip(
                          Icons.cake,
                          "${post['age_min'] ?? '—'}-${post['age_max'] ?? '—'} yrs",
                          color: Colors.orange,
                        ),
                    ],
                  ),
                  if (post['pay_scales'] != null &&
                      (post['pay_scales'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(color: Colors.teal.shade200),
                    const SizedBox(height: 8),
                    const Text(
                      "Pay Scales:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...((post['pay_scales'] as List).map((ps) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ps['pay_scale'] ?? 'N/A',
                              style: const TextStyle(
                                  fontSize: 13, color: _kTextPrimary),
                            ),
                          ],
                        ),
                      );
                    })),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OFFICIAL NOTIFICATION SECTION
  // ============================================================
  Widget _buildOfficialNotificationSection() {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Official Notification", Icons.notifications,
              color: Colors.blue),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isOfficialNotificationPdf
                        ? Icons.picture_as_pdf
                        : Icons.link,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Official Notification",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        _isOfficialNotificationPdf
                            ? "PDF Document - Click to view"
                            : "External Link - Click to open",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _viewOfficialNotification,
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                  tooltip: "View Notification",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _viewOfficialNotification,
              icon: Icon(
                _isOfficialNotificationPdf
                    ? Icons.picture_as_pdf
                    : Icons.open_in_new,
                color: Colors.white,
              ),
              label: Text(
                _isOfficialNotificationPdf
                    ? "View Official Notification PDF"
                    : "Open Official Notification",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADVERTISEMENT SECTION
  // ============================================================
  Widget _buildAdvertisementSection() {
    return _buildGlassCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Job Advertisement", Icons.campaign,
              color: Colors.orange),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getAdvertisementIcon(),
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Advertisement",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        _getAdvertisementSubtitle(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _viewAdvertisement,
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                  ),
                  tooltip: "View Advertisement",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _viewAdvertisement,
              icon: Icon(_getAdvertisementIcon(), color: Colors.white),
              label: Text(
                _getAdvertisementButtonText(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO NOTE
  // ============================================================
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Click on the buttons above to view official documents",
              style: TextStyle(
                fontSize: 13,
                color: _kTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAVE & SHARE BUTTONS
  // ============================================================
  Widget _buildSaveAndShareButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _toggleSaveJob,
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? Colors.white : _kPrimary,
              ),
              label: Text(
                _isSaved ? "Saved" : "Save Job",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isSaved ? Colors.white : _kPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? Colors.green : _kCardWhite,
                foregroundColor: _isSaved ? Colors.white : _kPrimary,
                side: BorderSide(
                  color: _isSaved ? Colors.green : _kPrimary,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _shareJob,
              icon: const Icon(Icons.share, color: _kPrimary),
              label: const Text(
                "Share",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCardWhite,
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // APPLY BUTTONS
  // ============================================================
  Widget _buildApplyButtons(
    bool hasApplyWithUs,
    bool hasWebsiteUrl,
    FeeBreakdown feeBreakdown,
  ) {
    if (_hasApplied) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.green, size: 28),
            ),
            const SizedBox(width: 14),
            Text(
              "Already Applied",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (hasApplyWithUs)
          SizedBox(
            width: double.infinity,
            height: 58,
            child: _buildGradientButton(
              text: _isApplyingWithUs
                  ? "Processing..."
                  : (feeBreakdown.totalFee > 0
                      ? "Apply with Us (₹${feeBreakdown.totalFee})"
                      : "Apply with Us"),
              icon: _isApplyingWithUs ? Icons.hourglass_empty : Icons.send,
              onTap: _isApplyingWithUs ? () {} : _applyWithUs,
            ),
          ),
        if (hasApplyWithUs && hasWebsiteUrl) const SizedBox(height: 14),
        if (hasWebsiteUrl)
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _isApplyingOnWebsite ? null : _applyOnWebsite,
              icon: _isApplyingOnWebsite
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPrimary,
                      ),
                    )
                  : const Icon(Icons.open_in_new, color: _kPrimary, size: 22),
              label: Text(
                _isApplyingOnWebsite ? "Opening..." : "Apply on Website",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kCardWhite,
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }
}