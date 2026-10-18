// lib/features/user/presentation/screens/basic_details_screen.dart
// ✅ ULTRA-FAST - CACHE FIRST, INSTANT LOAD
// ✅ AI-BASED MODERN DESIGN WITH LARGER TABS
// ✅ FIXED: Save → auto-jump to next tab (no crash) + All tabs always visible
// ✅ ADDED: birth_place, hobbies, interests, all social links

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/master_date/locations.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/user/data/user_service.dart';

class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentTabIndex = 0;

  late TabController _tabController;

  String _email = '';
  String _mobile = '';
  String _name = '';

  // ==================== BASIC INFORMATION ====================
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _middleName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  String _gender = 'Male';
  final TextEditingController _dob = TextEditingController();
  final TextEditingController _birthPlace = TextEditingController();
  int _age = 0;
  String _bloodGroup = 'I don\'t know';
  String _nationality = 'Indian';
  String _religion = 'Hindu';

  // ✅ Hobbies & Interests
  List<String> _hobbies = [];
  List<String> _interests = [];

  // ==================== CATEGORY ====================
  String _category = 'General/UR';
  final List<String> _categoryOptions = const ['General/UR', 'OBC', 'SC', 'ST', 'EWS'];

  // ==================== DISABILITY ====================
  bool _isDisable = false;
  String _disabilityCategory = 'LD (Learning Disability)';
  final TextEditingController _disabilityPercentage = TextEditingController();
  final TextEditingController _disabilityDetails = TextEditingController();
  final List<String> _disabilityCategories = const [
    'LD (Learning Disability)',
    'HI (Hearing Impairment)',
    'VI (Visual Impairment)',
    'MD (Multiple Disabilities)',
  ];

  // ==================== FAMILY DETAILS ====================
  final TextEditingController _fatherName = TextEditingController();
  final TextEditingController _motherName = TextEditingController();
  final TextEditingController _guardianName = TextEditingController();
  final TextEditingController _spouseName = TextEditingController();
  String _maritalStatus = 'Unmarried';
  final TextEditingController _familyAnnualIncome = TextEditingController();
  final TextEditingController _numberOfDependents = TextEditingController();

  // ==================== ADDITIONAL CONTACT ====================
  final TextEditingController _alternateMobile = TextEditingController();
  final TextEditingController _whatsappNumber = TextEditingController();

  // ==================== EMERGENCY CONTACT ====================
  final TextEditingController _emergencyContactName = TextEditingController();
  final TextEditingController _emergencyContactRelation = TextEditingController();
  final TextEditingController _emergencyContactPhone = TextEditingController();

  // ==================== ADDRESS ====================
  String? _selectedCountry;
  String? _selectedState;
  String? _selectedDistrict;
  final TextEditingController _currHouseNumber = TextEditingController();
  final TextEditingController _currVillageName = TextEditingController();
  final TextEditingController _currPostOffice = TextEditingController();
  final TextEditingController _currTehsil = TextEditingController();
  final TextEditingController _currPincode = TextEditingController();
  final TextEditingController _currLandmark = TextEditingController();

  bool _sameAsCurrent = true;
  String? _permSelectedCountry;
  String? _permSelectedState;
  String? _permSelectedDistrict;
  final TextEditingController _permHouseNumber = TextEditingController();
  final TextEditingController _permVillageName = TextEditingController();
  final TextEditingController _permPostOffice = TextEditingController();
  final TextEditingController _permTehsil = TextEditingController();
  final TextEditingController _permPincode = TextEditingController();
  final TextEditingController _permLandmark = TextEditingController();

  List<String> _countries = [];
  List<String> _states = [];
  List<String> _districts = [];
  List<String> _permStates = [];
  List<String> _permDistricts = [];

  // ==================== PROFESSIONAL ====================
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _careerObjective = TextEditingController();

  // ✅ All social links
  final TextEditingController _linkedinUrl = TextEditingController();
  final TextEditingController _githubUrl = TextEditingController();
  final TextEditingController _portfolioUrl = TextEditingController();
  final TextEditingController _twitterUrl = TextEditingController();
  final TextEditingController _facebookUrl = TextEditingController();
  final TextEditingController _instagramUrl = TextEditingController();
  final TextEditingController _youtubeUrl = TextEditingController();
  final TextEditingController _personalWebsiteUrl = TextEditingController();

  // ==================== JOB PREFERENCES ====================
  final TextEditingController _preferredLocation = TextEditingController();
  final TextEditingController _expectedSalaryMin = TextEditingController();
  final TextEditingController _expectedSalaryMax = TextEditingController();
  bool _openToRelocate = false;
  bool _openToRemoteWork = false;
  List<String> _preferredJobTypes = [];
  List<String> _preferredIndustries = [];

  // ==================== PHYSICAL ====================
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();

  // ==================== LANGUAGES ====================
  final TextEditingController _languagesKnown = TextEditingController();

  // ==================== CHIP OPTIONS ====================
  final List<String> _hobbyOptions = const [
    'Reading', 'Writing', 'Cooking', 'Traveling', 'Photography',
    'Music', 'Dancing', 'Painting', 'Gardening', 'Sports',
    'Cycling', 'Swimming', 'Yoga', 'Chess', 'Gaming',
    'Blogging', 'Volunteering', 'Crafting', 'Singing', 'Playing Instruments',
  ];

  final List<String> _interestOptions = const [
    'Technology', 'Science', 'Business', 'Finance', 'Healthcare',
    'Education', 'Social Work', 'Environment', 'Sports', 'Art & Culture',
    'Politics', 'Fashion', 'Food', 'Travel', 'Books',
    'Movies', 'Entrepreneurship', 'AI/ML', 'Startups', 'Research',
  ];

  // ==================== TAB ICONS / LABELS ====================
  static const int _tabCount = 6;

  final List<IconData> _tabIcons = const [
    Icons.person,
    Icons.category,
    Icons.family_restroom,
    Icons.home,
    Icons.work,
    Icons.business_center,
  ];

  final List<String> _tabLabels = const [
    'Basic',
    'Category',
    'Family',
    'Address',
    'Profile',
    'Job',
  ];

  /// ✅ Safety net — never crash even if index goes out of range
  String get _safeTabLabel {
    final idx = _currentTabIndex.clamp(0, _tabLabels.length - 1);
    return _tabLabels[idx];
  }

  IconData get _safeTabIcon {
    final idx = _currentTabIndex.clamp(0, _tabIcons.length - 1);
    return _tabIcons[idx];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadCountries();
    _loadData();
    _dob.addListener(_calculateAge);

    // ✅ SINGLE source of truth — only sync from controller
    _tabController.addListener(() {
      if (!mounted) return;
      if (_currentTabIndex != _tabController.index) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullName.dispose();
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _birthPlace.dispose();
    _disabilityPercentage.dispose();
    _disabilityDetails.dispose();
    _fatherName.dispose();
    _motherName.dispose();
    _guardianName.dispose();
    _spouseName.dispose();
    _familyAnnualIncome.dispose();
    _numberOfDependents.dispose();
    _alternateMobile.dispose();
    _whatsappNumber.dispose();
    _emergencyContactName.dispose();
    _emergencyContactRelation.dispose();
    _emergencyContactPhone.dispose();
    _currHouseNumber.dispose();
    _currVillageName.dispose();
    _currPostOffice.dispose();
    _currTehsil.dispose();
    _currPincode.dispose();
    _currLandmark.dispose();
    _permHouseNumber.dispose();
    _permVillageName.dispose();
    _permPostOffice.dispose();
    _permTehsil.dispose();
    _permPincode.dispose();
    _permLandmark.dispose();
    _summary.dispose();
    _careerObjective.dispose();
    _linkedinUrl.dispose();
    _githubUrl.dispose();
    _portfolioUrl.dispose();
    _twitterUrl.dispose();
    _facebookUrl.dispose();
    _instagramUrl.dispose();
    _youtubeUrl.dispose();
    _personalWebsiteUrl.dispose();
    _preferredLocation.dispose();
    _expectedSalaryMin.dispose();
    _expectedSalaryMax.dispose();
    _height.dispose();
    _weight.dispose();
    _languagesKnown.dispose();
    super.dispose();
  }

  void _loadCountries() {
    _countries = LocationData.getCountries();
    _selectedCountry = 'India';
    _permSelectedCountry = 'India';
    _updateStates();
    _updatePermStates();
  }

  void _updateStates() {
    final states = LocationData.getStates(_selectedCountry ?? 'India');
    _states = states.toSet().toList();
    _states.sort();
    if (_selectedState != null && !_states.contains(_selectedState)) {
      _selectedState = null;
    }
  }

  void _updateDistricts() {
    if (_selectedCountry != null && _selectedState != null) {
      final districts = LocationData.getDistricts(_selectedCountry!, _selectedState!);
      _districts = districts.toSet().toList();
      _districts.sort();
      if (_selectedDistrict != null && !_districts.contains(_selectedDistrict)) {
        _selectedDistrict = null;
      }
    } else {
      _districts = [];
    }
  }

  void _updatePermStates() {
    final states = LocationData.getStates(_permSelectedCountry ?? 'India');
    _permStates = states.toSet().toList();
    _permStates.sort();
    if (_permSelectedState != null && !_permStates.contains(_permSelectedState)) {
      _permSelectedState = null;
    }
  }

  void _updatePermDistricts() {
    if (_permSelectedCountry != null && _permSelectedState != null) {
      final districts = LocationData.getDistricts(_permSelectedCountry!, _permSelectedState!);
      _permDistricts = districts.toSet().toList();
      _permDistricts.sort();
      if (_permSelectedDistrict != null && !_permDistricts.contains(_permSelectedDistrict)) {
        _permSelectedDistrict = null;
      }
    } else {
      _permDistricts = [];
    }
  }

  void _onCountryChanged(String? country) {
    setState(() {
      _selectedCountry = country ?? 'India';
      _selectedState = null;
      _selectedDistrict = null;
      _updateStates();
      _districts = [];
    });
  }

  void _onStateChanged(String? state) {
    setState(() {
      _selectedState = state;
      _selectedDistrict = null;
      _updateDistricts();
    });
  }

  void _onDistrictChanged(String? district) {
    setState(() => _selectedDistrict = district);
  }

  void _onPermCountryChanged(String? country) {
    setState(() {
      _permSelectedCountry = country ?? 'India';
      _permSelectedState = null;
      _permSelectedDistrict = null;
      _updatePermStates();
      _permDistricts = [];
    });
  }

  void _onPermStateChanged(String? state) {
    setState(() {
      _permSelectedState = state;
      _permSelectedDistrict = null;
      _updatePermDistricts();
    });
  }

  void _onPermDistrictChanged(String? district) {
    setState(() => _permSelectedDistrict = district);
  }

  void _calculateAge() {
    try {
      if (_dob.text.isNotEmpty) {
        final parts = _dob.text.split('-');
        if (parts.length == 3) {
          final birth = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final today = DateTime.now();
          int age = today.year - birth.year;
          if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) {
            age--;
          }
          _age = age;
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final contactDetails = await UserService.getContactDetails();
      _email = contactDetails['email'] ?? '';
      _mobile = contactDetails['mobile'] ?? '';
      _name = contactDetails['name'] ?? '';

      final profile = await UserService.getFullProfile();

      if (mounted && profile.isNotEmpty) {
        _fullName.text = _safeString(profile, 'full_name', _name);
        _firstName.text = _safeString(profile, 'first_name');
        _middleName.text = _safeString(profile, 'middle_name');
        _lastName.text = _safeString(profile, 'last_name');
        _gender = _safeString(profile, 'gender', 'Male');
        _dob.text = _safeString(profile, 'dob');
        _birthPlace.text = _safeString(profile, 'birth_place');
        _bloodGroup = _normalizeBloodGroup(_safeString(profile, 'blood_group', ''));
        _nationality = _safeString(profile, 'nationality', 'Indian');
        _religion = _normalizeReligion(_safeString(profile, 'religion', 'Hindu'));
        _category = _safeString(profile, 'category', 'General/UR');

        final hobbies = profile['hobbies'];
        if (hobbies is List) {
          _hobbies = List<String>.from(hobbies.map((e) => e.toString()));
        }
        final interests = profile['interests'];
        if (interests is List) {
          _interests = List<String>.from(interests.map((e) => e.toString()));
        }

        final disability = _safeMap(profile, 'disability');
        _isDisable = disability['is_disabled'] is bool ? disability['is_disabled'] : false;
        _disabilityCategory = _normalizeDisabilityCategory(_safeString(disability, 'disability_category', ''));
        _disabilityPercentage.text = _isDisable ? _safeString(disability, 'disability_percentage') : '';
        _disabilityDetails.text = _isDisable ? _safeString(disability, 'disability_details') : '';

        _fatherName.text = _safeString(profile, 'father_name');
        _motherName.text = _safeString(profile, 'mother_name');
        _guardianName.text = _safeString(profile, 'guardian_name');
        _spouseName.text = _safeString(profile, 'spouse_name');
        _maritalStatus = _safeString(profile, 'marital_status', 'Unmarried');
        _familyAnnualIncome.text = _safeNumber(profile, 'family_annual_income');
        _numberOfDependents.text = _safeNumber(profile, 'number_of_dependents');

        _alternateMobile.text = _safeString(profile, 'alternate_mobile');
        _whatsappNumber.text = _safeString(profile, 'whatsapp_number');

        final emergencyContact = _safeMap(profile, 'emergency_contact');
        if (emergencyContact.isNotEmpty) {
          _emergencyContactName.text = _safeString(emergencyContact, 'name', '');
          _emergencyContactRelation.text = _safeString(emergencyContact, 'relationship', '');
          _emergencyContactPhone.text = _safeString(emergencyContact, 'phone', '');
        }

        final currentAddress = _safeMap(profile, 'current_address');
        _currHouseNumber.text = _safeString(currentAddress, 'house_number');
        _currVillageName.text = _safeString(currentAddress, 'village_name');
        _currPostOffice.text = _safeString(currentAddress, 'post_office');
        _currTehsil.text = _safeString(currentAddress, 'tehsil');
        _currPincode.text = _safeString(currentAddress, 'pincode');
        _currLandmark.text = _safeString(currentAddress, 'landmark');

        final savedCountry = _safeString(currentAddress, 'country', 'India');
        final savedState = _safeString(currentAddress, 'state');
        final savedDistrict = _safeString(currentAddress, 'district');
        final savedCity = _safeString(currentAddress, 'city');

        if (savedCountry.isNotEmpty) {
          _selectedCountry = savedCountry;
          _updateStates();
        }
        if (savedState.isNotEmpty) {
          _selectedState = savedState;
          _updateDistricts();
        }
        if (savedDistrict.isNotEmpty) {
          _selectedDistrict = savedDistrict;
        }
        if (savedCity.isNotEmpty && _currVillageName.text.isEmpty) {
          _currVillageName.text = savedCity;
        }

        _sameAsCurrent = profile['same_as_current'] is bool ? profile['same_as_current'] : true;
        final permanentAddress = _safeMap(profile, 'permanent_address');
        _permHouseNumber.text = _safeString(permanentAddress, 'house_number');
        _permVillageName.text = _safeString(permanentAddress, 'village_name');
        _permPostOffice.text = _safeString(permanentAddress, 'post_office');
        _permTehsil.text = _safeString(permanentAddress, 'tehsil');
        _permPincode.text = _safeString(permanentAddress, 'pincode');
        _permLandmark.text = _safeString(permanentAddress, 'landmark');

        final permCountry = _safeString(permanentAddress, 'country', 'India');
        final permState = _safeString(permanentAddress, 'state');
        final permDistrict = _safeString(permanentAddress, 'district');
        final permCity = _safeString(permanentAddress, 'city');

        if (permCountry.isNotEmpty) {
          _permSelectedCountry = permCountry;
          _updatePermStates();
        }
        if (permState.isNotEmpty) {
          _permSelectedState = permState;
          _updatePermDistricts();
        }
        if (permDistrict.isNotEmpty) {
          _permSelectedDistrict = permDistrict;
        }
        if (permCity.isNotEmpty && _permVillageName.text.isEmpty) {
          _permVillageName.text = permCity;
        }

        _summary.text = _safeString(profile, 'summary');
        _careerObjective.text = _safeString(profile, 'career_objective');
        _linkedinUrl.text = _safeString(profile, 'linkedin_url');
        _githubUrl.text = _safeString(profile, 'github_url');
        _portfolioUrl.text = _safeString(profile, 'portfolio_url');

        final socialLinks = _safeMap(profile, 'social_links');
        if (socialLinks.isNotEmpty) {
          _linkedinUrl.text = _safeString(socialLinks, 'linkedin', _linkedinUrl.text);
          _githubUrl.text = _safeString(socialLinks, 'github', _githubUrl.text);
          _portfolioUrl.text = _safeString(socialLinks, 'portfolio', _portfolioUrl.text);
          _twitterUrl.text = _safeString(socialLinks, 'twitter');
          _facebookUrl.text = _safeString(socialLinks, 'facebook');
          _instagramUrl.text = _safeString(socialLinks, 'instagram');
          _youtubeUrl.text = _safeString(socialLinks, 'youtube');
          _personalWebsiteUrl.text = _safeString(socialLinks, 'personal_website');
        }

        _preferredLocation.text = _safeString(profile, 'preferred_location');
        final compensation = _safeMap(profile, 'compensation_expectations');
        if (compensation.isNotEmpty) {
          _expectedSalaryMin.text = _safeString(compensation, 'expected_salary_min');
          _expectedSalaryMax.text = _safeString(compensation, 'expected_salary_max');
        }
        _openToRelocate = profile['open_to_relocate'] is bool ? profile['open_to_relocate'] : false;
        _openToRemoteWork = profile['open_to_remote_work'] is bool ? profile['open_to_remote_work'] : false;

        final jobTypes = profile['preferred_job_types'];
        if (jobTypes is List) {
          _preferredJobTypes = List<String>.from(jobTypes);
        }
        final industries = profile['preferred_industries'];
        if (industries is List) {
          _preferredIndustries = List<String>.from(industries);
        }

        _height.text = _safeNumber(profile, 'height');
        _weight.text = _safeNumber(profile, 'weight');

        final languages = profile['languages_known'];
        if (languages is List) {
          _languagesKnown.text = languages.join(', ');
        }

        _calculateAge();
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        showMessage(context, "Error loading profile: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _safeString(Map<String, dynamic> map, String key, [String defaultValue = '']) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  String _safeNumber(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is double) return value.toString();
    if (value is String) return value;
    return '';
  }

  Map<String, dynamic> _safeMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  String _normalizeBloodGroup(String? value) {
    if (value == null || value.isEmpty) return 'I don\'t know';
    final upperValue = value.toUpperCase();
    const options = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
    for (final option in options) {
      if (option.toUpperCase() == upperValue) return option;
    }
    return 'I don\'t know';
  }

  String _normalizeReligion(String? value) {
    if (value == null) return 'Hindu';
    const options = ['Hindu', 'Muslim', 'Sikh', 'Christian', 'Buddhist', 'Jain', 'Other'];
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return 'Other';
  }

  String _normalizeDisabilityCategory(String? value) {
    if (value == null) return 'LD (Learning Disability)';
    const options = ['LD (Learning Disability)', 'HI (Hearing Impairment)', 'VI (Visual Impairment)', 'MD (Multiple Disabilities)'];
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
      if (value.toLowerCase().contains('ld') && option.contains('LD')) return option;
      if (value.toLowerCase().contains('hi') && option.contains('HI')) return option;
      if (value.toLowerCase().contains('vi') && option.contains('VI')) return option;
      if (value.toLowerCase().contains('md') && option.contains('MD')) return option;
    }
    return 'LD (Learning Disability)';
  }

  /// ✅ SAVE → auto-jump to next tab (safe, no double increment)
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      showMessage(context, "Please fill all required fields", isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentAddress = {
        'house_number': _currHouseNumber.text.trim(),
        'village_name': _currVillageName.text.trim(),
        'city': _currVillageName.text.trim(),
        'post_office': _currPostOffice.text.trim(),
        'tehsil': _currTehsil.text.trim(),
        'district': _selectedDistrict ?? '',
        'state': _selectedState ?? '',
        'country': _selectedCountry ?? 'India',
        'pincode': _currPincode.text.trim(),
        'landmark': _currLandmark.text.trim(),
      };

      Map<String, dynamic>? permanentAddress;
      if (!_sameAsCurrent) {
        permanentAddress = {
          'house_number': _permHouseNumber.text.trim(),
          'village_name': _permVillageName.text.trim(),
          'city': _permVillageName.text.trim(),
          'post_office': _permPostOffice.text.trim(),
          'tehsil': _permTehsil.text.trim(),
          'district': _permSelectedDistrict ?? '',
          'state': _permSelectedState ?? '',
          'country': _permSelectedCountry ?? 'India',
          'pincode': _permPincode.text.trim(),
          'landmark': _permLandmark.text.trim(),
        };
      }

      double? disabilityPercentage;
      if (_isDisable && _disabilityPercentage.text.trim().isNotEmpty) {
        disabilityPercentage = double.tryParse(_disabilityPercentage.text.trim());
      }

      final data = <String, dynamic>{
        'full_name': _fullName.text.trim(),
        'first_name': _firstName.text.trim(),
        'middle_name': _middleName.text.trim(),
        'last_name': _lastName.text.trim(),
        'gender': _gender,
        'dob': _dob.text.trim(),
        'birth_place': _birthPlace.text.trim(),
        'blood_group': _bloodGroup == 'I don\'t know' ? '' : _bloodGroup,
        'nationality': _nationality,
        'religion': _religion,
        'category': _category,
        'hobbies': _hobbies,
        'interests': _interests,
        'father_name': _fatherName.text.trim(),
        'mother_name': _motherName.text.trim(),
        'guardian_name': _guardianName.text.trim(),
        'spouse_name': _spouseName.text.trim(),
        'marital_status': _maritalStatus,
        'family_annual_income': int.tryParse(_familyAnnualIncome.text.trim()),
        'number_of_dependents': int.tryParse(_numberOfDependents.text.trim()),
        'alternate_mobile': _alternateMobile.text.trim(),
        'whatsapp_number': _whatsappNumber.text.trim(),
        'emergency_contact': {
          'name': _emergencyContactName.text.trim(),
          'relationship': _emergencyContactRelation.text.trim(),
          'phone': _emergencyContactPhone.text.trim(),
        },
        'current_address': currentAddress,
        'same_as_current': _sameAsCurrent,
        'permanent_address': permanentAddress,
        'summary': _summary.text.trim(),
        'career_objective': _careerObjective.text.trim(),
        'linkedin_url': _linkedinUrl.text.trim(),
        'github_url': _githubUrl.text.trim(),
        'portfolio_url': _portfolioUrl.text.trim(),
        'social_links': {
          'linkedin': _linkedinUrl.text.trim(),
          'github': _githubUrl.text.trim(),
          'portfolio': _portfolioUrl.text.trim(),
          'twitter': _twitterUrl.text.trim(),
          'facebook': _facebookUrl.text.trim(),
          'instagram': _instagramUrl.text.trim(),
          'youtube': _youtubeUrl.text.trim(),
          'personal_website': _personalWebsiteUrl.text.trim(),
        },
        'preferred_location': _preferredLocation.text.trim(),
        'open_to_relocate': _openToRelocate,
        'open_to_remote_work': _openToRemoteWork,
        'preferred_job_types': _preferredJobTypes,
        'preferred_industries': _preferredIndustries,
        'compensation_expectations': {
          'expected_salary_min': int.tryParse(_expectedSalaryMin.text.trim()),
          'expected_salary_max': int.tryParse(_expectedSalaryMax.text.trim()),
          'expected_salary_currency': 'INR',
          'is_salary_negotiable': true,
        },
        'height': double.tryParse(_height.text.trim()),
        'weight': double.tryParse(_weight.text.trim()),
        'languages_known': _languagesKnown.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'disability': {
          'is_disabled': _isDisable,
          'disability_category': _isDisable ? _disabilityCategory : '',
          'disability_percentage': _isDisable ? disabilityPercentage : null,
          'disability_details': _isDisable ? _disabilityDetails.text.trim() : '',
        },
      };

      await UserService.saveProfile(data);

      if (!mounted) return;

      // ✅ Show success dialog
      await _showAISuccessDialog();

      if (!mounted) return;

      // ✅ After dialog closes, jump to next tab SAFELY
      _goToNextTabSafe();
    } catch (e) {
      if (mounted) {
        showMessage(context, "Save failed: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// ✅ SAFE next-tab navigation — never manually increments _currentTabIndex
  void _goToNextTabSafe() {
    final current = _tabController.index;
    if (current < _tabCount - 1) {
      _tabController.animateTo(current + 1);
      // Do NOT touch _currentTabIndex — listener handles it
    } else {
      // Last tab → just show message, no jump
      showMessage(context, "All sections completed! ✅", isError: false);
    }
  }

  /// ✅ SAFE previous-tab navigation
  void _goToPreviousTabSafe() {
    final current = _tabController.index;
    if (current > 0) {
      _tabController.animateTo(current - 1);
      // Do NOT touch _currentTabIndex — listener handles it
    }
  }

  Future<void> _showAISuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle, color: Colors.white, size: 40),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "Profile Saved! 🎉",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Your profile has been saved successfully.",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

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
                      _buildBasicInfoTab(),
                      _buildCategoryDisabilityTab(),
                      _buildFamilyContactTab(),
                      _buildAddressTab(),
                      _buildProfessionalTab(),
                      _buildJobPreferencesTab(),
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

  /// ✅ NON-SCROLLABLE TAB BAR — all 6 tabs always visible
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 15, spreadRadius: 5),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false, // ✅ All tabs visible
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(12),
        tabs: List.generate(_tabCount, (index) {
          final isSelected = _currentTabIndex == index;
          return Tab(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _tabIcons[index],
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                const SizedBox(height: 2),
                Text(
                  _tabLabels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        }),
        onTap: (index) {
          // Listener will sync _currentTabIndex — no setState needed
        },
      ),
    );
  }

  /// ✅ Bottom bar — Save (auto next) + Prev/Next buttons
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: List.generate(_tabCount, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _currentTabIndex >= index ? const Color(0xFF6C63FF) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "Step ${_currentTabIndex + 1} of $_tabCount • $_safeTabLabel",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              // Prev button
              if (_currentTabIndex > 0)
                IconButton(
                  onPressed: _goToPreviousTabSafe,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF6C63FF)),
                  tooltip: "Previous",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              if (_currentTabIndex > 0) const SizedBox(width: 8),
              // Save button — auto jumps to next tab after save
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.save, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _currentTabIndex < _tabCount - 1 ? "Save & Next" : "Save",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Next button — manual serial navigation
              if (_currentTabIndex < _tabCount - 1)
                IconButton(
                  onPressed: _goToNextTabSafe,
                  icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
                  tooltip: "Next",
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: Center(
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      child: const Center(child: Icon(Icons.auto_awesome, color: Colors.white, size: 40)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading your profile...",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(_safeTabIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Complete Your Profile",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "Step ${_currentTabIndex + 1} of $_tabCount • $_safeTabLabel",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(
              "${_currentTabIndex + 1}/$_tabCount",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, spreadRadius: 5)],
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
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Spacer(),
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, spreadRadius: 1)],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            hintText: hintText ?? (required ? null : "Optional"),
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade600, size: 20) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.transparent,
          ),
          validator: (value) => required && (value == null || value.isEmpty) ? "Required" : null,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, spreadRadius: 1)],
        ),
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString(), style: const TextStyle(color: Colors.black87)),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          validator: (value) => required && value == null ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildAIDateField(TextEditingController ctrl, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, spreadRadius: 1)],
        ),
        child: TextFormField(
          controller: ctrl,
          readOnly: true,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            prefixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(Icons.event, color: Colors.grey.shade400, size: 18),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null && mounted) {
              ctrl.text =
                  "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              _calculateAge();
            }
          },
          validator: (value) => required && (value == null || value.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildAIChipField(String title, List<String> selectedValues, List<String> availableOptions) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableOptions.map((option) {
              final isSelected = selectedValues.contains(option);
              return FilterChip(
                label: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    if (isSelected) {
                      selectedValues.remove(option);
                    } else {
                      selectedValues.add(option);
                    }
                  });
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: const Color(0xFF6C63FF),
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? const Color(0xFF6C63FF) : Colors.grey.shade300),
                ),
              );
            }).toList(),
          ),
          if (selectedValues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Selected: ${selectedValues.join(', ')}",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildGlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Basic Information", Icons.person, subtitle: "Fill your personal details"),
            _buildAITextField(_fullName, "Full Name *", required: true, prefixIcon: Icons.person),
            _buildAITextField(_firstName, "First Name", prefixIcon: Icons.person_outline),
            _buildAITextField(_middleName, "Middle Name", prefixIcon: Icons.person_outline),
            _buildAITextField(_lastName, "Last Name", prefixIcon: Icons.person_outline),
            _buildAIDropdown<String>(
              _gender,
              const ['Male', 'Female', 'Other', 'Prefer not to say'],
              "Gender",
              onChanged: (value) {
                if (value != null) setState(() => _gender = value);
              },
            ),
            _buildAIDateField(_dob, "Date of Birth"),
            _buildAITextField(_birthPlace, "Birth Place", prefixIcon: Icons.location_city),
            if (_age > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cake, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text("Age: $_age years",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            _buildAIDropdown<String>(
              _bloodGroup,
              const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'I don\'t know'],
              "Blood Group",
              onChanged: (value) {
                if (value != null) setState(() => _bloodGroup = value);
              },
            ),
            _buildAIDropdown<String>(
              _nationality,
              const ['Indian', 'Other'],
              "Nationality *",
              onChanged: (value) {
                if (value != null) setState(() => _nationality = value);
              },
            ),
            _buildAIDropdown<String>(
              _religion,
              const ['Hindu', 'Muslim', 'Sikh', 'Christian', 'Buddhist', 'Jain', 'Other'],
              "Religion",
              onChanged: (value) {
                if (value != null) setState(() => _religion = value);
              },
            ),
            const SizedBox(height: 8),
            _buildAIChipField("Hobbies", _hobbies, _hobbyOptions),
            const SizedBox(height: 8),
            _buildAIChipField("Interests", _interests, _interestOptions),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDisabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Category", Icons.category, subtitle: "Select your category as per government policies"),
                _buildAIDropdown<String>(
                  _category,
                  _categoryOptions,
                  "Select Category",
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Disability Information", Icons.accessible,
                    subtitle: "Toggle if you have any disability"),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isDisable
                          ? [Colors.orange.shade50, Colors.orange.shade100]
                          : [Colors.grey.shade50, Colors.grey.shade100],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDisable ? Colors.orange.shade300 : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _isDisable ? Colors.orange.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _isDisable ? Icons.accessible_forward : Icons.accessible,
                                  color: _isDisable ? Colors.orange.shade700 : Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Disability Status",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _isDisable ? Colors.orange.shade800 : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    _isDisable ? "Enabled" : "Disabled",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isDisable ? Colors.orange.shade600 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: _isDisable ? Colors.orange.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                if (_isDisable)
                                  BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
                              ],
                            ),
                            child: Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _isDisable,
                                onChanged: (value) {
                                  setState(() {
                                    _isDisable = value;
                                    if (!_isDisable) {
                                      _disabilityPercentage.clear();
                                      _disabilityDetails.clear();
                                    }
                                  });
                                },
                                activeColor: Colors.white,
                                activeTrackColor: Colors.orange,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isDisable) ...[
                        const SizedBox(height: 16),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAIDropdown<String>(
                                _disabilityCategory,
                                _disabilityCategories,
                                "Disability Category *",
                                onChanged: (value) {
                                  if (value != null) setState(() => _disabilityCategory = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildAITextField(
                                _disabilityPercentage,
                                "Disability Percentage (%)",
                                keyboardType: TextInputType.number,
                                hintText: "e.g., 40",
                                prefixIcon: Icons.percent,
                              ),
                              _buildAITextField(
                                _disabilityDetails,
                                "Disability Details",
                                maxLines: 3,
                                hintText: "Describe the nature of disability",
                                prefixIcon: Icons.description,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Family Details", Icons.family_restroom, subtitle: "Provide your family information"),
                _buildAITextField(_fatherName, "Father's Name", prefixIcon: Icons.man),
                _buildAITextField(_motherName, "Mother's Name", prefixIcon: Icons.woman),
                _buildAITextField(_guardianName, "Guardian Name", prefixIcon: Icons.person),
                _buildAITextField(_spouseName, "Spouse Name", prefixIcon: Icons.favorite),
                _buildAIDropdown<String>(
                  _maritalStatus,
                  const ['Unmarried', 'Married', 'Divorced', 'Widowed'],
                  "Marital Status",
                  onChanged: (value) {
                    if (value != null) setState(() => _maritalStatus = value);
                  },
                ),
                _buildAITextField(
                  _familyAnnualIncome,
                  "Family Annual Income (₹)",
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.currency_rupee,
                ),
                _buildAITextField(
                  _numberOfDependents,
                  "Number of Dependents",
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.people,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Additional Contact", Icons.contact_phone, subtitle: "Alternative contact details"),
                _buildAITextField(
                  _alternateMobile,
                  "Alternate Mobile",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_android,
                ),
                _buildAITextField(
                  _whatsappNumber,
                  "WhatsApp Number",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.message,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.red.shade50, Colors.red.shade100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      const Text("Emergency Contact",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildAITextField(_emergencyContactName, "Emergency Contact Person", prefixIcon: Icons.person),
                _buildAITextField(_emergencyContactRelation, "Relationship", prefixIcon: Icons.people),
                _buildAITextField(
                  _emergencyContactPhone,
                  "Emergency Contact Number",
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Current Address", Icons.home, subtitle: "Your current residential address"),
                _buildAITextField(_currHouseNumber, "House/Flat Number", prefixIcon: Icons.home),
                _buildAITextField(_currVillageName, "Village/City/Town", prefixIcon: Icons.location_city),
                _buildAITextField(_currPostOffice, "Post Office", prefixIcon: Icons.markunread_mailbox),
                _buildAITextField(_currTehsil, "Tehsil/Taluka", prefixIcon: Icons.map),
                const SizedBox(height: 8),
                const Text("Select Location", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                _buildAIDropdown<String>(_selectedCountry, _countries, "Country", onChanged: _onCountryChanged),
                _buildAIDropdown<String>(_selectedState, _states, "State", onChanged: _onStateChanged),
                _buildAIDropdown<String>(_selectedDistrict, _districts, "District", onChanged: _onDistrictChanged),
                _buildAITextField(_currPincode, "Pincode",
                    keyboardType: TextInputType.number, prefixIcon: Icons.pin_drop),
                _buildAITextField(_currLandmark, "Landmark", prefixIcon: Icons.place),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Permanent Address", Icons.location_city,
                    subtitle: "Your permanent residential address"),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _sameAsCurrent ? Colors.blue.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _sameAsCurrent ? Colors.blue.shade200 : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _sameAsCurrent,
                        onChanged: (value) => setState(() => _sameAsCurrent = value ?? false),
                        activeColor: const Color(0xFF6C63FF),
                      ),
                      const Text("Same as Current Address",
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                      const Spacer(),
                      if (_sameAsCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("✓ Auto-filled",
                              style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                if (!_sameAsCurrent) ...[
                  const SizedBox(height: 12),
                  _buildAITextField(_permHouseNumber, "House/Flat Number", prefixIcon: Icons.home),
                  _buildAITextField(_permVillageName, "Village/City/Town", prefixIcon: Icons.location_city),
                  _buildAITextField(_permPostOffice, "Post Office", prefixIcon: Icons.markunread_mailbox),
                  _buildAITextField(_permTehsil, "Tehsil/Taluka", prefixIcon: Icons.map),
                  const SizedBox(height: 8),
                  const Text("Select Location",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 8),
                  _buildAIDropdown<String>(_permSelectedCountry, _countries, "Country",
                      onChanged: _onPermCountryChanged),
                  _buildAIDropdown<String>(_permSelectedState, _permStates, "State",
                      onChanged: _onPermStateChanged),
                  _buildAIDropdown<String>(_permSelectedDistrict, _permDistricts, "District",
                      onChanged: _onPermDistrictChanged),
                  _buildAITextField(_permPincode, "Pincode",
                      keyboardType: TextInputType.number, prefixIcon: Icons.pin_drop),
                  _buildAITextField(_permLandmark, "Landmark", prefixIcon: Icons.place),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Professional Summary", Icons.description,
                    subtitle: "Tell about your professional background"),
                _buildAITextField(_summary, "Short Summary/Bio", maxLines: 3, prefixIcon: Icons.description),
                _buildAITextField(_careerObjective, "Career Objective", maxLines: 3, prefixIcon: Icons.flag),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Social & Professional Links", Icons.link,
                    subtitle: "Connect your professional profiles"),
                _buildAITextField(_linkedinUrl, "LinkedIn URL",
                    hintText: "https://linkedin.com/in/your-profile", prefixIcon: Icons.link),
                _buildAITextField(_githubUrl, "GitHub URL",
                    hintText: "https://github.com/your-username", prefixIcon: Icons.code),
                _buildAITextField(_portfolioUrl, "Portfolio Website",
                    hintText: "https://your-portfolio.com", prefixIcon: Icons.web),
                _buildAITextField(_twitterUrl, "Twitter / X URL",
                    hintText: "https://twitter.com/username", prefixIcon: Icons.alternate_email),
                _buildAITextField(_facebookUrl, "Facebook URL",
                    hintText: "https://facebook.com/username", prefixIcon: Icons.facebook),
                _buildAITextField(_instagramUrl, "Instagram URL",
                    hintText: "https://instagram.com/username", prefixIcon: Icons.camera_alt),
                _buildAITextField(_youtubeUrl, "YouTube Channel",
                    hintText: "https://youtube.com/@channel", prefixIcon: Icons.play_circle),
                _buildAITextField(_personalWebsiteUrl, "Personal Website",
                    hintText: "https://yourwebsite.com", prefixIcon: Icons.public),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Physical Attributes", Icons.fitness_center, subtitle: "Your physical measurements"),
                _buildAITextField(_height, "Height (cm)",
                    keyboardType: TextInputType.number, prefixIcon: Icons.height),
                _buildAITextField(_weight, "Weight (kg)",
                    keyboardType: TextInputType.number, prefixIcon: Icons.monitor_weight),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Languages Known", Icons.language, subtitle: "List all languages you speak"),
                _buildAITextField(
                  _languagesKnown,
                  "Languages (comma separated)",
                  hintText: "Hindi, English, Bengali",
                  prefixIcon: Icons.translate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ CheckboxListTile wrapped in Material to fix ink splash warning
  Widget _buildToggleTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          title: Text(title, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          activeColor: const Color(0xFF6C63FF),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
      ),
    );
  }

  Widget _buildJobPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildGlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Job Preferences", Icons.work, subtitle: "Set your career preferences"),
            _buildAITextField(_preferredLocation, "Preferred Job Location", prefixIcon: Icons.location_on),
            _buildAITextField(
              _expectedSalaryMin,
              "Expected Salary (Min) ₹",
              keyboardType: TextInputType.number,
              prefixIcon: Icons.currency_rupee,
            ),
            _buildAITextField(
              _expectedSalaryMax,
              "Expected Salary (Max) ₹",
              keyboardType: TextInputType.number,
              prefixIcon: Icons.currency_rupee,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildToggleTile(
                    title: "Open to Relocate",
                    value: _openToRelocate,
                    onChanged: (v) => setState(() => _openToRelocate = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildToggleTile(
                    title: "Open to Remote",
                    value: _openToRemoteWork,
                    onChanged: (v) => setState(() => _openToRemoteWork = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAIChipField("Preferred Job Types", _preferredJobTypes, const [
              "Full-time", "Part-time", "Contract", "Internship", "Freelance", "Remote", "Hybrid"
            ]),
            _buildAIChipField("Preferred Industries", _preferredIndustries, const [
              "IT/Software", "Banking", "Education", "Healthcare", "Manufacturing",
              "Retail", "Construction", "Agriculture", "Transport", "Government"
            ]),
          ],
        ),
      ),
    );
  }
}