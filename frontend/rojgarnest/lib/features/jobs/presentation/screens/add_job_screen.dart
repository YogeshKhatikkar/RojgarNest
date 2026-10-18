// lib/features/jobs/presentation/screens/add_job_screen.dart
// ✅ COMPLETE FIXED VERSION
// ✅ FIXED: All job details (PDF, Image, Link, notification, etc.) are now correctly sent and saved to the database.
// ✅ FIXED: The file upload process is now robust and handles the `advertisement_url` correctly.
// ✅ FIXED: Payload keys are now aligned with the backend schema (e.g., official_notification_link).
// ✅ FIXED: This ensures the Job Details screen can display all saved information.
// ✅ No lines skipped. Full and complete file.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnest/core/config/api_config.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/master_date/locations.dart';
import 'package:rojgarnest/features/notification/service/notification_service.dart';
import 'package:rojgarnest/core/master_date/education.dart';
import 'package:rojgarnest/core/master_date/job_colors.dart';

class AddJobScreen extends StatefulWidget {
  final String adminRole;
  final VoidCallback? onJobAdded;
  final VoidCallback? onJobUpdated;

  // ✅ Edit mode support
  final Map<String, dynamic>? editingJob;
  final bool isEditMode;

  const AddJobScreen({
    super.key,
    this.adminRole = 'admin',
    this.onJobAdded,
    this.onJobUpdated,
    this.editingJob,
    this.isEditMode = false,
  });

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen>
    with SingleTickerProviderStateMixin {
  static const int maxFileSizeMB = 50;
  static const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();

  // ==================== TAB CONTROL ====================
  static const int _tabCount = 8;
  late TabController _tabController;
  int _currentTabIndex = 0;

  // ==================== DRAFT JOB ID ====================
  String? _draftJobId;
  bool _isSavingDraft = false;
  Map<int, bool> _tabSaveStatus = {};

  final List<IconData> _tabIcons = const [
    Icons.business,
    Icons.people,
    Icons.calendar_today,
    Icons.date_range,
    Icons.work_outline,
    Icons.people_alt,
    Icons.notifications,
    Icons.info_outline,
  ];

  final List<String> _tabLabels = const [
    'Basic',
    'Vacancy',
    'Age/Fees',
    'Timeline',
    'Work',
    'Interview',
    'Notification',
    'Extras',
  ];

  String get _safeTabLabel {
    final idx = _currentTabIndex.clamp(0, _tabLabels.length - 1);
    return _tabLabels[idx];
  }

  IconData get _safeTabIcon {
    final idx = _currentTabIndex.clamp(0, _tabIcons.length - 1);
    return _tabIcons[idx];
  }

  // ==================== BASIC CONTROLLERS ====================
  final organizationCtrl = TextEditingController();
  final postNameCtrl = TextEditingController();
  final cityVillageCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final lastDateCtrl = TextEditingController();
  final postDateCtrl = TextEditingController();

  final applyWithUsUrlCtrl = TextEditingController();
  bool hasApplyWithUs = false;
  final websiteUrlCtrl = TextEditingController();

  // ==================== OFFICIAL NOTIFICATION ====================
  final officialNotificationUrlCtrl = TextEditingController();
  bool hasOfficialNotificationLink = false;
  String? selectedFileName;
  Uint8List? selectedFileBytes;
  String? selectedFileMimeType;
  bool isUploading = false;
  bool hasAdvertisementFile = false;

  // ==================== AGE LIMIT ====================
  final ageCalcDateCtrl = TextEditingController();
  final ageRelaxationCtrl = TextEditingController();

  // ==================== AGE RELAXATION DROPDOWN ====================
  bool _hasAgeRelaxation = false;
  bool _isEditingRelaxation = false;
  String? _editingRelaxationCategory;
  final TextEditingController relaxationCategoryCtrl = TextEditingController();
  final TextEditingController relaxationYearsCtrl = TextEditingController();
  final Map<String, TextEditingController> relaxationControllers = {};
  final Map<String, String> relaxationValues = {};

  final List<String> relaxationCategories = const [
    'General/UR', 'OBC', 'SC', 'ST', 'EWS', 'PWD', 'Female', 'ESM',
    'Ex-Serviceman', 'Sports Person', 'Kashmiri Migrant', 'J&K Domicile',
  ];

  // ==================== APPLICATION FEES ====================
  bool _hasApplicationFees = false;
  final Map<String, TextEditingController> feesControllers = {};
  final Map<String, String> feesValues = {};
  String? _editingFeeCategory;
  bool _isEditingFee = false;
  final TextEditingController feeCategoryCtrl = TextEditingController();
  final TextEditingController feeAmountCtrl = TextEditingController();

  final List<String> predefinedFeeCategories = const [
    'General/UR', 'OBC', 'SC', 'ST', 'EWS', 'PWD', 'Female', 'ESM',
    'Transgender', 'Other',
  ];

  // ==================== MULTIPLE POSTS ====================
  List<Map<String, dynamic>> multiplePosts = [];
  final postNameCtrl2 = TextEditingController();
  final vacancyCtrl = TextEditingController();
  String? selectedQualificationFromEducation;
  String? selectedQualificationSubOption;
  String? selectedDegreeStream;
  String? selectedDegreeName;
  List<String> _qualificationSubOptions = [];
  List<String> _degreeStreams = [];
  List<String> _degreeNames = [];
  final postAgeMinCtrl = TextEditingController();
  final postAgeMaxCtrl = TextEditingController();
  final otherQualificationCtrl = TextEditingController();
  final TextEditingController experienceDetailsCtrl = TextEditingController();
  int? _editingPostIndex;
  bool _isEditingPost = false;

  // ==================== PAY SCALE ====================
  int? _selectedPostForPayScale;
  final TextEditingController payScaleCtrl = TextEditingController();
  final TextEditingController gradePayCtrl = TextEditingController();
  final TextEditingController payBandCtrl = TextEditingController();
  final TextEditingController minSalaryCtrl = TextEditingController();
  final TextEditingController maxSalaryCtrl = TextEditingController();
  int? _editingPayScaleIndex;
  bool _isEditingPayScale = false;

  // ==================== CATEGORY VACANCY ====================
  bool _hasCategoryVacancy = false;
  int? _editingCategoryPostIndex;
  int? _editingCategoryIndex;
  bool _isEditingCategory = false;
  final TextEditingController categoryNameCtrl = TextEditingController();
  final TextEditingController categoryVacancyCtrl = TextEditingController();

  final List<String> predefinedCategories = const [
    'General/UR', 'OBC', 'SC', 'ST', 'EWS', 'PWD', 'Female', 'ESM',
  ];

  // ==================== DATES ====================
  final TextEditingController applicationStartDateCtrl = TextEditingController();
  final TextEditingController applicationEndDateCtrl = TextEditingController();

  // ==================== OFFICIAL DETAILS ====================
  final TextEditingController notificationNumberCtrl = TextEditingController();
  final TextEditingController notificationDateCtrl = TextEditingController();
  String selectedApplicationMode = 'Online';
  final List<String> applicationModes = ['Online', 'Offline', 'Both'];

  // ==================== EXAM CITIES ====================
  List<String> examCities = [];
  final TextEditingController examCityCtrl = TextEditingController();

  // ==================== PHYSICAL ELIGIBILITY ====================
  bool _hasPhysicalRequirement = false;
  final TextEditingController minHeightCtrl = TextEditingController();
  final TextEditingController minHeightFemaleCtrl = TextEditingController();
  final TextEditingController minChestCtrl = TextEditingController();
  final TextEditingController maxWeightCtrl = TextEditingController();
  final TextEditingController physicalRelaxationCtrl = TextEditingController();

  // ==================== MEDICAL ====================
  bool _hasMedicalRequirement = false;
  final TextEditingController medicalStandardsCtrl = TextEditingController();

  // ==================== TRAINING ====================
  bool _hasTraining = false;
  final TextEditingController trainingDurationCtrl = TextEditingController();
  final TextEditingController trainingStipendCtrl = TextEditingController();
  final TextEditingController trainingLocationCtrl = TextEditingController();

  // ==================== ADDITIONAL ====================
  final TextEditingController whatsappNumberCtrl = TextEditingController();
  final TextEditingController telegramChannelCtrl = TextEditingController();

  // ==================== EDUCATION ====================
  final List<String> educationLevels = [
    'No Formal Education', 'Below 5th', '5th Pass', '8th Pass', '10th Pass',
    '12th Pass', 'ITI', 'Diploma', 'Graduation', 'Post Graduation', 'PhD',
    'Vocational Training', 'Any Graduate', 'Any Post Graduate',
  ];

  final TextEditingController educationDetailsCtrl = TextEditingController();
  String selectedEducation = 'Any Graduate';

  bool isFresherEligible = true;
  bool isExperiencedEligible = true;

  List<String> selectedBenefits = [];
  final List<String> availableBenefits = const [
    'Health Insurance', 'Provident Fund', 'Gratuity', 'Bonus',
    'Travel Allowance', 'House Rent Allowance', 'Food Allowance',
    'Education Allowance', 'Leave Encashment', 'Flexible Timing',
    'Work From Home', 'Free Transport', 'Free Accommodation',
    'Medical Facilities', 'Training Programs', 'Career Growth',
    'Performance Bonus', 'Stock Options', 'Mobile Allowance',
    'Internet Allowance',
  ];

  final List<String> workSchedules = const [
    'Full Time', 'Part Time', 'Contractual', 'Temporary', 'Permanent',
    'Freelance', 'Internship', 'Volunteer',
  ];
  String selectedWorkSchedule = 'Full Time';

  final List<String> shifts = const [
    'Day Shift', 'Night Shift', 'Rotational Shift', 'Flexible Shift',
    'Split Shift', 'On Call',
  ];
  String selectedShift = 'Day Shift';

  final List<String> workingDays = const [
    'Monday to Friday', 'Monday to Saturday', '5 Days a Week',
    '6 Days a Week', 'Alternate Days', 'Rotational Off',
  ];
  String selectedWorkingDays = 'Monday to Friday';

  List<String> selectedLanguages = [];
  final List<String> availableLanguages = const [
    'Hindi', 'English', 'Marathi', 'Bengali', 'Telugu', 'Tamil',
    'Gujarati', 'Kannada', 'Malayalam', 'Punjabi', 'Urdu', 'Odia',
    'Assamese',
  ];
  final TextEditingController otherLanguagesCtrl = TextEditingController();

  final TextEditingController interviewVenueCtrl = TextEditingController();
  final TextEditingController interviewDateCtrl = TextEditingController();
  final TextEditingController interviewTimeCtrl = TextEditingController();
  bool isInterviewOnline = false;
  final TextEditingController interviewLinkCtrl = TextEditingController();
  List<String> interviewDocuments = [];
  final List<String> requiredDocuments = const [
    'Resume/CV', 'Educational Certificates', 'Experience Certificates',
    'Aadhar Card', 'PAN Card', 'Passport Size Photo', 'Caste Certificate',
    'Disability Certificate', 'Ex-Serviceman Certificate', 'Income Certificate',
  ];

  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController contactDesignationCtrl = TextEditingController();
  final TextEditingController contactEmailCtrl = TextEditingController();
  final TextEditingController contactPhoneCtrl = TextEditingController();
  final TextEditingController importantNotesCtrl = TextEditingController();
  final TextEditingController termsAndConditionsCtrl = TextEditingController();

  List<String> selectionStages = [];
  final List<String> availableStages = const [
    'Application Screening', 'Written Exam', 'Skill Test',
    'Group Discussion', 'Personal Interview', 'HR Interview',
    'Technical Interview', 'Medical Examination', 'Document Verification',
    'Final Selection',
  ];
  final TextEditingController selectionProcessDetailsCtrl =
      TextEditingController();

  bool hasBond = false;
  final TextEditingController bondDurationCtrl = TextEditingController();
  final TextEditingController bondAmountCtrl = TextEditingController();
  final TextEditingController bondTermsCtrl = TextEditingController();

  final List<String> urgencyLevels = const [
    'Immediate', 'Urgent', 'Normal', 'Long Term',
  ];
  String selectedUrgency = 'Normal';
  final List<String> genderPreferences = const [
    'Any', 'Male', 'Female', 'Transgender',
  ];
  String selectedGenderPreference = 'Any';
  bool isFullyRemote = false;
  bool isHybrid = false;

  final TextEditingController admitCardDateCtrl = TextEditingController();
  final TextEditingController examDateCtrl = TextEditingController();
  final TextEditingController resultDateCtrl = TextEditingController();
  final TextEditingController officialWebsiteCtrl = TextEditingController();
  final TextEditingController helplineNumberCtrl = TextEditingController();
  final TextEditingController helplineEmailCtrl = TextEditingController();

  final List<String> jobTypes = const [
    'private', 'remote', 'hybrid', 'government',
  ];
  final List<String> jobLevels = const [
    'entry', 'mid', 'senior', 'lead', 'executive',
  ];
  final List<String> categories = const [
    'IT', 'Marketing', 'Finance', 'HR', 'Engineering', 'Teaching',
    'Healthcare', 'Government', 'Banking', 'Defense', 'Sales', 'Operations',
  ];

  String jobType = 'private';
  String jobLevel = 'mid';
  String category = 'IT';
  String _colorType = 'blue';

  String? _selectedCountry;
  String? _selectedState;
  String? _selectedDistrict;
  List<String> _countries = [];
  List<String> _states = [];
  List<String> _districts = [];

  bool isLoading = false;
  bool _showMultiplePosts = false;
  bool _useCurrentLocation = false;
  String _locationStatus = '';
  bool _isGettingLocation = false;
  bool _isGeocoding = false;
  Map<String, dynamic>? _geocodedResult;
  String _geocodingStatus = '';

  // ==================== EDUCATION MASTER DATA MAPS ====================
  final Map<String, List<String>> _qualificationSubOptionsMap = {
    'ITI': EducationMasterData.getItiTradeNames(),
    'Diploma': EducationMasterData.getDiplomaCourseNames(),
    'Vocational Training': EducationMasterData.getCertificationNames(),
  };

  final Map<String, List<String>> _degreeStreamsMap = {
    'Graduation': const [
      'B.Tech', 'B.E.', 'B.Sc', 'B.Com', 'B.A.', 'BBA', 'BCA', 'B.Pharma',
      'B.Arch', 'B.Des', 'B.Plan', 'B.H.M.', 'B.Ed', 'B.P.Ed', 'B.Lib',
      'B.F.A.', 'B.J.M.C.', 'B.S.W.', 'LL.B.', 'B.A.LL.B', 'B.Com.LL.B',
      'B.B.A.LL.B', 'MBBS', 'BDS', 'BHMS', 'BAMS', 'BUMS', 'B.V.Sc.',
      'B.P.T.', 'B.O.T.', 'B.Sc Nursing', 'B.Optom', 'B.M.L.T.',
      'B.Sc Agriculture', 'B.Sc Horticulture', 'B.Sc Forestry', 'B.F.Sc',
    ],
    'Post Graduation': const [
      'M.Tech', 'M.E.', 'M.Sc', 'M.Com', 'M.A.', 'MBA', 'MCA', 'M.Pharma',
      'M.Arch', 'M.Des', 'M.Plan', 'M.H.M.', 'M.Ed', 'M.P.Ed', 'M.Lib',
      'M.F.A.', 'M.J.M.C.', 'M.S.W.', 'LL.M.', 'MD', 'MS', 'MDS', 'M.P.T.',
      'M.Sc Nursing',
    ],
    'PhD': const [
      'PhD', 'M.Phil', 'D.Sc', 'D.Litt', 'DBA', 'D.M.A.', 'Ed.D', 'D.Eng',
    ],
  };

  final Map<String, List<String>> _degreeSubjectsMap = {
    'B.Tech': EducationMasterData.getEngineeringBranches(),
    'B.E.': EducationMasterData.getEngineeringBranches(),
    'M.Tech': EducationMasterData.getEngineeringBranches(),
    'M.E.': EducationMasterData.getEngineeringBranches(),
    'B.Sc': EducationMasterData.getScienceSubjects(),
    'M.Sc': EducationMasterData.getScienceSubjects(),
    'B.Com': EducationMasterData.getCommerceSubjects(),
    'M.Com': EducationMasterData.getCommerceSubjects(),
    'B.A.': EducationMasterData.getArtsSubjects(),
    'M.A.': EducationMasterData.getArtsSubjects(),
    'BBA': EducationMasterData.getManagementSubjects(),
    'MBA': EducationMasterData.getManagementSubjects(),
    'BCA': EducationMasterData.getComputerSubjects(),
    'MCA': EducationMasterData.getComputerSubjects(),
    'MBBS': EducationMasterData.getMedicalSubjects(),
    'BDS': EducationMasterData.getMedicalSubjects(),
    'BHMS': EducationMasterData.getMedicalSubjects(),
    'BAMS': EducationMasterData.getMedicalSubjects(),
    'B.Pharma': EducationMasterData.getMedicalSubjects(),
    'M.Pharma': EducationMasterData.getMedicalSubjects(),
    'LL.B.': EducationMasterData.getLawSubjects(),
    'LL.M.': EducationMasterData.getLawSubjects(),
    'B.Sc Agriculture': EducationMasterData.getAgricultureSubjects(),
    'PhD': [],
    'M.Phil': [],
  };

  // ============================================================
  // ✅ SAFE HELPER: Convert age_min/age_max (int/double/String/null) to String
  // ============================================================
  String _safeAgeToString(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is double) {
      if (value == value.truncateToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_currentTabIndex != _tabController.index) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    _loadCountries();
    _setupLocationListeners();

    for (var category in relaxationCategories) {
      relaxationControllers[category] = TextEditingController();
      relaxationValues[category] = '';
    }

    for (var category in predefinedFeeCategories) {
      feesControllers[category] = TextEditingController();
      feesValues[category] = '';
    }
    _updateQualificationSubOptions();

    for (int i = 0; i < _tabCount; i++) {
      _tabSaveStatus[i] = false;
    }

    // ✅ Pre-fill data if in edit mode
    if (widget.isEditMode && widget.editingJob != null) {
      _preFillJobData(widget.editingJob!);
    }
  }

  // ============================================================
  // ✅ PRE-FILL JOB DATA FOR EDIT MODE
  // ============================================================
  void _preFillJobData(Map<String, dynamic> job) {
    debugPrint("📝 Pre-filling job data for edit mode");
    debugPrint("   Job ID: ${job['_id']}");
    debugPrint("   Job keys: ${job.keys.toList()}");

    try {
      _draftJobId = job['_id']?.toString();

      // ==================== BASIC TAB ====================
      organizationCtrl.text = job['organization']?.toString() ?? '';
      postNameCtrl.text = job['post_name']?.toString() ?? '';
      descriptionCtrl.text = job['description']?.toString() ?? '';
      lastDateCtrl.text = job['last_date']?.toString() ?? '';
      postDateCtrl.text = job['post_date']?.toString() ?? '';
      websiteUrlCtrl.text = job['website_url']?.toString() ?? '';

      final jobLocation = job['job_location'] as Map? ?? {};
      cityVillageCtrl.text = jobLocation['city']?.toString() ??
          jobLocation['village_name']?.toString() ??
          '';
      locationCtrl.text = jobLocation['location_name']?.toString() ??
          job['location']?.toString() ??
          '';

      if (job['job_type'] != null) {
        final jt = job['job_type'].toString().toLowerCase();
        if (jobTypes.contains(jt)) {
          jobType = jt;
        }
      }
      if (job['job_level'] != null) {
        final jl = job['job_level'].toString().toLowerCase();
        if (jobLevels.contains(jl)) {
          jobLevel = jl;
        }
      }
      if (job['category'] != null) {
        category = job['category'].toString();
      }
      if (job['color_type'] != null) {
        _colorType =
            JobColorMasterData.normalize(job['color_type'].toString());
      }

      hasApplyWithUs = job['has_apply_with_us'] == true;
      applyWithUsUrlCtrl.text = job['apply_with_us_url']?.toString() ?? '';

      // ✅ FIX: Use correct field name from backend
      hasOfficialNotificationLink = job['official_notification_link'] != null && job['official_notification_link'].toString().isNotEmpty;
      officialNotificationUrlCtrl.text =
          job['official_notification_link']?.toString() ?? '';

      final advUrl = job['advertisement_url']?.toString();
      if (advUrl != null && advUrl.isNotEmpty) {
        hasAdvertisementFile = true;
        selectedFileName = job['advertisement_filename']?.toString() ??
            'advertisement.pdf';
      }

      // ==================== VACANCY TAB ====================
      final multiplePostsData = job['multiple_posts'];
      if (multiplePostsData is List && multiplePostsData.isNotEmpty) {
        _showMultiplePosts = true;
        multiplePosts = multiplePostsData.whereType<Map>().map((e) {
          final Map<String, dynamic> postMap = Map<String, dynamic>.from(e);
          if (postMap.containsKey('age_min')) {
            postMap['age_min'] = _safeAgeToString(postMap['age_min']);
          }
          if (postMap.containsKey('age_max')) {
            postMap['age_max'] = _safeAgeToString(postMap['age_max']);
          }
          if (postMap['pay_scales'] is List) {
            postMap['pay_scales'] = (postMap['pay_scales'] as List)
                .whereType<Map>()
                .map((ps) => Map<String, dynamic>.from(ps))
                .toList();
          }
          if (postMap['category_vacancies'] is List) {
            postMap['category_vacancies'] =
                (postMap['category_vacancies'] as List)
                    .whereType<Map>()
                    .map((cv) => Map<String, dynamic>.from(cv))
                    .toList();
          }
          return postMap;
        }).toList();
      }

      if (job['required_qualification'] != null) {
        final rawQual = job['required_qualification'].toString().trim();
        if (rawQual.isNotEmpty) {
          if (educationLevels.contains(rawQual)) {
            selectedEducation = rawQual;
          } else {
            selectedEducation = 'Any Graduate';
          }
        }
      }
      educationDetailsCtrl.text = job['education_details']?.toString() ?? '';
      isFresherEligible = job['is_fresher_eligible'] != false;
      isExperiencedEligible = job['is_experienced_eligible'] != false;

      // ==================== AGE & FEES TAB ====================
      ageCalcDateCtrl.text = job['age_calculation_date']?.toString() ?? '';
      ageRelaxationCtrl.text = job['age_relaxation_details']?.toString() ?? '';

      final ageRelaxationByCategory = job['age_relaxation_by_category'];
      if (ageRelaxationByCategory is Map &&
          ageRelaxationByCategory.isNotEmpty) {
        _hasAgeRelaxation = true;
        ageRelaxationByCategory.forEach((key, value) {
          final years = value?.toString() ?? '';
          if (years.isNotEmpty) {
            relaxationValues[key.toString()] = years;
            if (relaxationControllers.containsKey(key.toString())) {
              relaxationControllers[key.toString()]?.text = years;
            } else {
              relaxationControllers[key.toString()] =
                  TextEditingController(text: years);
            }
          }
        });
      }

      final applicationFees = job['application_fees'];
      if (job['has_application_fees'] == true &&
          applicationFees is Map &&
          applicationFees.isNotEmpty) {
        _hasApplicationFees = true;
        applicationFees.forEach((key, value) {
          final amount = value?.toString() ?? '';
          if (amount.isNotEmpty) {
            feesValues[key.toString()] = amount;
            if (feesControllers.containsKey(key.toString())) {
              feesControllers[key.toString()]?.text = amount;
            } else {
              feesControllers[key.toString()] =
                  TextEditingController(text: amount);
            }
          }
        });
      }

      // ==================== TIMELINE TAB ====================
      applicationStartDateCtrl.text =
          job['application_start_date']?.toString() ?? '';
      applicationEndDateCtrl.text =
          job['application_end_date']?.toString() ?? '';
      notificationNumberCtrl.text =
          job['notification_number']?.toString() ?? '';
      notificationDateCtrl.text = job['notification_date']?.toString() ?? '';

      if (job['application_mode'] != null) {
        final mode = job['application_mode'].toString();
        if (applicationModes.contains(mode)) {
          selectedApplicationMode = mode;
        }
      }

      final examCitiesData = job['exam_cities'];
      if (examCitiesData is List) {
        examCities = examCitiesData.map((e) => e.toString()).toList();
      }

      admitCardDateCtrl.text = job['admit_card_date']?.toString() ?? '';
      examDateCtrl.text = job['exam_date']?.toString() ?? '';
      resultDateCtrl.text = job['result_date']?.toString() ?? '';

      // ==================== WORK TAB ====================
      if (job['work_schedule'] != null) {
        final ws = job['work_schedule'].toString();
        if (workSchedules.contains(ws)) {
          selectedWorkSchedule = ws;
        }
      }
      if (job['shift'] != null) {
        final s = job['shift'].toString();
        if (shifts.contains(s)) {
          selectedShift = s;
        }
      }
      if (job['working_days'] != null) {
        final wd = job['working_days'].toString();
        if (workingDays.contains(wd)) {
          selectedWorkingDays = wd;
        }
      }
      isFullyRemote = job['is_fully_remote'] == true;
      isHybrid = job['is_hybrid'] == true;

      final benefitsData = job['benefits'];
      if (benefitsData is List) {
        selectedBenefits = benefitsData.map((e) => e.toString()).toList();
      }

      final languagesData = job['languages_required'];
      if (languagesData is List) {
        selectedLanguages = languagesData.map((e) => e.toString()).toList();
      }
      otherLanguagesCtrl.text = job['other_languages']?.toString() ?? '';

      experienceDetailsCtrl.text =
          job['experience_details']?.toString() ?? '';

      // ==================== INTERVIEW TAB ====================
      isInterviewOnline = job['is_interview_online'] == true;
      interviewVenueCtrl.text = job['interview_venue']?.toString() ?? '';
      interviewLinkCtrl.text = job['interview_link']?.toString() ?? '';
      interviewDateCtrl.text = job['interview_date']?.toString() ?? '';
      interviewTimeCtrl.text = job['interview_time']?.toString() ?? '';

      final interviewDocsData = job['interview_documents'];
      if (interviewDocsData is List) {
        interviewDocuments =
            interviewDocsData.map((e) => e.toString()).toList();
      }

      final selectionStagesData = job['selection_stages'];
      if (selectionStagesData is List) {
        selectionStages =
            selectionStagesData.map((e) => e.toString()).toList();
      }
      selectionProcessDetailsCtrl.text =
          job['selection_process_details']?.toString() ?? '';

      hasBond = job['has_bond'] == true;
      bondDurationCtrl.text = job['bond_duration']?.toString() ?? '';
      bondAmountCtrl.text = job['bond_amount']?.toString() ?? '';
      bondTermsCtrl.text = job['bond_terms']?.toString() ?? '';

      contactPersonCtrl.text = job['contact_person']?.toString() ?? '';
      contactDesignationCtrl.text =
          job['contact_designation']?.toString() ?? '';
      contactEmailCtrl.text = job['contact_email']?.toString() ?? '';
      contactPhoneCtrl.text = job['contact_phone']?.toString() ?? '';

      importantNotesCtrl.text = job['important_notes']?.toString() ?? '';
      termsAndConditionsCtrl.text =
          job['terms_conditions']?.toString() ?? '';

      // ==================== NOTIFICATION TAB ====================
      final physicalEligibility = job['physical_eligibility'];
      if (physicalEligibility is Map && physicalEligibility.isNotEmpty) {
        _hasPhysicalRequirement = true;
        minHeightCtrl.text =
            physicalEligibility['min_height_cm']?.toString() ?? '';
        minHeightFemaleCtrl.text =
            physicalEligibility['min_height_female_cm']?.toString() ?? '';
        minChestCtrl.text =
            physicalEligibility['min_chest_cm']?.toString() ?? '';
        maxWeightCtrl.text =
            physicalEligibility['max_weight_kg']?.toString() ?? '';
        physicalRelaxationCtrl.text =
            physicalEligibility['relaxation']?.toString() ?? '';
      }

      _hasMedicalRequirement = job['has_medical_requirement'] == true ||
          (job['medical_standards'] != null &&
              job['medical_standards'].toString().isNotEmpty);
      medicalStandardsCtrl.text =
          job['medical_standards']?.toString() ?? '';

      // ==================== EXTRAS TAB ====================
      final trainingDetails = job['training_details'];
      if (job['has_training'] == true &&
          trainingDetails is Map &&
          trainingDetails.isNotEmpty) {
        _hasTraining = true;
        trainingDurationCtrl.text =
            trainingDetails['duration']?.toString() ?? '';
        trainingStipendCtrl.text =
            trainingDetails['stipend']?.toString() ?? '';
        trainingLocationCtrl.text =
            trainingDetails['location']?.toString() ?? '';
      }

      if (job['urgency_level'] != null) {
        final urgency = job['urgency_level'].toString();
        if (urgencyLevels.contains(urgency)) {
          selectedUrgency = urgency;
        }
      }

      if (job['gender_preference'] != null) {
        final gender = job['gender_preference'].toString();
        if (genderPreferences.contains(gender)) {
          selectedGenderPreference = gender;
        }
      }

      whatsappNumberCtrl.text = job['whatsapp_number']?.toString() ?? '';
      telegramChannelCtrl.text = job['telegram_channel']?.toString() ?? '';
      officialWebsiteCtrl.text = job['official_website']?.toString() ?? '';
      helplineNumberCtrl.text = job['helpline_number']?.toString() ?? '';
      helplineEmailCtrl.text = job['helpline_email']?.toString() ?? '';

      for (int i = 0; i < _tabCount; i++) {
        _tabSaveStatus[i] = true;
      }

      debugPrint("✅ Job data pre-filled successfully");
    } catch (e) {
      debugPrint("❌ Error pre-filling job data: $e");
    }
  }

  void _updateQualificationSubOptions() {
    setState(() {
      final selected = selectedQualificationFromEducation;
      selectedQualificationSubOption = null;
      selectedDegreeStream = null;
      selectedDegreeName = null;
      _qualificationSubOptions = [];
      _degreeStreams = [];
      _degreeNames = [];

      if (selected != null) {
        if (selected == '10th Pass' || selected == '12th Pass') {
          _qualificationSubOptions = [];
          _degreeStreams = [];
        } else if (_qualificationSubOptionsMap.containsKey(selected)) {
          _qualificationSubOptions = _qualificationSubOptionsMap[selected]!;
          _degreeStreams = [];
        } else if (_degreeStreamsMap.containsKey(selected)) {
          _qualificationSubOptions = [];
          _degreeStreams = _degreeStreamsMap[selected]!;
        }
      }
    });
  }

  void _updateDegreeNames() {
    setState(() {
      if (selectedDegreeStream != null &&
          _degreeSubjectsMap.containsKey(selectedDegreeStream)) {
        _degreeNames = _degreeSubjectsMap[selectedDegreeStream]!;
      } else {
        _degreeNames = [];
      }
      selectedDegreeName = null;
    });
  }

  void _loadCountries() {
    _countries = LocationData.getCountries();
    _selectedCountry = 'India';
    _states = LocationData.getStates('India');
    setState(() {});
  }

  void _setupLocationListeners() {
    cityVillageCtrl.addListener(_updateFullLocation);
  }

  void _updateFullLocation() {
    if (_useCurrentLocation) return;
    final cityVillage = cityVillageCtrl.text.trim();
    final district = _selectedDistrict ?? '';
    final state = _selectedState ?? '';
    final country = _selectedCountry ?? 'India';
    final List<String> parts = [];
    if (cityVillage.isNotEmpty) parts.add(cityVillage);
    if (district.isNotEmpty && district != cityVillage) parts.add(district);
    if (state.isNotEmpty) parts.add(state);
    if (country.isNotEmpty && country != 'India') parts.add(country);
    locationCtrl.text = parts.join(', ');
    _geocodedResult = null;
    _geocodingStatus = '';
  }

  void _onCountryChanged(String? country) {
    setState(() {
      _selectedCountry = country ?? 'India';
      _selectedState = null;
      _selectedDistrict = null;
      _states = LocationData.getStates(_selectedCountry!);
      _districts = [];
    });
    _updateFullLocation();
  }

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      if (_selectedCountry != null && _selectedState != null) {
        _districts = LocationData.getDistricts(
          _selectedCountry!,
          _selectedState!,
        );
      } else {
        _districts = [];
      }
    });
    _updateFullLocation();
  }

  void _onDistrictChanged(String? district) {
    setState(() => _selectedDistrict = district);
    _updateFullLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    organizationCtrl.dispose();
    postNameCtrl.dispose();
    cityVillageCtrl.dispose();
    locationCtrl.dispose();
    descriptionCtrl.dispose();
    lastDateCtrl.dispose();
    postDateCtrl.dispose();
    applyWithUsUrlCtrl.dispose();
    websiteUrlCtrl.dispose();
    officialNotificationUrlCtrl.dispose();
    ageCalcDateCtrl.dispose();
    ageRelaxationCtrl.dispose();
    postNameCtrl2.dispose();
    vacancyCtrl.dispose();
    postAgeMinCtrl.dispose();
    postAgeMaxCtrl.dispose();
    otherQualificationCtrl.dispose();
    educationDetailsCtrl.dispose();
    experienceDetailsCtrl.dispose();
    otherLanguagesCtrl.dispose();
    interviewVenueCtrl.dispose();
    interviewDateCtrl.dispose();
    interviewTimeCtrl.dispose();
    interviewLinkCtrl.dispose();
    contactPersonCtrl.dispose();
    contactDesignationCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
    importantNotesCtrl.dispose();
    termsAndConditionsCtrl.dispose();
    selectionProcessDetailsCtrl.dispose();
    bondDurationCtrl.dispose();
    bondAmountCtrl.dispose();
    bondTermsCtrl.dispose();
    admitCardDateCtrl.dispose();
    examDateCtrl.dispose();
    resultDateCtrl.dispose();
    officialWebsiteCtrl.dispose();
    helplineNumberCtrl.dispose();
    helplineEmailCtrl.dispose();
    payScaleCtrl.dispose();
    gradePayCtrl.dispose();
    payBandCtrl.dispose();
    minSalaryCtrl.dispose();
    maxSalaryCtrl.dispose();
    applicationStartDateCtrl.dispose();
    applicationEndDateCtrl.dispose();
    notificationNumberCtrl.dispose();
    notificationDateCtrl.dispose();
    examCityCtrl.dispose();
    minHeightCtrl.dispose();
    minHeightFemaleCtrl.dispose();
    minChestCtrl.dispose();
    maxWeightCtrl.dispose();
    physicalRelaxationCtrl.dispose();
    medicalStandardsCtrl.dispose();
    trainingDurationCtrl.dispose();
    trainingStipendCtrl.dispose();
    trainingLocationCtrl.dispose();
    whatsappNumberCtrl.dispose();
    telegramChannelCtrl.dispose();
    categoryNameCtrl.dispose();
    categoryVacancyCtrl.dispose();
    relaxationCategoryCtrl.dispose();
    relaxationYearsCtrl.dispose();
    feeCategoryCtrl.dispose();
    feeAmountCtrl.dispose();
    for (var controller in relaxationControllers.values) {
      controller.dispose();
    }
    for (var controller in feesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // TAB-WISE SAVE
  // ============================================================
  Map<String, dynamic> _buildTabData(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return {
          "organization": organizationCtrl.text.trim().isEmpty
              ? "Not Specified"
              : organizationCtrl.text.trim(),
          "post_name": postNameCtrl.text.trim().isEmpty
              ? "Untitled Job"
              : postNameCtrl.text.trim(),
          "location_text": _useCurrentLocation ? "" : locationCtrl.text.trim(),
          "job_type": jobType,
          "job_level": jobLevel,
          "category": category,
          "color_type": _colorType,
          "post_date": postDateCtrl.text.trim().isEmpty
              ? _getCurrentDate()
              : postDateCtrl.text.trim(),
          "use_current_location": _useCurrentLocation,
          "description": descriptionCtrl.text.trim(),
          "last_date": lastDateCtrl.text.trim(),
          "website_url": websiteUrlCtrl.text.trim(),
          "has_apply_with_us": hasApplyWithUs,
          "apply_with_us_url": hasApplyWithUs &&
                  applyWithUsUrlCtrl.text.trim().isNotEmpty
              ? applyWithUsUrlCtrl.text.trim()
              : null,
        };

      case 1:
        return {
          "multiple_posts": _showMultiplePosts ? _processMultiplePosts() : [],
          "total_posts": _showMultiplePosts ? _totalVacancySum : 0,
          "required_qualification": _getQualificationDisplayString(),
          "education_details": educationDetailsCtrl.text.trim(),
          "is_fresher_eligible": isFresherEligible,
          "is_experienced_eligible": isExperiencedEligible,
        };

      case 2:
        final Map<String, dynamic> tabData = {
          "age_calculation_date": ageCalcDateCtrl.text.trim(),
          "has_application_fees": _hasApplicationFees,
          "application_fees":
              _hasApplicationFees ? _processApplicationFees() : {},
        };
        final ageRelaxations = _processAgeRelaxations();
        if (ageRelaxations.isNotEmpty) {
          tabData["age_relaxation_by_category"] = ageRelaxations;
        }
        if (ageRelaxationCtrl.text.isNotEmpty) {
          tabData["age_relaxation_details"] = ageRelaxationCtrl.text.trim();
        }
        return tabData;

      case 3:
        return {
          "application_start_date": applicationStartDateCtrl.text.trim(),
          "application_end_date": applicationEndDateCtrl.text.trim(),
          "notification_number": notificationNumberCtrl.text.trim(),
          "notification_date": notificationDateCtrl.text.trim(),
          "application_mode": selectedApplicationMode,
          "exam_cities": examCities,
          "admit_card_date": admitCardDateCtrl.text.trim(),
          "exam_date": examDateCtrl.text.trim(),
          "result_date": resultDateCtrl.text.trim(),
        };

      case 4:
        return {
          "work_schedule": selectedWorkSchedule,
          "shift": selectedShift,
          "working_days": selectedWorkingDays,
          "is_fully_remote": isFullyRemote,
          "is_hybrid": isHybrid,
          "benefits": selectedBenefits,
          "languages_required": selectedLanguages,
          "other_languages": otherLanguagesCtrl.text.trim(),
          "experience_details": experienceDetailsCtrl.text.trim(),
        };

      case 5:
        return {
          "interview_venue":
              isInterviewOnline ? null : interviewVenueCtrl.text.trim(),
          "interview_link": isInterviewOnline &&
                  interviewLinkCtrl.text.trim().isNotEmpty
              ? interviewLinkCtrl.text.trim()
              : null,
          "interview_date": interviewDateCtrl.text.trim(),
          "interview_time": interviewTimeCtrl.text.trim(),
          "interview_documents": interviewDocuments,
          "selection_stages": selectionStages,
          "selection_process_details": selectionProcessDetailsCtrl.text.trim(),
          "has_bond": hasBond,
          "bond_duration": hasBond ? bondDurationCtrl.text.trim() : null,
          "bond_amount": hasBond && bondAmountCtrl.text.trim().isNotEmpty
              ? int.tryParse(bondAmountCtrl.text.trim())
              : null,
          "bond_terms": hasBond ? bondTermsCtrl.text.trim() : null,
          "contact_person": contactPersonCtrl.text.trim(),
          "contact_designation": contactDesignationCtrl.text.trim(),
          "contact_email": contactEmailCtrl.text.trim(),
          "contact_phone": contactPhoneCtrl.text.trim(),
          "important_notes": importantNotesCtrl.text.trim(),
          "terms_conditions": termsAndConditionsCtrl.text.trim(),
        };

      case 6:
        // ✅ FIX: Correctly structure the notification data for the backend
        return {
          "has_official_notification": hasOfficialNotificationLink,
          "official_notification_link": hasOfficialNotificationLink
              ? officialNotificationUrlCtrl.text.trim()
              : null,
          "advertisement_url": null, // This is set during the final publish/update step
          "advertisement_download_url": null,
          "has_physical_requirement": _hasPhysicalRequirement,
          "physical_eligibility":
              _hasPhysicalRequirement ? _processPhysicalEligibility() : null,
          "has_medical_requirement": _hasMedicalRequirement,
          "medical_standards": _hasMedicalRequirement &&
                  medicalStandardsCtrl.text.trim().isNotEmpty
              ? medicalStandardsCtrl.text.trim()
              : null,
        };

      case 7:
        return {
          "has_training": _hasTraining,
          "training_details": _hasTraining ? _processTrainingDetails() : null,
          "urgency_level": selectedUrgency,
          "gender_preference": selectedGenderPreference,
          "whatsapp_number": whatsappNumberCtrl.text.trim(),
          "telegram_channel": telegramChannelCtrl.text.trim(),
          "official_website": officialWebsiteCtrl.text.trim(),
          "helpline_number": helplineNumberCtrl.text.trim(),
          "helpline_email": helplineEmailCtrl.text.trim(),
        };

      default:
        return {};
    }
  }

  // ✅ FIXED: safe age parsing in _processMultiplePosts
  List<Map<String, dynamic>> _processMultiplePosts() {
    List<Map<String, dynamic>> processedPosts = [];
    for (var post in multiplePosts) {
      Map<String, dynamic> processedPost = {
        'post_name': post['post_name'],
        'total_posts': post['total_posts'],
        'qualification': post['qualification'],
        'qualification_main': post['qualification_main'],
        'qualification_sub': post['qualification_sub'],
        'degree_stream': post['degree_stream'],
        'degree_name': post['degree_name'],
        'other_qualification_details': post['other_qualification_details'] ?? '',
        'experience_details': post['experience_details'] ?? '',
      };

      // ✅ Safe age handling
      final ageMinStr = _safeAgeToString(post['age_min']);
      if (ageMinStr.isNotEmpty) {
        final parsedMin = int.tryParse(ageMinStr);
        if (parsedMin != null) {
          processedPost['age_min'] = parsedMin;
        }
      }

      final ageMaxStr = _safeAgeToString(post['age_max']);
      if (ageMaxStr.isNotEmpty) {
        final parsedMax = int.tryParse(ageMaxStr);
        if (parsedMax != null) {
          processedPost['age_max'] = parsedMax;
        }
      }

      if (post['pay_scales'] != null &&
          (post['pay_scales'] as List).isNotEmpty) {
        processedPost['pay_scales'] = post['pay_scales'];
      }
      if (post['category_vacancies'] != null &&
          (post['category_vacancies'] as List).isNotEmpty) {
        final Map<String, dynamic> postReservation = {};
        for (var cat in post['category_vacancies']) {
          postReservation[cat['name'].toLowerCase().replaceAll('/', '_')] =
              cat['vacancy'];
        }
        if (postReservation.isNotEmpty) {
          processedPost['reservation_vacancy'] = postReservation;
        }
      }
      processedPosts.add(processedPost);
    }
    return processedPosts;
  }

  Map<String, dynamic> _processAgeRelaxations() {
    Map<String, dynamic> ageRelaxations = {};
    for (var entry in relaxationValues.entries) {
      if (entry.value.isNotEmpty) {
        final years = int.tryParse(entry.value);
        if (years != null && years > 0) {
          ageRelaxations[entry.key.toLowerCase()] = years;
        }
      }
    }
    return ageRelaxations;
  }

  Map<String, dynamic> _processApplicationFees() {
    Map<String, dynamic> applicationFees = {};
    for (var entry in feesValues.entries) {
      if (entry.value.isNotEmpty) {
        final amount = int.tryParse(entry.value);
        if (amount != null && amount > 0) {
          applicationFees[entry.key.toLowerCase()] = amount;
        }
      }
    }
    return applicationFees;
  }

  Map<String, dynamic> _processPhysicalEligibility() {
    final Map<String, dynamic> physical = {};
    if (minHeightCtrl.text.isNotEmpty) {
      physical["min_height_cm"] = minHeightCtrl.text.trim();
    }
    if (minHeightFemaleCtrl.text.isNotEmpty) {
      physical["min_height_female_cm"] = minHeightFemaleCtrl.text.trim();
    }
    if (minChestCtrl.text.isNotEmpty) {
      physical["min_chest_cm"] = minChestCtrl.text.trim();
    }
    if (maxWeightCtrl.text.isNotEmpty) {
      physical["max_weight_kg"] = maxWeightCtrl.text.trim();
    }
    if (physicalRelaxationCtrl.text.isNotEmpty) {
      physical["relaxation"] = physicalRelaxationCtrl.text.trim();
    }
    return physical;
  }

  Map<String, dynamic> _processTrainingDetails() {
    final Map<String, dynamic> training = {};
    if (trainingDurationCtrl.text.isNotEmpty) {
      training["duration"] = trainingDurationCtrl.text.trim();
    }
    if (trainingStipendCtrl.text.isNotEmpty) {
      training["stipend"] = int.tryParse(trainingStipendCtrl.text.trim());
    }
    if (trainingLocationCtrl.text.isNotEmpty) {
      training["location"] = trainingLocationCtrl.text.trim();
    }
    return training;
  }

  Future<bool> _saveCurrentTab() async {
    if (_isSavingDraft) return false;
    setState(() => _isSavingDraft = true);

    try {
      final tabData = _buildTabData(_currentTabIndex);

      if (!_useCurrentLocation && _geocodedResult != null) {
        tabData["job_location"] = {
          "latitude": _geocodedResult!['latitude'],
          "longitude": _geocodedResult!['longitude'],
          "location_name": locationCtrl.text.trim(),
          "city": _geocodedResult!['city'],
          "district": _geocodedResult!['district'],
          "state": _geocodedResult!['state'],
          "country": _geocodedResult!['country'],
          "is_geocoded": true,
          "geocoded_at": DateTime.now().toIso8601String(),
          "source": _geocodedResult!['source'],
        };
      }

      final token = await SecureStorage.getToken();
      if (token == null) {
        throw Exception("No authentication token found");
      }

      Map<String, dynamic> response;

      if (_draftJobId == null) {
        final apiEndpoint = _getApiEndpoint();
        final res = await DioClient.dio.post(
          apiEndpoint,
          data: {
            ...tabData,
            "status": "draft",
            "is_draft": true,
            "current_tab": _currentTabIndex,
            "tab_${_currentTabIndex}_saved": true,
          },
        );

        response = res.data;

        if (response['data'] != null && response['data']['_id'] != null) {
          _draftJobId = response['data']['_id'].toString();
        } else if (response['_id'] != null) {
          _draftJobId = response['_id'].toString();
        } else if (response['id'] != null) {
          _draftJobId = response['id'].toString();
        }

        debugPrint("✅ Draft job created: $_draftJobId");
      } else {
        final apiEndpoint = _getApiEndpoint();
        await DioClient.dio.put(
          '$apiEndpoint/$_draftJobId',
          data: {
            ...tabData,
            "current_tab": _currentTabIndex,
            "tab_${_currentTabIndex}_saved": true,
          },
        );
        debugPrint("✅ Draft job updated: $_draftJobId");
      }

      _tabSaveStatus[_currentTabIndex] = true;

      if (mounted) {
        showMessage(context, "✅ ${_safeTabLabel} saved successfully!");
      }

      return true;
    } catch (e) {
      debugPrint("❌ Tab save error: $e");
      if (mounted) {
        showMessage(context, "Failed to save: ${e.toString()}", isError: true);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }
  }

  Future<void> _saveAndGoToNextTab() async {
    final saved = await _saveCurrentTab();
    if (!saved) return;
    if (_currentTabIndex < _tabCount - 1) {
      _tabController.animateTo(_currentTabIndex + 1);
    }
  }

  // ============================================================
  // BLUE/WHITE COLOR IDENTIFICATION
  // ============================================================
  String _getColorTypeDescription() {
    switch (_colorType) {
      case 'blue':
        return '🔵 Blue Collar Job (Labour, Driver, Security, etc.)';
      case 'white':
        return '⚪ White Collar Job (Office, IT, Management, etc.)';
      case 'green':
        return '🟢 Green Collar Job (Environment, Agriculture, etc.)';
      case 'red':
        return '🔴 Red Collar Job (Emergency, Defense, etc.)';
      case 'orange':
        return '🟠 Orange Collar Job (Construction, Mining, etc.)';
      case 'purple':
        return '🟣 Purple Collar Job (Creative, Design, etc.)';
      case 'teal':
        return '🩵 Teal Collar Job (Healthcare, Medical, etc.)';
      case 'pink':
        return '🩷 Pink Collar Job (Care, Beauty, etc.)';
      case 'indigo':
        return '🔵 Indigo Collar Job (Education, Training, etc.)';
      case 'amber':
        return '🟡 Amber Collar Job (Hospitality, Tourism, etc.)';
      case 'cyan':
        return '🩵 Cyan Collar Job (Water, Marine, etc.)';
      case 'grey':
        return '⚫ Grey Collar Job (General, Others)';
      default:
        return '🔵 Blue Collar Job';
    }
  }

  String _getSuggestedColor() {
    final jobTitle = postNameCtrl.text.toLowerCase();
    final jobCategory = category.toLowerCase();

    final blueCollarKeywords = [
      'driver', 'security', 'guard', 'labour', 'labor', 'worker',
      'helper', 'cleaner', 'sweeper', 'mali', 'gardener',
      'plumber', 'electrician', 'carpenter', 'painter', 'welder',
      'mechanic', 'fitter', 'mason', 'construction', 'factory',
      'warehouse', 'packing', 'loading', 'delivery', 'courier',
    ];

    final whiteCollarKeywords = [
      'manager', 'engineer', 'developer', 'analyst', 'consultant',
      'executive', 'officer', 'director', 'architect', 'designer',
      'accountant', 'auditor', 'lawyer', 'doctor', 'teacher',
      'professor', 'scientist', 'researcher', 'administrator',
      'coordinator', 'supervisor', 'team lead', 'project',
    ];

    for (final keyword in blueCollarKeywords) {
      if (jobTitle.contains(keyword)) return 'blue';
    }
    for (final keyword in whiteCollarKeywords) {
      if (jobTitle.contains(keyword)) return 'white';
    }

    switch (jobCategory) {
      case 'it':
      case 'marketing':
      case 'finance':
      case 'hr':
      case 'banking':
        return 'white';
      case 'engineering':
      case 'healthcare':
      case 'teaching':
        return 'white';
      case 'defense':
      case 'government':
        return 'blue';
      case 'operations':
      case 'sales':
        return 'blue';
      default:
        return 'blue';
    }
  }

  // ============================================================
  // API ENDPOINTS
  // ============================================================
  String _getApiEndpoint() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs';
      case 'superadmin':
        return '/admin/add-job';
      default:
        return '/admin/add-job';
    }
  }

  String _getUploadEndpoint() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs/upload-advertisement';
      case 'superadmin':
        return '/admin/add-job-with-advertisement';
      default:
        return '/admin/add-job-with-advertisement';
    }
  }

  String _getUpdateEndpoint(String jobId) {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs/$jobId';
      case 'superadmin':
        return '/admin/jobs/$jobId';
      default:
        return '/admin/jobs/$jobId';
    }
  }

  String _getPublishEndpoint(String jobId) {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs/$jobId/publish';
      case 'superadmin':
        return '/admin/jobs/$jobId/publish';
      default:
        return '/admin/jobs/$jobId/publish';
    }
  }

  // ============================================================
  // FILE PICKER
  // ============================================================
  Future<void> _pickAdvertisement() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && mounted) {
        final file = result.files.first;
        if (file.size > maxFileSizeBytes) {
          final fileSizeMB = (file.size / (1024 * 1024)).toStringAsFixed(1);
          if (mounted) {
            showMessage(
              context,
              "❌ File size ($fileSizeMB MB) exceeds $maxFileSizeMB MB limit.",
              isError: true,
            );
          }
          return;
        }
        setState(() {
          selectedFileName = file.name;
          selectedFileBytes = file.bytes;
          selectedFileMimeType = _getMimeType(file.name);
          hasAdvertisementFile = true;
        });
        if (mounted) {
          showMessage(context, "✅ File selected: ${file.name}",
              isError: false);
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Error picking file: $e", isError: true);
      }
    }
  }

  void _clearAdvertisementFile() {
    setState(() {
      selectedFileName = null;
      selectedFileBytes = null;
      selectedFileMimeType = null;
      hasAdvertisementFile = false;
    });
  }

  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // MULTIPLE POST METHODS
  // ============================================================
  int get _totalVacancySum {
    int sum = 0;
    for (var post in multiplePosts) {
      sum += (post['total_posts'] as int);
    }
    return sum;
  }

  int _getTotalCategoryVacancySum(int postIndex) {
    int sum = 0;
    var categories = multiplePosts[postIndex]['category_vacancies'];
    if (categories != null) {
      for (var cat in categories) {
        sum += (cat['vacancy'] as int);
      }
    }
    return sum;
  }

  String _getQualificationDisplayString() {
    if (selectedDegreeName != null && selectedDegreeName!.isNotEmpty) {
      return selectedDegreeName!;
    }
    if (selectedDegreeStream != null && selectedDegreeStream!.isNotEmpty) {
      return selectedDegreeStream!;
    }
    if (selectedQualificationSubOption != null &&
        selectedQualificationSubOption!.isNotEmpty) {
      return selectedQualificationSubOption!;
    }
    if (selectedQualificationFromEducation != null &&
        selectedQualificationFromEducation!.isNotEmpty) {
      return selectedQualificationFromEducation!;
    }
    return 'Any Graduate';
  }

  // ✅ FIXED: _savePost stores age as String (controller-safe)
  void _savePost() {
    final postName = postNameCtrl2.text.trim();
    final vacancy = int.tryParse(vacancyCtrl.text.trim());

    if (postName.isEmpty) {
      showMessage(context, "Post name is required", isError: true);
      return;
    }
    if (vacancy == null || vacancy <= 0) {
      showMessage(context, "Valid number of vacancies is required",
          isError: true);
      return;
    }

    final postData = {
      'post_name': postName,
      'total_posts': vacancy,
      'qualification': _getQualificationDisplayString(),
      'qualification_main': selectedQualificationFromEducation ?? '',
      'qualification_sub': selectedQualificationSubOption ?? '',
      'degree_stream': selectedDegreeStream ?? '',
      'degree_name': selectedDegreeName ?? '',
      'other_qualification_details': otherQualificationCtrl.text.trim(),
      'experience_details': experienceDetailsCtrl.text.trim(),
      // ✅ Store age as String (kept controller-safe)
      'age_min': postAgeMinCtrl.text.trim(),
      'age_max': postAgeMaxCtrl.text.trim(),
      'pay_scales': (_isEditingPost && _editingPostIndex != null)
          ? (multiplePosts[_editingPostIndex!]['pay_scales'] ?? [])
          : [],
      'category_vacancies': (_isEditingPost && _editingPostIndex != null)
          ? (multiplePosts[_editingPostIndex!]['category_vacancies'] ?? [])
          : [],
    };

    setState(() {
      if (_isEditingPost && _editingPostIndex != null) {
        multiplePosts[_editingPostIndex!] = postData;
        showMessage(context, "Post updated successfully");
      } else {
        multiplePosts.add(postData);
        showMessage(context, "Post added successfully");
      }
      _isEditingPost = false;
      _editingPostIndex = null;
    });

    postNameCtrl2.clear();
    vacancyCtrl.clear();
    selectedQualificationFromEducation = null;
    selectedQualificationSubOption = null;
    selectedDegreeStream = null;
    selectedDegreeName = null;
    _qualificationSubOptions = [];
    _degreeStreams = [];
    _degreeNames = [];
    postAgeMinCtrl.clear();
    postAgeMaxCtrl.clear();
    otherQualificationCtrl.clear();
    experienceDetailsCtrl.clear();
  }

  // ✅ FIXED: _startEditPost uses safe age conversion
  void _startEditPost(int index) {
    final post = multiplePosts[index];
    setState(() {
      _isEditingPost = true;
      _editingPostIndex = index;
      postNameCtrl2.text = post['post_name']?.toString() ?? '';
      vacancyCtrl.text = (post['total_posts'] ?? 1).toString();
      selectedQualificationFromEducation = post['qualification_main'];
      selectedQualificationSubOption = post['qualification_sub'];
      selectedDegreeStream = post['degree_stream'];
      selectedDegreeName = post['degree_name'];
      otherQualificationCtrl.text =
          post['other_qualification_details']?.toString() ?? '';
      experienceDetailsCtrl.text =
          post['experience_details']?.toString() ?? '';
      _updateQualificationSubOptions();
      if (selectedDegreeStream != null && selectedDegreeStream!.isNotEmpty) {
        _updateDegreeNames();
      }
      // ✅ Safe age to String conversion
      postAgeMinCtrl.text = _safeAgeToString(post['age_min']);
      postAgeMaxCtrl.text = _safeAgeToString(post['age_max']);
    });
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: Text(
          "Are you sure you want to delete \"${multiplePosts[index]['post_name']}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => multiplePosts.removeAt(index));
              Navigator.pop(context);
              showMessage(context, "Post deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _cancelEditPost() {
    setState(() {
      _isEditingPost = false;
      _editingPostIndex = null;
      postNameCtrl2.clear();
      vacancyCtrl.clear();
      selectedQualificationFromEducation = null;
      selectedQualificationSubOption = null;
      selectedDegreeStream = null;
      selectedDegreeName = null;
      _qualificationSubOptions = [];
      _degreeStreams = [];
      _degreeNames = [];
      postAgeMinCtrl.clear();
      postAgeMaxCtrl.clear();
      otherQualificationCtrl.clear();
      experienceDetailsCtrl.clear();
    });
  }

  // ============================================================
  // PAY SCALE METHODS
  // ============================================================
  void _startEditPayScale(int postIndex, int payScaleIndex) {
    final payScale = multiplePosts[postIndex]['pay_scales'][payScaleIndex];
    setState(() {
      _selectedPostForPayScale = postIndex;
      _isEditingPayScale = true;
      _editingPayScaleIndex = payScaleIndex;
      payScaleCtrl.text = payScale['pay_scale'] ?? '';
      gradePayCtrl.text = payScale['grade_pay'] ?? '';
      payBandCtrl.text = payScale['pay_band'] ?? '';
      minSalaryCtrl.text = payScale['min_salary']?.toString() ?? '';
      maxSalaryCtrl.text = payScale['max_salary']?.toString() ?? '';
    });
  }

  void _savePayScaleForPost() {
    if (_selectedPostForPayScale == null) {
      showMessage(context, "Please select a post first", isError: true);
      return;
    }

    final payScale = payScaleCtrl.text.trim();

    if (payScale.isEmpty &&
        gradePayCtrl.text.trim().isEmpty &&
        payBandCtrl.text.trim().isEmpty &&
        minSalaryCtrl.text.trim().isEmpty &&
        maxSalaryCtrl.text.trim().isEmpty) {
      showMessage(context, "No pay scale data entered. Skipping...");
      _cancelPayScaleForm();
      return;
    }

    final payScaleData = {
      'pay_scale': payScale.isEmpty ? null : payScale,
      'grade_pay':
          gradePayCtrl.text.trim().isEmpty ? null : gradePayCtrl.text.trim(),
      'pay_band':
          payBandCtrl.text.trim().isEmpty ? null : payBandCtrl.text.trim(),
      'min_salary': minSalaryCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(minSalaryCtrl.text.trim()),
      'max_salary': maxSalaryCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(maxSalaryCtrl.text.trim()),
    };

    setState(() {
      if (multiplePosts[_selectedPostForPayScale!]['pay_scales'] == null) {
        multiplePosts[_selectedPostForPayScale!]['pay_scales'] = [];
      }
      if (_isEditingPayScale && _editingPayScaleIndex != null) {
        multiplePosts[_selectedPostForPayScale!]['pay_scales']
            [_editingPayScaleIndex!] = payScaleData;
        showMessage(context, "Pay scale updated successfully");
      } else {
        multiplePosts[_selectedPostForPayScale!]['pay_scales']
            .add(payScaleData);
        showMessage(context, "Pay scale added successfully");
      }
    });

    payScaleCtrl.clear();
    gradePayCtrl.clear();
    payBandCtrl.clear();
    minSalaryCtrl.clear();
    maxSalaryCtrl.clear();
    _selectedPostForPayScale = null;
    _isEditingPayScale = false;
    _editingPayScaleIndex = null;
  }

  void _deletePayScaleFromPost(int postIndex, int payScaleIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pay Scale"),
        content: const Text("Are you sure you want to delete this pay scale?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                multiplePosts[postIndex]['pay_scales'].removeAt(payScaleIndex);
              });
              Navigator.pop(context);
              showMessage(context, "Pay scale deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _cancelPayScaleForm() {
    setState(() {
      _selectedPostForPayScale = null;
      _isEditingPayScale = false;
      _editingPayScaleIndex = null;
      payScaleCtrl.clear();
      gradePayCtrl.clear();
      payBandCtrl.clear();
      minSalaryCtrl.clear();
      maxSalaryCtrl.clear();
    });
  }

  // ============================================================
  // CATEGORY VACANCY METHODS
  // ============================================================
  void _saveCategoryForPost() {
    if (_editingCategoryPostIndex == null) {
      showMessage(context, "Please select a post first", isError: true);
      return;
    }
    final name = categoryNameCtrl.text.trim();
    final vacancy = int.tryParse(categoryVacancyCtrl.text.trim());

    if (name.isEmpty) {
      showMessage(context, "Category name is required", isError: true);
      return;
    }
    if (vacancy == null || vacancy <= 0) {
      showMessage(context, "Valid vacancy number is required", isError: true);
      return;
    }

    setState(() {
      if (multiplePosts[_editingCategoryPostIndex!]['category_vacancies'] ==
          null) {
        multiplePosts[_editingCategoryPostIndex!]['category_vacancies'] = [];
      }
      if (_isEditingCategory && _editingCategoryIndex != null) {
        multiplePosts[_editingCategoryPostIndex!]['category_vacancies']
            [_editingCategoryIndex!] = {'name': name, 'vacancy': vacancy};
        showMessage(context, "Category updated successfully");
      } else {
        multiplePosts[_editingCategoryPostIndex!]['category_vacancies'].add({
          'name': name,
          'vacancy': vacancy,
        });
        showMessage(context, "Category added successfully");
      }
      _editingCategoryPostIndex = null;
      _isEditingCategory = false;
      _editingCategoryIndex = null;
      categoryNameCtrl.clear();
      categoryVacancyCtrl.clear();
    });
  }

  void _startAddCategoryForPost(int postIndex) {
    setState(() {
      _editingCategoryPostIndex = postIndex;
      _isEditingCategory = false;
      _editingCategoryIndex = null;
      categoryNameCtrl.clear();
      categoryVacancyCtrl.clear();
    });
  }

  void _startEditCategoryForPost(int postIndex, int catIndex) {
    final cat = multiplePosts[postIndex]['category_vacancies'][catIndex];
    setState(() {
      _editingCategoryPostIndex = postIndex;
      _isEditingCategory = true;
      _editingCategoryIndex = catIndex;
      categoryNameCtrl.text = cat['name'];
      categoryVacancyCtrl.text = cat['vacancy'].toString();
    });
  }

  void _cancelCategoryForPostForm() {
    setState(() {
      _editingCategoryPostIndex = null;
      _isEditingCategory = false;
      _editingCategoryIndex = null;
      categoryNameCtrl.clear();
      categoryVacancyCtrl.clear();
    });
  }

  void _deleteCategoryFromPost(int postIndex, int catIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Category"),
        content: Text(
          "Are you sure you want to delete \"${multiplePosts[postIndex]['category_vacancies'][catIndex]['name']}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                multiplePosts[postIndex]['category_vacancies']
                    .removeAt(catIndex);
              });
              Navigator.pop(context);
              showMessage(context, "Category deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AGE RELAXATION METHODS
  // ============================================================
  void _saveRelaxation() {
    final category = relaxationCategoryCtrl.text.trim();
    final years = relaxationYearsCtrl.text.trim();

    if (category.isEmpty) {
      showMessage(context, "Please select a category", isError: true);
      return;
    }
    if (years.isEmpty || int.tryParse(years) == null) {
      showMessage(context, "Valid years is required", isError: true);
      return;
    }

    setState(() {
      relaxationValues[category] = years;
      if (relaxationControllers.containsKey(category)) {
        relaxationControllers[category]?.text = years;
      } else {
        relaxationControllers[category] = TextEditingController(text: years);
      }
      relaxationCategoryCtrl.clear();
      relaxationYearsCtrl.clear();
      _isEditingRelaxation = false;
      _editingRelaxationCategory = null;
    });
    showMessage(context, "Age relaxation saved for $category");
  }

  void _startEditRelaxation(String category, String years) {
    setState(() {
      _isEditingRelaxation = true;
      _editingRelaxationCategory = category;
      relaxationCategoryCtrl.text = category;
      relaxationYearsCtrl.text = years;
    });
  }

  void _cancelRelaxationForm() {
    setState(() {
      _isEditingRelaxation = false;
      _editingRelaxationCategory = null;
      relaxationCategoryCtrl.clear();
      relaxationYearsCtrl.clear();
    });
  }

  void _deleteRelaxation(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Age Relaxation"),
        content: Text(
          "Are you sure you want to delete relaxation for $category?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                relaxationValues.remove(category);
                if (relaxationControllers.containsKey(category)) {
                  relaxationControllers[category]?.clear();
                }
              });
              Navigator.pop(context);
              showMessage(context, "Age relaxation deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLICATION FEES METHODS
  // ============================================================
  void _saveApplicationFee() {
    final category = feeCategoryCtrl.text.trim();
    final amount = feeAmountCtrl.text.trim();

    if (category.isEmpty) {
      showMessage(context, "Category is required", isError: true);
      return;
    }
    if (amount.isEmpty || int.tryParse(amount) == null) {
      showMessage(context, "Valid fee amount is required", isError: true);
      return;
    }

    setState(() {
      feesValues[category] = amount;
      if (feesControllers.containsKey(category)) {
        feesControllers[category]?.text = amount;
      } else {
        feesControllers[category] = TextEditingController(text: amount);
      }
      feeCategoryCtrl.clear();
      feeAmountCtrl.clear();
      _isEditingFee = false;
      _editingFeeCategory = null;
    });
    showMessage(context, "Application fee saved for $category");
  }

  void _startEditFee(String category, String amount) {
    setState(() {
      _isEditingFee = true;
      _editingFeeCategory = category;
      feeCategoryCtrl.text = category;
      feeAmountCtrl.text = amount;
    });
  }

  void _cancelFeeForm() {
    setState(() {
      _isEditingFee = false;
      _editingFeeCategory = null;
      feeCategoryCtrl.clear();
      feeAmountCtrl.clear();
    });
  }

  void _deleteFee(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Application Fee"),
        content: Text(
          "Are you sure you want to delete application fee for $category?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                feesValues.remove(category);
                if (feesControllers.containsKey(category)) {
                  feesControllers[category]?.clear();
                }
              });
              Navigator.pop(context);
              showMessage(context, "Application fee deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXAM CITY METHODS
  // ============================================================
  void _addExamCity() {
    final city = examCityCtrl.text.trim();
    if (city.isEmpty) {
      showMessage(context, "Please enter exam city name", isError: true);
      return;
    }
    setState(() {
      examCities.add(city);
      examCityCtrl.clear();
    });
    showMessage(context, "Exam city added");
  }

  void _deleteExamCity(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Exam City"),
        content: Text(
          "Are you sure you want to delete \"${examCities[index]}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => examCities.removeAt(index));
              Navigator.pop(context);
              showMessage(context, "Exam city deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION METHODS
  // ============================================================
  Future<void> _refreshNotificationCount() async {
    try {
      await NotificationService.getUnreadCount();
    } catch (e) {
      debugPrint("Error refreshing notification count: $e");
    }
  }

  void _toggleCurrentLocation(bool value) async {
    if (value) {
      if (mounted) {
        setState(() {
          _useCurrentLocation = true;
          _locationStatus = "Checking location...";
          _isGettingLocation = true;
        });
      }
      try {
        final token = await SecureStorage.getToken();
        if (token != null) {
          final response = await DioClient.dio.get('/auth/my-location');
          if (mounted && response.data['has_location'] == true) {
            final location = response.data['location'];
            if (mounted) {
              setState(() {
                _locationStatus =
                    "✅ Using: ${location['location_name'] ?? 'Saved location'}";
              });
            }
            cityVillageCtrl.clear();
            locationCtrl.clear();
            if (mounted) {
              setState(() {
                _selectedCountry = 'India';
                _selectedState = null;
                _selectedDistrict = null;
                _geocodedResult = null;
              });
            }
          } else {
            if (mounted) {
              setState(() => _locationStatus = "⚠️ No saved location found.");
            }
          }
        } else {
          if (mounted) {
            setState(() => _locationStatus = "⚠️ Please login again");
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _locationStatus = "⚠️ Could not fetch location");
        }
      } finally {
        if (mounted) {
          setState(() => _isGettingLocation = false);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _useCurrentLocation = false;
          _locationStatus = "";
          _selectedCountry = 'India';
          _states = LocationData.getStates('India');
          _geocodedResult = null;
          _geocodingStatus = '';
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    if (mounted) {
      setState(() {
        _isGeocoding = true;
        _geocodingStatus = 'Searching for coordinates...';
        _geocodedResult = null;
      });
    }
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1&countrycodes=in&addressdetails=1',
        ),
        headers: {'User-Agent': 'rojgarnest/1.0'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final addressData = data[0]['address'] as Map<String, dynamic>?;
          final result = {
            'latitude': lat,
            'longitude': lon,
            'city': addressData?['city'] ??
                addressData?['town'] ??
                addressData?['village'] ??
                cityVillageCtrl.text.trim(),
            'district': addressData?['state_district'] ??
                addressData?['county'] ??
                _selectedDistrict,
            'state': addressData?['state'] ?? _selectedState,
            'country': 'India',
            'source': 'openstreetmap',
          };
          if (mounted) {
            setState(() {
              _geocodingStatus = '✅ Coordinates found!';
              _geocodedResult = result;
            });
          }
          return result;
        }
      }
      if (mounted) {
        setState(() => _geocodingStatus = '❌ Could not find coordinates');
      }
      return null;
    } catch (e) {
      if (mounted) {
        setState(() => _geocodingStatus = '❌ Error finding location');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _findCoordinates() async {
    if (_useCurrentLocation) {
      if (mounted) {
        showMessage(
          context,
          "Cannot find coordinates when using current location",
          isError: true,
        );
      }
      return;
    }
    final locationText = locationCtrl.text.trim();
    if (locationText.isEmpty) {
      if (mounted) {
        showMessage(context, "Please select location first", isError: true);
      }
      return;
    }
    final result = await _geocodeAddress(locationText);
    if (result != null && mounted) {
      showMessage(
        context,
        "✅ Location found! Lat: ${result['latitude'].toStringAsFixed(6)}, Lon: ${result['longitude'].toStringAsFixed(6)}",
      );
    }
  }

  // ============================================================
  // PUBLISH / UPDATE
  // ============================================================
  bool _hasAnyNotification() {
    return (hasOfficialNotificationLink &&
            officialNotificationUrlCtrl.text.trim().isNotEmpty) ||
        (hasAdvertisementFile && selectedFileBytes != null);
  }

  /// ✅ FINAL FIX: This method now correctly assembles all job data,
  /// handles file uploads, and sends a complete payload to the backend.
  Future<void> _publishJob() async {
    if (!_hasAnyNotification()) {
      if (mounted) {
        showMessage(
          context,
          "⚠️ Please provide either Official Notification PDF Link OR upload an Advertisement file before publishing",
          isError: true,
        );
      }
      _tabController.animateTo(6);
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      // First, save all tabs to create or update the draft job
      if (_draftJobId == null) {
        showMessage(context, "Saving all tabs first...", isError: false);
        for (int i = 0; i < _tabCount; i++) {
          _currentTabIndex = i;
          final saved = await _saveCurrentTab();
          if (!saved) {
            showMessage(context, "Failed to save tab ${_tabLabels[i]}",
                isError: true);
            return;
          }
        }
      }

      // Now, assemble the final complete job data from all tabs
      final Map<String, dynamic> finalJobData = {
        "status": "open",
        "is_draft": false,
        ..._buildTabData(0),
        ..._buildTabData(1),
        ..._buildTabData(2),
        ..._buildTabData(3),
        ..._buildTabData(4),
        ..._buildTabData(5),
        ..._buildTabData(6),
        ..._buildTabData(7),
      };

      if (!_useCurrentLocation && _geocodedResult != null) {
        finalJobData["job_location"] = {
          "latitude": _geocodedResult!['latitude'],
          "longitude": _geocodedResult!['longitude'],
          "location_name": locationCtrl.text.trim(),
          "city": _geocodedResult!['city'],
          "district": _geocodedResult!['district'],
          "state": _geocodedResult!['state'],
          "country": _geocodedResult!['country'],
          "is_geocoded": true,
          "geocoded_at": DateTime.now().toIso8601String(),
          "source": _geocodedResult!['source'],
        };
      }

      // Handle advertisement file upload if a file is selected
      if (hasAdvertisementFile && selectedFileBytes != null && selectedFileName != null) {
        if (mounted) setState(() => isUploading = true);
        
        final token = await SecureStorage.getToken();
        if (token == null) {
          throw Exception("No authentication token found");
        }
        
        final uri = Uri.parse('${ApiConfig.baseUrl}${_getUploadEndpoint()}');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';
        
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          selectedFileBytes!,
          filename: selectedFileName!,
          contentType: selectedFileMimeType != null
              ? MediaType.parse(selectedFileMimeType!)
              : null,
        );
        request.files.add(multipartFile);
        
        request.fields['job_data'] = jsonEncode(finalJobData);
        if (_draftJobId != null) {
          request.fields['job_id'] = _draftJobId!;
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (mounted && response.statusCode == 200) {
          showMessage(context, "✅ Job published successfully with advertisement!");
          await _refreshNotificationCount();
          _clearForm();
          if (mounted && widget.onJobAdded != null) {
            widget.onJobAdded!();
          }
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? "Upload failed: ${response.statusCode}");
        }
      } else {
        // No file to upload, just send the job data as JSON
        if (_draftJobId != null) {
          await DioClient.dio.put(_getUpdateEndpoint(_draftJobId!), data: finalJobData);
          await DioClient.dio.post(_getPublishEndpoint(_draftJobId!));
        } else {
          await DioClient.dio.post(_getApiEndpoint(), data: finalJobData);
        }
        if (mounted) {
          showMessage(context, "✅ Job published successfully!");
        }
        await _refreshNotificationCount();
        _clearForm();
        if (mounted && widget.onJobAdded != null) {
          widget.onJobAdded!();
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          "Failed to publish job: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isUploading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE UPDATES (EDIT MODE)
  // ============================================================
  Future<void> _saveUpdates() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      // Assemble the final complete job data from all tabs
      final Map<String, dynamic> updatedJobData = {
        ..._buildTabData(0),
        ..._buildTabData(1),
        ..._buildTabData(2),
        ..._buildTabData(3),
        ..._buildTabData(4),
        ..._buildTabData(5),
        ..._buildTabData(6),
        ..._buildTabData(7),
      };

      if (!_useCurrentLocation && _geocodedResult != null) {
        updatedJobData["job_location"] = {
          "latitude": _geocodedResult!['latitude'],
          "longitude": _geocodedResult!['longitude'],
          "location_name": locationCtrl.text.trim(),
          "city": _geocodedResult!['city'],
          "district": _geocodedResult!['district'],
          "state": _geocodedResult!['state'],
          "country": _geocodedResult!['country'],
          "is_geocoded": true,
          "geocoded_at": DateTime.now().toIso8601String(),
          "source": _geocodedResult!['source'],
        };
      }

      // Handle advertisement file upload if a NEW file is selected
      if (hasAdvertisementFile && selectedFileBytes != null && selectedFileName != null) {
        setState(() => isUploading = true);

        final token = await SecureStorage.getToken();
        if (token == null) {
          throw Exception("No authentication token found");
        }

        final uri = Uri.parse('${ApiConfig.baseUrl}${_getUploadEndpoint()}');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $token';

        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          selectedFileBytes!,
          filename: selectedFileName!,
          contentType: selectedFileMimeType != null
              ? MediaType.parse(selectedFileMimeType!)
              : null,
        );
        request.files.add(multipartFile);
        
        request.fields['job_data'] = jsonEncode(updatedJobData);
        request.fields['job_id'] = _draftJobId!;
        request.fields['is_update'] = 'true'; // Flag to tell backend to update

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? "Upload failed: ${response.statusCode}");
        }
      } else {
        // No new file uploaded, just update the text data
        await DioClient.dio.put(
          _getUpdateEndpoint(_draftJobId!),
          data: updatedJobData,
        );
      }

      debugPrint("✅ Job updated successfully: $_draftJobId");

      if (mounted) {
        showMessage(context, "✅ Job updated successfully!");
        if (widget.onJobUpdated != null) {
          widget.onJobUpdated!();
        }
        if (widget.onJobAdded != null) {
          widget.onJobAdded!(); // Also refresh parent list
        }
      }
    } catch (e) {
      debugPrint("❌ Update failed: $e");
      if (mounted) {
        showMessage(
          context,
          "Failed to update job: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isUploading = false;
        });
      }
    }
  }

  void _clearForm() {
    // Basic Tab
    organizationCtrl.clear();
    postNameCtrl.clear();
    cityVillageCtrl.clear();
    locationCtrl.clear();
    descriptionCtrl.clear();
    lastDateCtrl.clear();
    postDateCtrl.clear();
    applyWithUsUrlCtrl.clear();
    hasApplyWithUs = false;
    websiteUrlCtrl.clear();

    // Notification Tab
    officialNotificationUrlCtrl.clear();
    hasOfficialNotificationLink = false;
    _clearAdvertisementFile();

    // Age/Fees Tab
    ageCalcDateCtrl.clear();
    ageRelaxationCtrl.clear();
    _hasAgeRelaxation = false;
    relaxationValues.clear();
    relaxationControllers.forEach((key, value) => value.clear());
    _hasApplicationFees = false;
    feesValues.clear();
    feesControllers.forEach((key, value) => value.clear());

    // Vacancy Tab
    multiplePosts.clear();
    _showMultiplePosts = false;
    selectedEducation = 'Any Graduate';
    otherQualificationCtrl.clear();
    educationDetailsCtrl.clear();
    experienceDetailsCtrl.clear();
    isFresherEligible = true;
    isExperiencedEligible = true;

    // Work Tab
    selectedBenefits.clear();
    selectedWorkSchedule = 'Full Time';
    selectedShift = 'Day Shift';
    selectedWorkingDays = 'Monday to Friday';
    selectedLanguages.clear();
    otherLanguagesCtrl.clear();

    // Interview Tab
    interviewVenueCtrl.clear();
    interviewDateCtrl.clear();
    interviewTimeCtrl.clear();
    isInterviewOnline = false;
    interviewLinkCtrl.clear();
    interviewDocuments.clear();
    contactPersonCtrl.clear();
    contactDesignationCtrl.clear();
    contactEmailCtrl.clear();
    contactPhoneCtrl.clear();
    importantNotesCtrl.clear();
    termsAndConditionsCtrl.clear();
    selectionStages.clear();
    selectionProcessDetailsCtrl.clear();
    hasBond = false;
    bondDurationCtrl.clear();
    bondAmountCtrl.clear();
    bondTermsCtrl.clear();

    // Timeline Tab
    applicationStartDateCtrl.clear();
    applicationEndDateCtrl.clear();
    notificationNumberCtrl.clear();
    notificationDateCtrl.clear();
    examCities.clear();
    examCityCtrl.clear();
    admitCardDateCtrl.clear();
    examDateCtrl.clear();
    resultDateCtrl.clear();

    // Extras Tab
    _hasPhysicalRequirement = false;
    minHeightCtrl.clear();
    minHeightFemaleCtrl.clear();
    minChestCtrl.clear();
    maxWeightCtrl.clear();
    physicalRelaxationCtrl.clear();
    _hasMedicalRequirement = false;
    medicalStandardsCtrl.clear();
    _hasTraining = false;
    trainingDurationCtrl.clear();
    trainingStipendCtrl.clear();
    trainingLocationCtrl.clear();
    selectedUrgency = 'Normal';
    selectedGenderPreference = 'Any';
    whatsappNumberCtrl.clear();
    telegramChannelCtrl.clear();
    officialWebsiteCtrl.clear();
    helplineNumberCtrl.clear();
    helplineEmailCtrl.clear();

    // Reset other states
    _useCurrentLocation = false;
    _locationStatus = "";
    _selectedCountry = 'India';
    _selectedState = null;
    _selectedDistrict = null;
    _states = LocationData.getStates('India');
    _districts = [];
    _geocodedResult = null;
    _geocodingStatus = '';
    _draftJobId = null;
    _isSavingDraft = false;
    for (int i = 0; i < _tabCount; i++) {
      _tabSaveStatus[i] = false;
    }
    _tabController.animateTo(0);
  }

  // ============================================================
  // TAB NAVIGATION
  // ============================================================
  void _goToNextTabSafe() {
    final current = _tabController.index;
    if (current < _tabCount - 1) {
      _tabController.animateTo(current + 1);
    } else {
      showMessage(context, "All sections completed! ✅", isError: false);
    }
  }

  void _goToPreviousTabSafe() {
    final current = _tabController.index;
    if (current > 0) {
      _tabController.animateTo(current - 1);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBasicTab(),
                      _buildVacancyTab(),
                      _buildAgeFeesTab(),
                      _buildTimelineTab(),
                      _buildWorkTab(),
                      _buildInterviewTab(),
                      _buildNotificationTab(),
                      _buildExtrasTab(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isEditMode
              ? [const Color(0xFFFF6588), const Color(0xFF6C63FF)]
              : [const Color(0xFF6C63FF), const Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.isEditMode ? Icons.edit : _safeTabIcon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isEditMode
                      ? "Edit Job - ${widget.adminRole.toUpperCase()}"
                      : "Add New Job - ${widget.adminRole.toUpperCase()}",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  "Step ${_currentTabIndex + 1} of $_tabCount • $_safeTabLabel",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_draftJobId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: widget.isEditMode
                    ? Colors.orange.shade600
                    : Colors.green.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isEditMode ? Icons.edit : Icons.save,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isEditMode ? "Editing" : "Draft",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${_currentTabIndex + 1}/$_tabCount",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabCount, (index) {
            final isSelected = _currentTabIndex == index;
            final isSaved = _tabSaveStatus[index] == true;
            return GestureDetector(
              onTap: () => _tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isSaved ? Colors.green : Colors.grey.shade300),
                    width: isSaved && !isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF6C63FF).withOpacity(0.35),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSaved && !isSelected
                          ? Icons.check_circle
                          : _tabIcons[index],
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isSaved
                              ? Colors.green
                              : const Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tabLabels[index],
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(_tabCount, (index) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _tabSaveStatus[index] == true
                        ? Colors.green
                        : (_currentTabIndex >= index
                            ? const Color(0xFF6C63FF)
                            : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Step ${_currentTabIndex + 1} of $_tabCount • $_safeTabLabel",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (_currentTabIndex > 0)
                IconButton(
                  onPressed: _goToPreviousTabSafe,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Color(0xFF6C63FF),
                  ),
                  tooltip: "Previous",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              if (_currentTabIndex > 0) const SizedBox(width: 8),
              if (_currentTabIndex < _tabCount - 1)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isEditMode
                          ? [const Color(0xFFFF6588), const Color(0xFF6C63FF)]
                          : [const Color(0xFF6C63FF), const Color(0xFFFF6588)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSavingDraft ? null : _saveAndGoToNextTab,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSavingDraft
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.save, size: 18),
                              SizedBox(width: 6),
                              Text(
                                "Save & Next",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                  ),
                ),
              if (_currentTabIndex == _tabCount - 1)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isEditMode
                          ? [const Color(0xFFFF6588), const Color(0xFF6C63FF)]
                          : [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isEditMode
                                ? const Color(0xFFFF6588)
                                : Colors.green)
                            .withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (isLoading || isUploading)
                        ? null
                        : (widget.isEditMode ? _saveUpdates : _publishJob),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: (isLoading || isUploading)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isEditMode ? Icons.save : Icons.publish,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.isEditMode
                                    ? "Save Changes"
                                    : "Publish Job",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB CONTENTS ====================

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Organization Information",
                  Icons.business,
                  subtitle: "Basic details about the job",
                ),
                _buildAITextField(
                  organizationCtrl,
                  "Organization / Company Name",
                  prefixIcon: Icons.business,
                  hintText: "e.g., Google, Microsoft, Government of India",
                ),
                _buildAITextField(
                  postNameCtrl,
                  "Job Title / Post Name",
                  prefixIcon: Icons.work,
                  hintText: "e.g., Software Engineer, Clerk, Manager",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Job Classification",
                  Icons.category,
                  subtitle: "Type, level and category",
                ),
                _buildAIDropdown(
                  jobType,
                  jobTypes,
                  "Job Type *",
                  onChanged: (v) => setState(() => jobType = v!),
                ),
                _buildAIDropdown(
                  jobLevel,
                  jobLevels,
                  "Job Level",
                  onChanged: (v) => setState(() => jobLevel = v!),
                ),
                _buildAIDropdown(
                  category,
                  categories,
                  "Category *",
                  onChanged: (v) => setState(() => category = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Job Color Type",
                  Icons.color_lens,
                  subtitle: "Identify blue collar or white collar job",
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _colorType == 'blue'
                        ? Colors.blue.shade50
                        : _colorType == 'white'
                            ? Colors.grey.shade100
                            : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _colorType == 'blue'
                          ? Colors.blue
                          : _colorType == 'white'
                              ? Colors.grey.shade400
                              : Colors.purple,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _colorType == 'blue'
                            ? Icons.engineering
                            : _colorType == 'white'
                                ? Icons.business_center
                                : Icons.work,
                        color: _colorType == 'blue'
                            ? Colors.blue
                            : _colorType == 'white'
                                ? Colors.grey.shade700
                                : Colors.purple,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getColorTypeDescription(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _colorType == 'blue'
                                ? Colors.blue.shade800
                                : _colorType == 'white'
                                    ? Colors.grey.shade800
                                    : Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (postNameCtrl.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "AI suggests: ${_getSuggestedColor() == 'blue' ? '🔵 Blue Collar' : '⚪ White Collar'} based on job title",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _colorType = _getSuggestedColor();
                            });
                          },
                          child: const Text(
                            "Apply",
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildColorOption('blue', '🔵 Blue Collar', Colors.blue),
                    _buildColorOption('white', '⚪ White Collar',
                        Colors.grey.shade600),
                    _buildColorOption(
                        'green', '🟢 Green Collar', Colors.green),
                    _buildColorOption('red', '🔴 Red Collar', Colors.red),
                    _buildColorOption(
                        'orange', '🟠 Orange Collar', Colors.orange),
                    _buildColorOption(
                        'purple', '🟣 Purple Collar', Colors.purple),
                    _buildColorOption('teal', '🩵 Teal Collar', Colors.teal),
                    _buildColorOption('pink', '🩷 Pink Collar', Colors.pink),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Location",
                  Icons.location_on,
                  subtitle: "Where is this job located?",
                ),
                _buildLocationContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Dates & Links",
                  Icons.date_range,
                  subtitle: "Important dates and URLs",
                ),
                _buildAIDateField(postDateCtrl, "Post Date"),
                _buildAIDateField(lastDateCtrl, "Last Date to Apply"),
                _buildAITextField(
                  websiteUrlCtrl,
                  "Website URL",
                  hintText: "https://example.com",
                  prefixIcon: Icons.public,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(String colorKey, String label, Color color) {
    final isSelected = _colorType == colorKey;
    return GestureDetector(
      onTap: () => setState(() => _colorType = colorKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildVacancyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Vacancy Details",
                  Icons.people,
                  subtitle: "Add multiple posts with individual details",
                ),
                _buildVacancyToggle(),
                if (_showMultiplePosts) _multiplePostsForm(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Education Requirements",
                  Icons.school,
                  subtitle: "Qualification and eligibility",
                ),
                _buildAIDropdown<String>(
                    educationLevels.contains(selectedEducation)
                        ? selectedEducation
                        : null,
                    educationLevels,
                    "Education Level",
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => selectedEducation = v);
                      }
                    },
                  ),
                _buildAITextField(
                  educationDetailsCtrl,
                  "Education Details",
                  maxLines: 3,
                  hintText: "Details about required education",
                  prefixIcon: Icons.school,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggleTile(
                        title: "Fresher Eligible",
                        value: isFresherEligible,
                        onChanged: (v) =>
                            setState(() => isFresherEligible = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildToggleTile(
                        title: "Experienced Eligible",
                        value: isExperiencedEligible,
                        onChanged: (v) =>
                            setState(() => isExperiencedEligible = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeFeesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Age Limit & Relaxation",
                  Icons.calendar_today,
                  subtitle: "Set age criteria and category-wise relaxations",
                ),
                _buildAgeLimitContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Application Fees",
                  Icons.currency_rupee,
                  subtitle: "Category-wise application fees",
                ),
                _buildApplicationFeesContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Application Timeline",
                  Icons.date_range,
                  subtitle: "Important dates for application",
                ),
                _buildApplicationTimelineContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Important Dates",
                  Icons.event,
                  subtitle: "Admit card, exam and result dates",
                ),
                _buildImportantDatesContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Exam Cities",
                  Icons.location_city,
                  subtitle: "Cities where exam will be conducted",
                ),
                _buildExamCitiesContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Official Details",
                  Icons.assignment,
                  subtitle: "Notification number and mode",
                ),
                _buildOfficialDetailsContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Work Details",
                  Icons.work_outline,
                  subtitle: "Schedule, shift and working days",
                ),
                _buildWorkDetailsContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Experience Details",
                  Icons.work_history,
                  subtitle: "Experience requirements",
                ),
                _buildAITextField(
                  experienceDetailsCtrl,
                  "Experience Details",
                  maxLines: 3,
                  hintText: "e.g., Minimum 2 years experience required",
                  prefixIcon: Icons.work_history,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Benefits & Perks",
                  Icons.card_giftcard,
                  subtitle: "Select benefits offered",
                ),
                _buildBenefitsContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Language Requirements",
                  Icons.language,
                  subtitle: "Languages required for this job",
                ),
                _buildLanguageContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Interview Details",
                  Icons.people_alt,
                  subtitle: "Venue, date and documents required",
                ),
                _buildInterviewContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Selection Process",
                  Icons.timeline,
                  subtitle: "Stages in selection process",
                ),
                _buildSelectionProcessContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Bond / Agreement",
                  Icons.description,
                  subtitle: "Service bond details if any",
                ),
                _buildBondContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Contact Information",
                  Icons.contact_phone,
                  subtitle: "Contact person and helpline details",
                ),
                _buildContactInformationContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Official Notification",
                  Icons.notifications,
                  subtitle:
                      "Provide PDF link or upload file (required for publish)",
                ),
                _buildOfficialNotificationContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Application Options",
                  Icons.link,
                  subtitle: "Apply with Us and website links",
                ),
                _buildApplicationOptionsContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Physical & Medical",
                  Icons.fitness_center,
                  subtitle: "Physical eligibility and medical standards",
                ),
                _buildPhysicalMedicalContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Training Details",
                  Icons.school,
                  subtitle: "Training duration, stipend and location",
                ),
                _buildTrainingContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Additional Information",
                  Icons.info_outline,
                  subtitle: "Urgency, gender preference and notes",
                ),
                _buildAdditionalInformationContent(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Job Description",
                  Icons.description,
                  subtitle: "Detailed job description",
                ),
                _buildAITextField(
                  descriptionCtrl,
                  "Job Description (Optional)",
                  maxLines: 6,
                  hintText: "Enter job description",
                  prefixIcon: Icons.description,
                ),
                _buildAITextField(
                  importantNotesCtrl,
                  "Important Notes",
                  maxLines: 3,
                  hintText: "Any special instructions for applicants",
                  prefixIcon: Icons.note,
                ),
                _buildAITextField(
                  termsAndConditionsCtrl,
                  "Terms & Conditions",
                  maxLines: 3,
                  hintText: "Any terms and conditions for the job",
                  prefixIcon: Icons.gavel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  "Social & Communication",
                  Icons.share,
                  subtitle: "WhatsApp and Telegram links",
                ),
                _buildAITextField(
                  whatsappNumberCtrl,
                  "WhatsApp Number",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.chat,
                ),
                _buildAITextField(
                  telegramChannelCtrl,
                  "Telegram Channel",
                  hintText: "https://t.me/...",
                  prefixIcon: Icons.telegram,
                ),
                _buildAITextField(
                  officialWebsiteCtrl,
                  "Official Website",
                  hintText: "https://example.com",
                  prefixIcon: Icons.public,
                ),
                _buildAITextField(
                  helplineNumberCtrl,
                  "Helpline Number",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.support_agent,
                ),
                _buildAITextField(
                  helplineEmailCtrl,
                  "Helpline Email",
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONTENT BUILDERS ====================

  Widget _buildLocationContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _useCurrentLocation
                ? Colors.green.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _useCurrentLocation ? Colors.green : Colors.grey.shade300,
            ),
          ),
          child: SwitchListTile(
            title: const Text(
              "Use my current location",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
            ),
            subtitle: Text(
              _useCurrentLocation
                  ? "Job will be posted with your saved account location"
                  : "Enter location manually",
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5A5A5A),
              ),
            ),
            value: _useCurrentLocation,
            onChanged: _toggleCurrentLocation,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.shade100,
          ),
        ),
        if (_isGettingLocation)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  "Checking saved location...",
                  style: TextStyle(color: Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
        if (_locationStatus.isNotEmpty && !_isGettingLocation && mounted)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _locationStatus.contains("✅")
                      ? Icons.check_circle
                      : Icons.warning,
                  size: 16,
                  color: _locationStatus.contains("✅")
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _locationStatus.contains("✅")
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!_useCurrentLocation) ...[
          _buildAITextField(
            cityVillageCtrl,
            "City / Village Name",
            hintText: "e.g., Indore, Kukshi, Bhopal",
            prefixIcon: Icons.location_city,
          ),
          _buildAIDropdown(
            _selectedCountry,
            _countries,
            "Country",
            onChanged: _onCountryChanged,
          ),
          _buildAIDropdown(
            _selectedState,
            _states,
            "State",
            onChanged: _onStateChanged,
          ),
          _buildAIDropdown(
            _selectedDistrict,
            _districts,
            "District",
            onChanged: _onDistrictChanged,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeocoding ? null : _findCoordinates,
              icon: _isGeocoding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(
                _isGeocoding ? "Searching..." : "Find Coordinates Online",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_geocodingStatus.isNotEmpty && mounted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _geocodingStatus.contains('✅')
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _geocodingStatus.contains('✅')
                          ? Icons.check_circle
                          : Icons.info,
                      size: 16,
                      color: _geocodingStatus.contains('✅')
                          ? Colors.green
                          : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _geocodingStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: _geocodingStatus.contains('✅')
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.preview, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Location Format Preview:",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locationCtrl.text.isEmpty
                            ? "Select location to see preview"
                            : locationCtrl.text,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVacancyToggle() {
    return Container(
      decoration: BoxDecoration(
        color:
            _showMultiplePosts ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showMultiplePosts ? Colors.green : Colors.grey.shade300,
        ),
      ),
      child: SwitchListTile(
        title: const Text(
          "Add Multiple Posts (Post-wise Details)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Text(
          _showMultiplePosts
              ? "ON: Add different posts with separate details"
              : "OFF: No posts added",
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5A5A5A),
          ),
        ),
        value: _showMultiplePosts,
        onChanged: (value) {
          setState(() {
            _showMultiplePosts = value;
            if (!value) {
              multiplePosts.clear();
            }
          });
        },
        activeThumbColor: Colors.green,
        activeTrackColor: Colors.green.shade100,
      ),
    );
  }

  Widget _multiplePostsForm() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Add Post-wise Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAITextField(
                      postNameCtrl2,
                      "Post Name *",
                      prefixIcon: Icons.work,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAITextField(
                      vacancyCtrl,
                      "Number of Vacancies *",
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.people,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Qualification Required:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAIDropdown(
                      selectedQualificationFromEducation,
                      educationLevels,
                      "Education Level",
                      onChanged: (value) {
                        setState(() {
                          selectedQualificationFromEducation = value;
                          selectedQualificationSubOption = null;
                          selectedDegreeStream = null;
                          selectedDegreeName = null;
                          _qualificationSubOptions = [];
                          _degreeStreams = [];
                          _degreeNames = [];
                          _updateQualificationSubOptions();
                        });
                      },
                    ),
                    if (_qualificationSubOptions.isNotEmpty &&
                        selectedQualificationFromEducation != '10th Pass' &&
                        selectedQualificationFromEducation != '12th Pass' &&
                        selectedQualificationFromEducation != 'Any Graduate' &&
                        selectedQualificationFromEducation !=
                            'Any Post Graduate')
                      _buildAIDropdown(
                        selectedQualificationSubOption,
                        _qualificationSubOptions,
                        "Specific Qualification",
                        onChanged: (value) => setState(
                          () => selectedQualificationSubOption = value,
                        ),
                      ),
                    if (_degreeStreams.isNotEmpty)
                      Column(
                        children: [
                          _buildAIDropdown(
                            selectedDegreeStream,
                            _degreeStreams,
                            "Select Degree",
                            onChanged: (value) {
                              setState(() {
                                selectedDegreeStream = value;
                                selectedDegreeName = null;
                                _degreeNames = [];
                                _updateDegreeNames();
                              });
                            },
                          ),
                          if (_degreeNames.isNotEmpty)
                            _buildAIDropdown(
                              selectedDegreeName,
                              _degreeNames,
                              "Branch / Subject",
                              onChanged: (value) =>
                                  setState(() => selectedDegreeName = value),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    _buildAITextField(
                      otherQualificationCtrl,
                      "Other Qualification Details (Optional)",
                      maxLines: 2,
                      hintText:
                          "e.g., Any additional certification or training",
                    ),
                    const SizedBox(height: 12),
                    _buildAITextField(
                      experienceDetailsCtrl,
                      "Experience Details (if any)",
                      maxLines: 2,
                      hintText: "e.g., Minimum 2 years experience required",
                      prefixIcon: Icons.work_history,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAITextField(
                      postAgeMinCtrl,
                      "Min Age (Optional)",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAITextField(
                      postAgeMaxCtrl,
                      "Max Age (Optional)",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!_isEditingPost)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _savePost,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Post"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (_isEditingPost) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _savePost,
                        icon: const Icon(Icons.save),
                        label: const Text("Update Post"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelEditPost,
                        child: const Text("Cancel"),
                      ),
                    ),
                  ],
                  if (!_isEditingPost) const SizedBox(width: 12),
                  if (!_isEditingPost)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditingPost = false;
                            _editingPostIndex = null;
                            postNameCtrl2.clear();
                            vacancyCtrl.clear();
                            selectedQualificationFromEducation = null;
                            selectedQualificationSubOption = null;
                            selectedDegreeStream = null;
                            selectedDegreeName = null;
                            _qualificationSubOptions = [];
                            _degreeStreams = [];
                            _degreeNames = [];
                            postAgeMinCtrl.clear();
                            postAgeMaxCtrl.clear();
                            otherQualificationCtrl.clear();
                            experienceDetailsCtrl.clear();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("New Post"),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (multiplePosts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Added Posts:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Total: $_totalVacancySum posts",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...multiplePosts.asMap().entries.map(
                      (entry) => _buildPostCard(entry.key, entry.value),
                    ),
              ],
            ),
          ),
        ],
        if (multiplePosts.isNotEmpty) _payScaleFormPopup(),
        _categoryFormPopup(),
      ],
    );
  }

  // ✅ FIXED: _buildPostCard uses safe age conversion
  Widget _buildPostCard(int index, Map<String, dynamic> post) {
    final hasPayScales = post['pay_scales'] != null &&
        (post['pay_scales'] as List).isNotEmpty;
    final qualificationDisplay = post['qualification'] ?? 'Not specified';
    final otherQualification = post['other_qualification_details'] ?? '';
    final experienceDetails = post['experience_details'] ?? '';

    // ✅ SAFE: age_min/age_max may be int, double, String, or null
    final String ageMinStr = _safeAgeToString(post['age_min']);
    final String ageMaxStr = _safeAgeToString(post['age_max']);
    final bool hasAgeLimit = ageMinStr.isNotEmpty || ageMaxStr.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          post['post_name']?.toString() ?? 'Untitled Post',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Vacancies: ${post['total_posts'] ?? 0}",
              style: const TextStyle(color: Color(0xFF1A1A1A)),
            ),
            Text(
              "Qualification: $qualificationDisplay",
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
            ),
            if (otherQualification.isNotEmpty)
              Text(
                "Other: $otherQualification",
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF5A5A5A)),
              ),
            if (experienceDetails.isNotEmpty)
              Text(
                "Experience: $experienceDetails",
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _startEditPost(index),
              tooltip: "Edit Post",
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deletePost(index),
              tooltip: "Delete Post",
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ FIXED: safe age limit check
                if (hasAgeLimit)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Age Limit: ${ageMinStr.isEmpty ? '—' : ageMinStr} - ${ageMaxStr.isEmpty ? '—' : ageMaxStr} years",
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                    ),
                  ),
                if (experienceDetails.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_history,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Experience: $experienceDetails",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  "Salary & Grade Pay Structure:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                if (hasPayScales)
                  ...(post['pay_scales'] as List).asMap().entries.map(
                        (psEntry) => _buildPayScaleCard(
                            index, psEntry.key, psEntry.value),
                      ),
                if (!hasPayScales)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No pay scales added yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Category-wise Vacancy:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _hasCategoryVacancy,
                          onChanged: (value) {
                            setState(() {
                              _hasCategoryVacancy = value;
                              if (!value &&
                                  post['category_vacancies'] != null) {
                                post['category_vacancies'] = [];
                              }
                            });
                          },
                          activeThumbColor: Colors.indigo,
                          activeTrackColor: Colors.indigo.shade100,
                        ),
                      ],
                    ),
                    if (_hasCategoryVacancy)
                      ElevatedButton.icon(
                        onPressed: () => _startAddCategoryForPost(index),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add Category"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (_hasCategoryVacancy &&
                    post['category_vacancies'] != null &&
                    (post['category_vacancies'] as List).isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Category Vacancies:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          "${_getTotalCategoryVacancySum(index)}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...(post['category_vacancies'] as List)
                      .asMap()
                      .entries
                      .map(
                        (catEntry) => _buildCategoryCard(
                            index, catEntry.key, catEntry.value),
                      ),
                ] else if (_hasCategoryVacancy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "No categories added",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayScaleCard(
    int postIndex,
    int psIndex,
    Map<String, dynamic> payScale,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.currency_rupee,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            payScale['pay_scale']?.toString() ?? 'Not specified',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payScale['grade_pay'] != null &&
                  payScale['grade_pay'].toString().isNotEmpty)
                Text(
                  "Grade Pay: ${payScale['grade_pay']}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              if (payScale['pay_band'] != null &&
                  payScale['pay_band'].toString().isNotEmpty)
                Text(
                  "Pay Band: ${payScale['pay_band']}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              if (payScale['min_salary'] != null ||
                  payScale['max_salary'] != null)
                Text(
                  "Salary: ${payScale['min_salary'] != null ? '₹${payScale['min_salary']}' : ''}${payScale['min_salary'] != null && payScale['max_salary'] != null ? ' - ' : ''}${payScale['max_salary'] != null ? '₹${payScale['max_salary']}' : ''}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                onPressed: () => _startEditPayScale(postIndex, psIndex),
                tooltip: "Edit Pay Scale",
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () => _deletePayScaleFromPost(postIndex, psIndex),
                tooltip: "Delete Pay Scale",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    int postIndex,
    int catIndex,
    Map<String, dynamic> category,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.category, color: Colors.indigo),
        title: Text(
          category['name'],
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${category['vacancy']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
              onPressed: () => _startEditCategoryForPost(postIndex, catIndex),
              tooltip: "Edit Category",
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _deleteCategoryFromPost(postIndex, catIndex),
              tooltip: "Delete Category",
            ),
          ],
        ),
      ),
    );
  }

  Widget _payScaleFormPopup() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _sectionHeader(
          "Add Salary & Grade Pay (Optional)",
          Icons.currency_rupee,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "💡 Pay scale is optional. You can skip this section if not applicable.",
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedPostForPayScale,
                hint: const Text(
                  "Select Post for Salary Structure",
                  style: TextStyle(color: Color(0xFF1A1A1A)),
                ),
                decoration: const InputDecoration(
                  labelText: "Select Post *",
                  labelStyle: TextStyle(color: Color(0xFF2C2C2C)),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work, color: Color(0xFF4A4A4A)),
                ),
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                items: multiplePosts
                    .asMap()
                    .entries
                    .map(
                      (entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(
                          entry.value['post_name'],
                          style: const TextStyle(color: Color(0xFF1A1A1A)),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPostForPayScale = value;
                    _isEditingPayScale = false;
                    _editingPayScaleIndex = null;
                    payScaleCtrl.clear();
                    gradePayCtrl.clear();
                    payBandCtrl.clear();
                    minSalaryCtrl.clear();
                    maxSalaryCtrl.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedPostForPayScale != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEditingPayScale
                              ? "Editing Pay Scale for: ${multiplePosts[_selectedPostForPayScale!]['post_name']}"
                              : "Adding Pay Scale for: ${multiplePosts[_selectedPostForPayScale!]['post_name']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildAITextField(
                  payScaleCtrl,
                  "Pay Scale (Optional)",
                  hintText: "e.g., ₹44,900 - ₹1,42,400",
                  prefixIcon: Icons.currency_rupee,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        gradePayCtrl,
                        "Grade Pay (Optional)",
                        hintText: "e.g., ₹4,800",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        payBandCtrl,
                        "Pay Band (Optional)",
                        hintText: "e.g., Level 7",
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        minSalaryCtrl,
                        "Min Salary (₹) Optional",
                        keyboardType: TextInputType.number,
                        hintText: "e.g., 500000",
                        prefixIcon: Icons.currency_rupee,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        maxSalaryCtrl,
                        "Max Salary (₹) Optional",
                        keyboardType: TextInputType.number,
                        hintText: "e.g., 1200000",
                        prefixIcon: Icons.currency_rupee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancelPayScaleForm,
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _savePayScaleForPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isEditingPayScale ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _isEditingPayScale
                              ? "Update Salary"
                              : "Add Salary (Optional)",
                        ),
                      ),
                    ),
                  ],
                ),
                if (multiplePosts[_selectedPostForPayScale!]['pay_scales'] !=
                        null &&
                    (multiplePosts[_selectedPostForPayScale!]['pay_scales']
                            as List)
                        .isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    "Current Salary Structures for this Post:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(multiplePosts[_selectedPostForPayScale!]['pay_scales']
                          as List)
                      .asMap()
                      .entries
                      .map(
                        (entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.value['pay_scale'] ??
                                          'Not specified',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _startEditPayScale(
                                          _selectedPostForPayScale!,
                                          entry.key,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _deletePayScaleFromPost(
                                          _selectedPostForPayScale!,
                                          entry.key,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (entry.value['grade_pay'] != null &&
                                  entry.value['grade_pay']
                                      .toString()
                                      .isNotEmpty)
                                Text(
                                  "Grade Pay: ${entry.value['grade_pay']}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              if (entry.value['pay_band'] != null &&
                                  entry.value['pay_band']
                                      .toString()
                                      .isNotEmpty)
                                Text(
                                  "Pay Band: ${entry.value['pay_band']}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              if (entry.value['min_salary'] != null ||
                                  entry.value['max_salary'] != null)
                                Text(
                                  "Salary: ${entry.value['min_salary'] != null ? '₹${entry.value['min_salary']}' : ''}${entry.value['min_salary'] != null && entry.value['max_salary'] != null ? ' - ' : ''}${entry.value['max_salary'] != null ? '₹${entry.value['max_salary']}' : ''}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryFormPopup() {
    if (_editingCategoryPostIndex != null) {
      return Column(
        children: [
          const SizedBox(height: 16),
          _sectionHeader("Category-wise Vacancy", Icons.people_outline),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _isEditingCategory ? Icons.edit : Icons.add,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isEditingCategory
                          ? "Editing Category"
                          : "Adding Category",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: categoryNameCtrl.text.isEmpty
                            ? null
                            : categoryNameCtrl.text,
                        hint: const Text(
                          "Select Category",
                          style: TextStyle(color: Color(0xFF1A1A1A)),
                        ),
                        decoration: const InputDecoration(
                          labelText: "Category",
                          labelStyle: TextStyle(color: Color(0xFF2C2C2C)),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.category,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                        style: const TextStyle(color: Color(0xFF1A1A1A)),
                        items: predefinedCategories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(
                                  cat,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          categoryNameCtrl.text = value ?? '';
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: categoryVacancyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Vacancies",
                          labelStyle: TextStyle(color: Color(0xFF2C2C2C)),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.people,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isEditingCategory ? Icons.update : Icons.add,
                        color: Colors.indigo,
                      ),
                      onPressed: _saveCategoryForPost,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: _cancelCategoryForPostForm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAgeLimitContent() {
    return Column(
      children: [
        _buildAIDateField(ageCalcDateCtrl, "Age Calculation Date"),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Age Relaxation by Category",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Switch(
                    value: _hasAgeRelaxation,
                    onChanged: (value) =>
                        setState(() => _hasAgeRelaxation = value),
                    activeThumbColor: Colors.orange,
                    activeTrackColor: Colors.orange.shade100,
                  ),
                ],
              ),
              if (_hasAgeRelaxation) ...[
                const SizedBox(height: 12),
                const Text(
                  "Enter relaxation in years for each category:",
                  style: TextStyle(fontSize: 12, color: Color(0xFF5A5A5A)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEditingRelaxation ? Icons.edit : Icons.add,
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditingRelaxation
                                ? "Edit Relaxation"
                                : "Add New Relaxation",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.orange,
                            ),
                          ),
                          const Spacer(),
                          if (_isEditingRelaxation)
                            TextButton(
                              onPressed: _cancelRelaxationForm,
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _isEditingRelaxation
                                  ? _editingRelaxationCategory
                                  : null,
                              hint: const Text(
                                "Select Category",
                                style: TextStyle(color: Color(0xFF1A1A1A)),
                              ),
                              decoration: const InputDecoration(
                                labelText: "Category",
                                labelStyle:
                                    TextStyle(color: Color(0xFF2C2C2C)),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.category,
                                  color: Color(0xFF4A4A4A),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              style:
                                  const TextStyle(color: Color(0xFF1A1A1A)),
                              items: relaxationCategories
                                  .map(
                                    (cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                        cat,
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  relaxationCategoryCtrl.text = value ?? '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: relaxationYearsCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                labelText: "Years",
                                labelStyle:
                                    TextStyle(color: Color(0xFF2C2C2C)),
                                hintText: "e.g., 3",
                                hintStyle:
                                    TextStyle(color: Color(0xFF9E9E9E)),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.timer,
                                  color: Color(0xFF4A4A4A),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveRelaxation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEditingRelaxation
                                  ? Colors.orange
                                  : Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              _isEditingRelaxation ? "Update" : "Add",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (relaxationValues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.category,
                              size: 18,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Category-wise Age Relaxation:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${relaxationValues.length} Categories",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...relaxationValues.entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.category,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                              ),
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${entry.value} years",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _startEditRelaxation(
                                      entry.key,
                                      entry.value,
                                    ),
                                    tooltip: "Edit Relaxation",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteRelaxation(entry.key),
                                    tooltip: "Delete Relaxation",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (relaxationValues.isEmpty && _hasAgeRelaxation)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.category, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "No age relaxations added",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "Use the form above to add relaxations for different categories",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "💡 Age relaxation applies to reserved categories as per government rules.",
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationFeesContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hasApplicationFees
                ? Colors.teal.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasApplicationFees ? Colors.teal : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Enable Category-wise Application Fees",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Text(
                  _hasApplicationFees
                      ? "ON: Set different fees for different categories"
                      : "OFF: No application fees",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A5A5A),
                  ),
                ),
                value: _hasApplicationFees,
                onChanged: (value) {
                  setState(() {
                    _hasApplicationFees = value;
                    if (!value) {
                      feesValues.clear();
                      for (var c in feesControllers.values) {
                        c.clear();
                      }
                    }
                  });
                },
                activeThumbColor: Colors.teal,
                activeTrackColor: Colors.teal.shade100,
              ),
              if (_hasApplicationFees) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEditingFee ? Icons.edit : Icons.add,
                            size: 20,
                            color: Colors.teal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditingFee ? "Edit Fee" : "Add New Fee",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.teal,
                            ),
                          ),
                          const Spacer(),
                          if (_isEditingFee)
                            TextButton(
                              onPressed: _cancelFeeForm,
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _isEditingFee
                                  ? _editingFeeCategory
                                  : (feeCategoryCtrl.text.isEmpty
                                      ? null
                                      : feeCategoryCtrl.text),
                              hint: const Text(
                                "Select Category",
                                style: TextStyle(color: Color(0xFF1A1A1A)),
                              ),
                              decoration: const InputDecoration(
                                labelText: "Category",
                                labelStyle:
                                    TextStyle(color: Color(0xFF2C2C2C)),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.category,
                                  color: Color(0xFF4A4A4A),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              style:
                                  const TextStyle(color: Color(0xFF1A1A1A)),
                              items: predefinedFeeCategories
                                  .map(
                                    (cat) => DropdownMenuItem(
                                      value: cat,
                                      child: Text(
                                        cat,
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  feeCategoryCtrl.text = value ?? '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: feeAmountCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                labelText: "Fee (₹)",
                                labelStyle:
                                    TextStyle(color: Color(0xFF2C2C2C)),
                                hintText: "e.g., 500",
                                hintStyle:
                                    TextStyle(color: Color(0xFF9E9E9E)),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.currency_rupee,
                                  color: Color(0xFF4A4A4A),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveApplicationFee,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isEditingFee ? Colors.orange : Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text(_isEditingFee ? "Update" : "Add"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (feesValues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.payment,
                              size: 18,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Category-wise Application Fees:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${feesValues.length} Categories",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...feesValues.entries.map(
                          (entry) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.category,
                                  size: 18,
                                  color: Colors.teal,
                                ),
                              ),
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "₹${entry.value}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _startEditFee(entry.key, entry.value),
                                    tooltip: "Edit Fee",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteFee(entry.key),
                                    tooltip: "Delete Fee",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (feesValues.isEmpty && _hasApplicationFees)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.payment, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "No application fees added",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "Use the form above to add fees for different categories",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.teal),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "💡 Set application fees for different categories. Users will see these fees when applying.",
                          style: TextStyle(fontSize: 11, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationTimelineContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(
                applicationStartDateCtrl,
                "Application Start Date",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAIDateField(
                applicationEndDateCtrl,
                "Application End Date",
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAIDropdown(
          selectedApplicationMode,
          applicationModes,
          "Application Mode",
          onChanged: (v) => setState(() => selectedApplicationMode = v!),
        ),
      ],
    );
  }

  Widget _buildImportantDatesContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(admitCardDateCtrl, "Admit Card Date"),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAIDateField(examDateCtrl, "Exam Date"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(resultDateCtrl, "Result Date"),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildExamCitiesContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAITextField(
                examCityCtrl,
                "Exam City Name",
                hintText: "e.g., Indore, Bhopal, Mumbai",
                prefixIcon: Icons.location_on,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _addExamCity,
              icon: const Icon(Icons.add),
              label: const Text("Add"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        if (examCities.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            "Added Exam Cities:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: examCities
                .asMap()
                .entries
                .map(
                  (entry) => Chip(
                    label: Text(
                      entry.value,
                      style: const TextStyle(color: Color(0xFF1A1A1A)),
                    ),
                    avatar: const Icon(Icons.location_on, size: 16),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _deleteExamCity(entry.key),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildOfficialDetailsContent() {
    return Column(
      children: [
        _buildAITextField(
          notificationNumberCtrl,
          "Notification Number",
          prefixIcon: Icons.confirmation_number,
        ),
        _buildAIDateField(notificationDateCtrl, "Notification Date"),
      ],
    );
  }

  Widget _buildWorkDetailsContent() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAIDropdown(
                selectedWorkSchedule,
                workSchedules,
                "Work Schedule",
                onChanged: (v) => setState(() => selectedWorkSchedule = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAIDropdown(
                selectedShift,
                shifts,
                "Shift",
                onChanged: (v) => setState(() => selectedShift = v!),
              ),
            ),
          ],
        ),
        _buildAIDropdown(
          selectedWorkingDays,
          workingDays,
          "Working Days",
          onChanged: (v) => setState(() => selectedWorkingDays = v!),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleTile(
                title: "Fully Remote",
                value: isFullyRemote,
                onChanged: (v) => setState(() => isFullyRemote = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleTile(
                title: "Hybrid",
                value: isHybrid,
                onChanged: (v) => setState(() => isHybrid = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBenefitsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "Select Benefits:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableBenefits.map((benefit) {
              final isSelected = selectedBenefits.contains(benefit);
              return FilterChip(
                label: Text(
                  benefit,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedBenefits.add(benefit);
                    } else {
                      selectedBenefits.remove(benefit);
                    }
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.green.shade200,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          const Text(
            "Required Languages:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableLanguages.map((lang) {
              final isSelected = selectedLanguages.contains(lang);
              return FilterChip(
                label: Text(
                  lang,
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedLanguages.add(lang);
                    } else {
                      selectedLanguages.remove(lang);
                    }
                  });
                },
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.blue.shade200,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildAITextField(
            otherLanguagesCtrl,
            "Other Languages (comma separated)",
            hintText: "e.g., French, German",
            prefixIcon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewContent() {
    return Column(
      children: [
        _buildToggleTile(
          title: "Online Interview",
          value: isInterviewOnline,
          onChanged: (v) => setState(() => isInterviewOnline = v),
        ),
        const SizedBox(height: 12),
        if (isInterviewOnline)
          _buildAITextField(
            interviewLinkCtrl,
            "Interview Link",
            hintText: "https://meet.google.com/...",
            prefixIcon: Icons.link,
          )
        else
          _buildAITextField(
            interviewVenueCtrl,
            "Interview Venue",
            hintText: "Full address with landmark",
            prefixIcon: Icons.location_on,
          ),
        Row(
          children: [
            Expanded(
              child: _buildAIDateField(interviewDateCtrl, "Interview Date"),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAITextField(
                interviewTimeCtrl,
                "Interview Time",
                hintText: "e.g., 10:00 AM - 5:00 PM",
                prefixIcon: Icons.access_time,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Required Documents for Interview:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: requiredDocuments.map((doc) {
            final isSelected = interviewDocuments.contains(doc);
            return FilterChip(
              label: Text(
                doc,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    interviewDocuments.add(doc);
                  } else {
                    interviewDocuments.remove(doc);
                  }
                });
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: Colors.orange.shade200,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectionProcessContent() {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableStages.map((stage) {
            final isSelected = selectionStages.contains(stage);
            return FilterChip(
              label: Text(
                stage,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectionStages.add(stage);
                  } else {
                    selectionStages.remove(stage);
                  }
                });
              },
              backgroundColor: Colors.grey.shade200,
              selectedColor: Colors.purple.shade200,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildAITextField(
          selectionProcessDetailsCtrl,
          "Selection Process Details (Optional)",
          maxLines: 3,
          hintText: "Describe the complete selection process...",
          prefixIcon: Icons.description,
        ),
      ],
    );
  }

  Widget _buildBondContent() {
    return Card(
      color: hasBond ? Colors.red.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Service Bond Required",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              subtitle: const Text(
                "Is there any service bond or agreement?",
                style: TextStyle(color: Color(0xFF5A5A5A)),
              ),
              value: hasBond,
              onChanged: (newValue) => setState(() => hasBond = newValue),
              activeThumbColor: Colors.red,
              activeTrackColor: Colors.red.shade100,
            ),
            if (hasBond) ...[
              const SizedBox(height: 12),
              _buildAITextField(
                bondDurationCtrl,
                "Bond Duration",
                hintText: "e.g., 2 years",
                prefixIcon: Icons.timer,
              ),
              _buildAITextField(
                bondAmountCtrl,
                "Bond Amount (if any)",
                keyboardType: TextInputType.number,
                hintText: "e.g., 500000",
                prefixIcon: Icons.currency_rupee,
              ),
              _buildAITextField(
                bondTermsCtrl,
                "Bond Terms & Conditions",
                maxLines: 2,
                hintText: "Describe the bond terms...",
                prefixIcon: Icons.description,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactInformationContent() {
    return Column(
      children: [
        _buildAITextField(
          contactPersonCtrl,
          "Contact Person Name",
          prefixIcon: Icons.person,
        ),
        _buildAITextField(
          contactDesignationCtrl,
          "Designation",
          prefixIcon: Icons.badge,
        ),
        _buildAITextField(
          contactEmailCtrl,
          "Contact Email",
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email,
        ),
        _buildAITextField(
          contactPhoneCtrl,
          "Contact Phone Number",
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone,
        ),
        _buildAITextField(
          helplineNumberCtrl,
          "Helpline Number",
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.support_agent,
        ),
        _buildAITextField(
          helplineEmailCtrl,
          "Helpline Email",
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email,
        ),
      ],
    );
  }

  Widget _buildOfficialNotificationContent() {
    return Column(
      children: [
        Card(
          color: hasOfficialNotificationLink
              ? Colors.blue.shade50
              : Colors.grey.shade50,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    "Official Notification PDF Link",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  subtitle: const Text(
                    "Provide a direct URL link to the official notification PDF",
                    style: TextStyle(color: Color(0xFF5A5A5A)),
                  ),
                  value: hasOfficialNotificationLink,
                  onChanged: (value) {
                    setState(() {
                      hasOfficialNotificationLink = value;
                      if (!value) {
                        officialNotificationUrlCtrl.clear();
                      }
                    });
                  },
                  activeThumbColor: Colors.blue,
                  activeTrackColor: Colors.blue.shade100,
                ),
                if (hasOfficialNotificationLink && mounted) ...[
                  const SizedBox(height: 12),
                  _buildAITextField(
                    officialNotificationUrlCtrl,
                    "Official Notification PDF URL",
                    hintText: "https://example.com/notification.pdf",
                    prefixIcon: Icons.picture_as_pdf,
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          color: hasAdvertisementFile
              ? Colors.orange.shade50
              : Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    "Upload Advertisement File",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  subtitle: const Text(
                    "Upload PDF or Image file as advertisement",
                    style: TextStyle(color: Color(0xFF5A5A5A)),
                  ),
                  value: hasAdvertisementFile,
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _pickAdvertisement();
                      } else {
                        _clearAdvertisementFile();
                      }
                    });
                  },
                  activeThumbColor: Colors.orange,
                  activeTrackColor: Colors.orange.shade100,
                ),
                if (hasAdvertisementFile &&
                    selectedFileName != null &&
                    mounted) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedFileName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              if (selectedFileBytes != null)
                                Text(
                                  "${(selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5A5A5A),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _clearAdvertisementFile,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "⚠️ PDF/Link is required only for FINAL PUBLISH. You can save this tab without it!",
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationOptionsContent() {
    return Card(
      color: hasApplyWithUs ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Enable 'Apply with Us' Button",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              subtitle: const Text(
                "Redirect users to an external application form",
                style: TextStyle(color: Color(0xFF5A5A5A)),
              ),
              value: hasApplyWithUs,
              onChanged: (value) {
                setState(() {
                  hasApplyWithUs = value;
                  if (!value) {
                    applyWithUsUrlCtrl.clear();
                  }
                });
              },
            ),
            if (hasApplyWithUs && mounted) ...[
              const SizedBox(height: 12),
              _buildAITextField(
                applyWithUsUrlCtrl,
                "Apply With Us URL",
                hintText: "https://example.com/apply",
                prefixIcon: Icons.open_in_browser,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalMedicalContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Physical Requirements",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: const Text(
                  "Height, chest, weight requirements (Police/Defense jobs)",
                  style: TextStyle(color: Color(0xFF5A5A5A)),
                ),
                value: _hasPhysicalRequirement,
                onChanged: (value) =>
                    setState(() => _hasPhysicalRequirement = value),
                activeThumbColor: Colors.blue,
                activeTrackColor: Colors.blue.shade100,
              ),
              if (_hasPhysicalRequirement) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        minHeightCtrl,
                        "Min Height (cm) Male",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        minHeightFemaleCtrl,
                        "Min Height (cm) Female",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildAITextField(
                        minChestCtrl,
                        "Min Chest (cm)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAITextField(
                        maxWeightCtrl,
                        "Max Weight (kg)",
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                _buildAITextField(
                  physicalRelaxationCtrl,
                  "Physical Relaxation Details",
                  maxLines: 2,
                  hintText: "Relaxation for reserved categories",
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  "Medical Standards",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: const Text(
                  "Medical fitness requirements for the job",
                  style: TextStyle(color: Color(0xFF5A5A5A)),
                ),
                value: _hasMedicalRequirement,
                onChanged: (value) =>
                    setState(() => _hasMedicalRequirement = value),
                activeThumbColor: Colors.purple,
                activeTrackColor: Colors.purple.shade100,
              ),
              if (_hasMedicalRequirement) ...[
                const SizedBox(height: 12),
                _buildAITextField(
                  medicalStandardsCtrl,
                  "Medical Standards Details",
                  maxLines: 3,
                  hintText: "Describe medical fitness requirements",
                  prefixIcon: Icons.medical_services,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingContent() {
    return Card(
      color: _hasTraining ? Colors.green.shade50 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                "Training Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              subtitle: const Text(
                "Is there any training period for selected candidates?",
                style: TextStyle(color: Color(0xFF5A5A5A)),
              ),
              value: _hasTraining,
              onChanged: (value) => setState(() => _hasTraining = value),
              activeThumbColor: Colors.green,
              activeTrackColor: Colors.green.shade100,
            ),
            if (_hasTraining) ...[
              const SizedBox(height: 12),
              _buildAITextField(
                trainingDurationCtrl,
                "Training Duration",
                hintText: "e.g., 6 months",
                prefixIcon: Icons.timer,
              ),
              _buildAITextField(
                trainingStipendCtrl,
                "Training Stipend (₹)",
                keyboardType: TextInputType.number,
                hintText: "e.g., 15000",
                prefixIcon: Icons.currency_rupee,
              ),
              _buildAITextField(
                trainingLocationCtrl,
                "Training Location",
                hintText: "e.g., Training Academy, Delhi",
                prefixIcon: Icons.location_on,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInformationContent() {
    return Column(
      children: [
        _buildAIDropdown(
          selectedUrgency,
          urgencyLevels,
          "Urgency Level",
          onChanged: (v) => setState(() => selectedUrgency = v!),
        ),
        _buildAIDropdown(
          selectedGenderPreference,
          genderPreferences,
          "Gender Preference",
          onChanged: (v) => setState(() => selectedGenderPreference = v!),
        ),
      ],
    );
  }

  // ==================== REUSABLE WIDGETS ====================

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5A5A5A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAITextField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    int maxLines = 1,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            hintText: hintText ?? (required ? null : "Optional"),
            hintStyle: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 13,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: const Color(0xFF4A4A4A), size: 20)
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) =>
              required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildAIDropdown<T>(
    T? value,
    List<T> items,
    String label, {
    void Function(T?)? onChanged,
    bool required = false,
  }) {
    // ============================================================
    // ✅ FIX: Prevent DropdownButton assertion crash
    // Root cause: When editing a job whose saved value (e.g. "BBA")
    // is NOT in `items`, Flutter's DropdownButtonFormField asserts:
    //   "There should be exactly one item with value: BBA"
    //
    // Solution:
    //   1. If value not in items → prepend value to items
    //   2. If value has duplicates → deduplicate
    //   3. If items is empty → pass null
    // ============================================================
    List<T> safeItems = List<T>.from(items);
    T? safeValue = value;

    if (safeValue != null) {
      final int matchCount =
          safeItems.where((e) => e == safeValue).length;

      if (matchCount == 0) {
        // Value missing → prepend so exactly ONE match exists
        debugPrint(
          "⚠️ Dropdown '$label': value '$safeValue' not in items "
          "(${safeItems.length}). Prepending to prevent crash.",
        );
        safeItems.insert(0, safeValue);
      } else if (matchCount > 1) {
        // Duplicates → keep only the first occurrence
        debugPrint(
          "⚠️ Dropdown '$label': value '$safeValue' has $matchCount "
          "duplicates. Deduplicating.",
        );
        bool kept = false;
        safeItems = safeItems.where((e) {
          if (e == safeValue) {
            if (kept) return false;
            kept = true;
          }
          return true;
        }).toList();
      }
    }

    if (safeItems.isEmpty) {
      safeValue = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: DropdownButtonFormField<T>(
          initialValue: safeValue,
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF4A4A4A),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: safeItems.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          validator: (value) =>
              required && value == null ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildAIDateField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          readOnly: true,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: const TextStyle(
              color: Color(0xFF2C2C2C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.calendar_today,
              color: Color(0xFF4A4A4A),
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: const Icon(
              Icons.event,
              color: Color(0xFF757575),
              size: 18,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onTap: () => _selectDate(ctrl),
          validator: (value) =>
              required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
            ),
          ),
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          activeColor: const Color(0xFF6C63FF),
          checkColor: Colors.white,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
      ),
    );
  }
}