// lib/features/user/presentation/screens/experience_screen.dart
// ✅ COMPLETE - All resume sections: Work | Internships | Skills | Projects | Certs | Languages
// ✅ DUPLICATE PREVENTION in all sections
// ✅ Fresher mode with Skills/Projects/Certs/Languages
// ✅ FIXED: Font colors now clearly visible everywhere (text fields, dropdowns, labels, headers)
// ✅ ADDED: Animated AI loading screen (scale animation + gradient text shimmer)

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/user/data/user_service.dart';

class ExperienceScreen extends StatefulWidget {
  const ExperienceScreen({super.key});

  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> {
  // ==================== STATE ====================
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFresher = false;
  int _activeTabIndex = 0;

  List<Map<String, dynamic>> _experienceList = [];
  List<Map<String, dynamic>> _internshipList = [];
  List<Map<String, dynamic>> _skillsList = [];
  List<Map<String, dynamic>> _projectsList = [];
  List<Map<String, dynamic>> _certificationsList = [];
  List<Map<String, dynamic>> _languagesList = [];

  String? _editingExpId;
  String? _editingInternId;
  String? _editingSkillName;
  String? _editingProjectTitle;
  String? _editingCertName;
  String? _editingLangName;

  // ==================== EXPERIENCE CONTROLLERS ====================
  final _companyCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _workTypeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _achievementsCtrl = TextEditingController();
  final _skillsUsedCtrl = TextEditingController();
  final _reasonForLeaveCtrl = TextEditingController();
  final _reportingManagerCtrl = TextEditingController();
  final _teamSizeCtrl = TextEditingController();
  bool _isCurrent = false;
  String _employmentType = 'Full-time';
  final List<String> _employmentTypes = const [
    'Full-time', 'Part-time', 'Contract', 'Freelance', 'Internship', 'Consultant',
  ];

  // ==================== INTERNSHIP CONTROLLERS ====================
  final _internshipCompanyCtrl = TextEditingController();
  final _internshipRoleCtrl = TextEditingController();
  final _internshipStartCtrl = TextEditingController();
  final _internshipEndCtrl = TextEditingController();
  final _internshipDescCtrl = TextEditingController();
  final _internshipStipendCtrl = TextEditingController();
  final _internshipTechCtrl = TextEditingController();
  bool _isCurrentInternship = false;

  // ==================== SKILLS CONTROLLERS ====================
  final _skillNameCtrl = TextEditingController();
  final _skillYearsCtrl = TextEditingController();
  String _skillProficiency = 'Intermediate';
  String _skillCategory = 'Technical';
  final List<String> _proficiencyOptions = const ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
  final List<String> _skillCategoryOptions = const ['Technical', 'Soft Skill', 'Language', 'Tool', 'Domain'];

  // ==================== PROJECT CONTROLLERS ====================
  final _projectTitleCtrl = TextEditingController();
  final _projectDescCtrl = TextEditingController();
  final _projectTechCtrl = TextEditingController();
  final _projectRoleCtrl = TextEditingController();
  final _projectDurationCtrl = TextEditingController();
  final _projectUrlCtrl = TextEditingController();
  final _projectGithubCtrl = TextEditingController();

  // ==================== CERTIFICATION CONTROLLERS ====================
  final _certNameCtrl = TextEditingController();
  final _certIssuerCtrl = TextEditingController();
  final _certYearCtrl = TextEditingController();
  final _certCredentialCtrl = TextEditingController();
  final _certUrlCtrl = TextEditingController();

  // ==================== LANGUAGE CONTROLLERS ====================
  final _langNameCtrl = TextEditingController();
  String _langProficiency = 'Fluent';
  final List<String> _langProficiencyOptions = const [
    'Native', 'Fluent', 'Professional', 'Intermediate', 'Basic'
  ];
  bool _langRead = true;
  bool _langWrite = true;
  bool _langSpeak = true;

  // ==================== FRESHER CONTROLLERS ====================
  final _internshipDetailsCtrl = TextEditingController();
  final _trainingProgramCtrl = TextEditingController();
  final _dailyWageCtrl = TextEditingController();
  final _projectsDoneCtrl = TextEditingController();
  String _labourType = 'Mason';
  final List<String> _labourTypes = const [
    'Mason', 'Helper', 'Farming', 'Driver', 'Electrician',
    'Plumber', 'Carpenter', 'Painter', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    for (final c in [
      _companyCtrl, _roleCtrl, _industryCtrl, _workTypeCtrl, _locationCtrl,
      _salaryCtrl, _startDateCtrl, _endDateCtrl, _descriptionCtrl,
      _achievementsCtrl, _skillsUsedCtrl, _reasonForLeaveCtrl,
      _reportingManagerCtrl, _teamSizeCtrl,
      _internshipCompanyCtrl, _internshipRoleCtrl, _internshipStartCtrl,
      _internshipEndCtrl, _internshipDescCtrl, _internshipStipendCtrl,
      _internshipTechCtrl,
      _skillNameCtrl, _skillYearsCtrl,
      _projectTitleCtrl, _projectDescCtrl, _projectTechCtrl,
      _projectRoleCtrl, _projectDurationCtrl, _projectUrlCtrl, _projectGithubCtrl,
      _certNameCtrl, _certIssuerCtrl, _certYearCtrl, _certCredentialCtrl, _certUrlCtrl,
      _langNameCtrl,
      _internshipDetailsCtrl, _trainingProgramCtrl, _dailyWageCtrl, _projectsDoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAllData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await UserService.getProfileWithApplications(forceRefresh: forceRefresh);
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      _isFresher = profile['is_fresher'] == true;

      if (mounted) {
        setState(() {
          _experienceList = List<Map<String, dynamic>>.from(profile['experience'] ?? []);
          _internshipList = List<Map<String, dynamic>>.from(profile['internships'] ?? []);

          final skills = profile['skills'];
          if (skills is List) {
            _skillsList = skills.map((s) {
              if (s is Map) return Map<String, dynamic>.from(s);
              return {'name': s.toString(), 'proficiency': 'Intermediate', 'category': 'Technical'};
            }).toList();
          } else {
            _skillsList = [];
          }

          _projectsList = List<Map<String, dynamic>>.from(profile['projects'] ?? []);
          _certificationsList = List<Map<String, dynamic>>.from(profile['certifications'] ?? []);
          _languagesList = List<Map<String, dynamic>>.from(profile['languages'] ?? []);

          if (_isFresher) {
            _internshipDetailsCtrl.text = profile['internship_details'] ?? '';
            _trainingProgramCtrl.text = profile['training_program'] ?? '';
            _dailyWageCtrl.text = profile['daily_wage']?.toString() ?? '';
            _projectsDoneCtrl.text = profile['projects_done'] ?? '';
            _labourType = profile['labour_type'] ?? 'Mason';
          }
        });
      }
    } catch (e) {
      debugPrint("Load error: $e");
      if (mounted) showMessage(context, "Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== EXPERIENCE ====================
  void _startEditExp(Map<String, dynamic> item) {
    _editingExpId = item['_id'];
    _companyCtrl.text = item['company'] ?? '';
    _roleCtrl.text = item['role'] ?? '';
    _industryCtrl.text = item['industry_type'] ?? '';
    _workTypeCtrl.text = item['work_type'] ?? '';
    _locationCtrl.text = item['location'] ?? '';
    _salaryCtrl.text = item['salary']?.toString() ?? '';
    _startDateCtrl.text = item['start_date'] ?? '';
    _endDateCtrl.text = item['end_date'] ?? '';
    _descriptionCtrl.text = item['description'] ?? '';
    _achievementsCtrl.text = (item['achievements'] as List?)?.join('\n') ?? '';
    _skillsUsedCtrl.text = (item['skills_used'] as List?)?.join(', ') ?? '';
    _reasonForLeaveCtrl.text = item['reason_for_leaving'] ?? '';
    _reportingManagerCtrl.text = item['reporting_manager'] ?? '';
    _teamSizeCtrl.text = item['team_size']?.toString() ?? '';
    _isCurrent = item['end_date'] == null || item['end_date'] == '';
    _employmentType = item['employment_type'] ?? 'Full-time';
    setState(() {});
  }

  void _clearExpForm() {
    _editingExpId = null;
    for (final c in [_companyCtrl, _roleCtrl, _industryCtrl, _workTypeCtrl,
      _locationCtrl, _salaryCtrl, _startDateCtrl, _endDateCtrl, _descriptionCtrl,
      _achievementsCtrl, _skillsUsedCtrl, _reasonForLeaveCtrl,
      _reportingManagerCtrl, _teamSizeCtrl]) { c.clear(); }
    _isCurrent = false;
    _employmentType = 'Full-time';
    setState(() {});
  }

  bool _isExpDuplicate() {
    return _experienceList.any((e) =>
      e['company']?.toString().toLowerCase() == _companyCtrl.text.trim().toLowerCase() &&
      e['role']?.toString().toLowerCase() == _roleCtrl.text.trim().toLowerCase() &&
      e['start_date']?.toString() == _startDateCtrl.text.trim() &&
      e['_id'] != _editingExpId);
  }

  Future<void> _saveExperience() async {
    if (_companyCtrl.text.trim().isEmpty || _roleCtrl.text.trim().isEmpty) {
      showMessage(context, "Company and Role are required", isError: true);
      return;
    }
    if (_startDateCtrl.text.trim().isEmpty) {
      showMessage(context, "Start date is required", isError: true);
      return;
    }
    if (_isExpDuplicate()) {
      showMessage(context, "⚠️ This experience already exists!", isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final payload = {
      'company': _companyCtrl.text.trim(),
      'role': _roleCtrl.text.trim(),
      'industry_type': _industryCtrl.text.trim(),
      'work_type': _workTypeCtrl.text.trim(),
      'employment_type': _employmentType,
      'location': _locationCtrl.text.trim(),
      'salary': int.tryParse(_salaryCtrl.text.trim()),
      'start_date': _startDateCtrl.text.trim(),
      'end_date': _isCurrent ? null : _endDateCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
      'achievements': _achievementsCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'skills_used': _skillsUsedCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'reason_for_leaving': _reasonForLeaveCtrl.text.trim(),
      'reporting_manager': _reportingManagerCtrl.text.trim(),
      'team_size': int.tryParse(_teamSizeCtrl.text.trim()),
    };

    try {
      if (_editingExpId != null) {
        await UserService.updateExperience(_editingExpId!, payload);
      } else {
        await UserService.addExperience(payload);
      }
      _clearExpForm();
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Experience saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteExp(String id) async {
    final ok = await _confirmDelete("Delete Experience?");
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      await UserService.deleteExperience(id);
      await _loadAllData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== INTERNSHIP ====================
  void _startEditIntern(Map<String, dynamic> item) {
    _editingInternId = item['_id'];
    _internshipCompanyCtrl.text = item['company'] ?? '';
    _internshipRoleCtrl.text = item['role'] ?? '';
    _internshipStartCtrl.text = item['start_date'] ?? '';
    _internshipEndCtrl.text = item['end_date'] ?? '';
    _internshipDescCtrl.text = item['description'] ?? '';
    _internshipStipendCtrl.text = item['stipend']?.toString() ?? '';
    _internshipTechCtrl.text = (item['technologies'] as List?)?.join(', ') ?? '';
    _isCurrentInternship = item['end_date'] == null || item['end_date'] == '';
    setState(() {});
  }

  void _clearInternForm() {
    _editingInternId = null;
    for (final c in [_internshipCompanyCtrl, _internshipRoleCtrl,
      _internshipStartCtrl, _internshipEndCtrl, _internshipDescCtrl,
      _internshipStipendCtrl, _internshipTechCtrl]) { c.clear(); }
    _isCurrentInternship = false;
    setState(() {});
  }

  bool _isInternDuplicate() {
    return _internshipList.any((e) =>
      e['company']?.toString().toLowerCase() == _internshipCompanyCtrl.text.trim().toLowerCase() &&
      e['role']?.toString().toLowerCase() == _internshipRoleCtrl.text.trim().toLowerCase() &&
      e['_id'] != _editingInternId);
  }

  Future<void> _saveInternship() async {
    if (_internshipCompanyCtrl.text.trim().isEmpty || _internshipRoleCtrl.text.trim().isEmpty) {
      showMessage(context, "Company and Role are required", isError: true);
      return;
    }
    if (_internshipStartCtrl.text.trim().isEmpty) {
      showMessage(context, "Start date required", isError: true);
      return;
    }
    if (_isInternDuplicate()) {
      showMessage(context, "⚠️ This internship already exists!", isError: true);
      return;
    }
    setState(() => _isSaving = true);
    final payload = {
      'company': _internshipCompanyCtrl.text.trim(),
      'role': _internshipRoleCtrl.text.trim(),
      'start_date': _internshipStartCtrl.text.trim(),
      'end_date': _isCurrentInternship ? null : _internshipEndCtrl.text.trim(),
      'description': _internshipDescCtrl.text.trim(),
      'stipend': int.tryParse(_internshipStipendCtrl.text.trim()),
      'technologies': _internshipTechCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    };
    try {
      if (_editingInternId != null) {
        await UserService.updateInternship(_editingInternId!, payload);
      } else {
        await UserService.addInternship(payload);
      }
      _clearInternForm();
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Internship saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteIntern(String id) async {
    final ok = await _confirmDelete("Delete Internship?");
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      await UserService.deleteInternship(id);
      await _loadAllData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== SKILLS ====================
  bool _isSkillDuplicate() {
    return _skillsList.any((s) =>
      s['name']?.toString().toLowerCase() == _skillNameCtrl.text.trim().toLowerCase() &&
      s['name']?.toString().toLowerCase() != _editingSkillName?.toLowerCase());
  }

  Future<void> _saveSkill() async {
    final name = _skillNameCtrl.text.trim();
    if (name.isEmpty) {
      showMessage(context, "Skill name required", isError: true);
      return;
    }
    if (_isSkillDuplicate()) {
      showMessage(context, "⚠️ '$name' already added!", isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final list = List<Map<String, dynamic>>.from(_skillsList);
      if (_editingSkillName != null) {
        list.removeWhere((s) => s['name'] == _editingSkillName);
      }
      list.add({
        'name': name,
        'proficiency': _skillProficiency,
        'category': _skillCategory,
        'years_of_experience': int.tryParse(_skillYearsCtrl.text.trim()) ?? 0,
      });

      await UserService.saveProfile({'skills': list});
      _skillNameCtrl.clear();
      _skillYearsCtrl.clear();
      _editingSkillName = null;
      _skillProficiency = 'Intermediate';
      _skillCategory = 'Technical';
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Skill saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSkill(String name) async {
    final ok = await _confirmDelete("Delete skill '$name'?");
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      final list = _skillsList.where((s) => s['name'] != name).toList();
      await UserService.saveProfile({'skills': list});
      await _loadAllData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== PROJECTS ====================
  bool _isProjectDuplicate() {
    return _projectsList.any((p) =>
      p['title']?.toString().toLowerCase() == _projectTitleCtrl.text.trim().toLowerCase() &&
      p['title']?.toString().toLowerCase() != _editingProjectTitle?.toLowerCase());
  }

  Future<void> _saveProject() async {
    final title = _projectTitleCtrl.text.trim();
    if (title.isEmpty) {
      showMessage(context, "Project title required", isError: true);
      return;
    }
    if (_isProjectDuplicate()) {
      showMessage(context, "⚠️ Project '$title' already exists!", isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final list = List<Map<String, dynamic>>.from(_projectsList);
      if (_editingProjectTitle != null) {
        list.removeWhere((p) => p['title'] == _editingProjectTitle);
      }
      list.add({
        'title': title,
        'description': _projectDescCtrl.text.trim(),
        'technologies': _projectTechCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'role': _projectRoleCtrl.text.trim(),
        'duration': _projectDurationCtrl.text.trim(),
        'url': _projectUrlCtrl.text.trim(),
        'github_url': _projectGithubCtrl.text.trim(),
      });
      await UserService.saveProfile({'projects': list});
      for (final c in [_projectTitleCtrl, _projectDescCtrl, _projectTechCtrl,
        _projectRoleCtrl, _projectDurationCtrl, _projectUrlCtrl, _projectGithubCtrl]) { c.clear(); }
      _editingProjectTitle = null;
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Project saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteProject(String title) async {
    final ok = await _confirmDelete("Delete project '$title'?");
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      final list = _projectsList.where((p) => p['title'] != title).toList();
      await UserService.saveProfile({'projects': list});
      await _loadAllData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== CERTIFICATIONS ====================
  bool _isCertDuplicate() {
    return _certificationsList.any((c) =>
      c['name']?.toString().toLowerCase() == _certNameCtrl.text.trim().toLowerCase() &&
      c['name']?.toString().toLowerCase() != _editingCertName?.toLowerCase());
  }

  Future<void> _saveCert() async {
    final name = _certNameCtrl.text.trim();
    if (name.isEmpty) {
      showMessage(context, "Certification name required", isError: true);
      return;
    }
    if (_isCertDuplicate()) {
      showMessage(context, "⚠️ '$name' already added!", isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final list = List<Map<String, dynamic>>.from(_certificationsList);
      if (_editingCertName != null) {
        list.removeWhere((c) => c['name'] == _editingCertName);
      }
      list.add({
        'name': name,
        'issuer': _certIssuerCtrl.text.trim(),
        'year': int.tryParse(_certYearCtrl.text.trim()),
        'credential_id': _certCredentialCtrl.text.trim(),
        'url': _certUrlCtrl.text.trim(),
      });
      await UserService.saveProfile({'certifications': list});
      for (final c in [_certNameCtrl, _certIssuerCtrl, _certYearCtrl, _certCredentialCtrl, _certUrlCtrl]) { c.clear(); }
      _editingCertName = null;
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Certification saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteCert(String name) async {
    final ok = await _confirmDelete("Delete '$name'?");
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      final list = _certificationsList.where((c) => c['name'] != name).toList();
      await UserService.saveProfile({'certifications': list});
      await _loadAllData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== LANGUAGES ====================
  bool _isLangDuplicate() {
    return _languagesList.any((l) =>
      l['name']?.toString().toLowerCase() == _langNameCtrl.text.trim().toLowerCase() &&
      l['name']?.toString().toLowerCase() != _editingLangName?.toLowerCase());
  }

  Future<void> _saveLanguage() async {
    final name = _langNameCtrl.text.trim();
    if (name.isEmpty) {
      showMessage(context, "Language name required", isError: true);
      return;
    }
    if (_isLangDuplicate()) {
      showMessage(context, "⚠️ '$name' already added!", isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final list = List<Map<String, dynamic>>.from(_languagesList);
      if (_editingLangName != null) {
        list.removeWhere((l) => l['name'] == _editingLangName);
      }
      list.add({
        'name': name,
        'proficiency': _langProficiency,
        'read': _langRead,
        'write': _langWrite,
        'speak': _langSpeak,
      });
      await UserService.saveProfile({'languages': list});
      _langNameCtrl.clear();
      _editingLangName = null;
      _langProficiency = 'Fluent';
      _langRead = _langWrite = _langSpeak = true;
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Language saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLanguage(String name) async {
    final ok = await _confirmDelete("Delete '$name'?");
    if (!ok) return;
    setState(() => _isSaving = true);
    try {
      final list = _languagesList.where((l) => l['name'] != name).toList();
      await UserService.saveProfile({'languages': list});
      await _loadAllData(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== FRESHER ====================
  Future<void> _saveFresher() async {
    setState(() => _isSaving = true);
    try {
      await UserService.saveProfile({
        'is_fresher': true,
        'internship_details': _internshipDetailsCtrl.text.trim(),
        'training_program': _trainingProgramCtrl.text.trim(),
        'daily_wage': int.tryParse(_dailyWageCtrl.text.trim()),
        'projects_done': _projectsDoneCtrl.text.trim(),
        'labour_type': _labourType,
      });
      await _loadAllData(forceRefresh: true);
      if (mounted) showMessage(context, "Fresher info saved!");
    } catch (e) {
      if (mounted) showMessage(context, "$e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== TOGGLE MODE ====================
  Future<void> _toggleFresherMode(bool value) async {
    setState(() => _isLoading = true);
    try {
      if (value) {
        await UserService.saveProfile({'is_fresher': true});
      } else {
        await UserService.saveProfile({'is_fresher': false});
      }
      _activeTabIndex = 0;
      await _loadAllData(forceRefresh: true);
      if (mounted) {
        showMessage(context, value ? "✅ Fresher Mode" : "✅ Experienced Mode");
      }
    } catch (e) {
      if (mounted) showMessage(context, "Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      ctrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<bool> _confirmDelete(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirm"),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    return r == true;
  }

  String _formatDuration(String? startDate, String? endDate) {
    if (startDate == null || startDate.isEmpty) return '';
    try {
      final start = DateTime.parse(startDate);
      final end = endDate != null && endDate.isNotEmpty ? DateTime.parse(endDate) : DateTime.now();
      final years = end.year - start.year;
      final months = end.month - start.month;
      if (years > 0) return "$years yr${years > 1 ? 's' : ''} ${months > 0 ? '$months mon' : ''}";
      if (months > 0) return "$months month${months > 1 ? 's' : ''}";
      final days = end.difference(start).inDays;
      return "$days day${days > 1 ? 's' : ''}";
    } catch (e) {
      return '';
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _loadingScreen();
    return Scaffold(
      body: Container(
        decoration: _gradient(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 20),
                _fresherToggle(),
                const SizedBox(height: 16),
                _tabSelector(),
                const SizedBox(height: 16),
                _activeTabContent(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeTabContent() {
    if (_isFresher) {
      switch (_activeTabIndex) {
        case 0: return _skillsTab();
        case 1: return _projectsTab();
        case 2: return _certsTab();
        case 3: return _langsTab();
        default: return const SizedBox();
      }
    } else {
      switch (_activeTabIndex) {
        case 0: return _expTab();
        case 1: return _internTab();
        case 2: return _skillsTab();
        case 3: return _projectsTab();
        case 4: return _certsTab();
        case 5: return _langsTab();
        default: return const SizedBox();
      }
    }
  }

  // ✅ ANIMATED AI LOADING SCREEN
  // - Scale animation on the gradient icon box (2 sec)
  // - ShaderMask gradient text ("AI is loading your experience...")
  // - Pulsing circular progress indicator
  Widget _loadingScreen() => Scaffold(
    body: Container(
      decoration: _gradient(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Animated gradient icon box — scales up from 0 to 1
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
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // ✅ Gradient shimmer text
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ).createShader(bounds),
              child: const Text(
                "AI is loading your experience...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ✅ Circular progress indicator with gradient-ish tint
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  BoxDecoration _gradient() => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
    ),
  );

  Widget _header() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.work_outline, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Experience & Skills", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(_isFresher ? "Fresher Mode" : "Experienced Mode",
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _glass({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.5)),
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, spreadRadius: 5)],
    ),
    child: child,
  );

  Widget _sectionHeader(String t, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(i, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
      ],
    ),
  );

  Widget _fresherToggle() => _glass(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isFresher ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_isFresher ? Icons.school : Icons.work,
                  color: _isFresher ? Colors.green.shade700 : Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isFresher ? "Fresher Mode" : "Experienced Mode",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: _isFresher ? Colors.green.shade900 : Colors.blue.shade900)),
                Text(_isFresher ? "No work experience yet" : "Work experience available",
                    style: TextStyle(fontSize: 12,
                        color: _isFresher ? Colors.green.shade700 : Colors.blue.shade700)),
              ],
            ),
          ],
        ),
        Switch(
          value: _isFresher,
          onChanged: _toggleFresherMode,
          activeColor: Colors.white,
          activeTrackColor: Colors.green,
          inactiveTrackColor: Colors.blue,
        ),
      ],
    ),
  );

  Widget _tabSelector() {
    final tabs = _isFresher
        ? [
            _TabData('Skills', Icons.build, _skillsList.length, Colors.blue),
            _TabData('Projects', Icons.code, _projectsList.length, Colors.purple),
            _TabData('Certs', Icons.verified, _certificationsList.length, Colors.teal),
            _TabData('Languages', Icons.language, _languagesList.length, Colors.orange),
          ]
        : [
            _TabData('Work Exp', Icons.work, _experienceList.length, Colors.blue),
            _TabData('Internships', Icons.business_center, _internshipList.length, Colors.orange),
            _TabData('Skills', Icons.build, _skillsList.length, Colors.green),
            _TabData('Projects', Icons.code, _projectsList.length, Colors.purple),
            _TabData('Certs', Icons.verified, _certificationsList.length, Colors.teal),
            _TabData('Languages', Icons.language, _languagesList.length, Colors.red),
          ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final isSelected = _activeTabIndex == i;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => setState(() => _activeTabIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, color: isSelected ? t.color : Colors.grey.shade600, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: isSelected ? t.color : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? t.color.withOpacity(0.1) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text("${t.count}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: isSelected ? t.color : Colors.grey.shade600)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================== EXPERIENCE TAB ====================
  Widget _expTab() => Column(
    children: [
      _expForm(),
      const SizedBox(height: 20),
      _expList(),
      if (_isFresher) _fresherExtras(),
    ],
  );

  Widget _expForm() => _glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_editingExpId == null ? "Add Work Experience" : "Edit Work Experience",
            _editingExpId == null ? Icons.add_circle_outline : Icons.edit),
        _tf(_companyCtrl, "Company Name", required: true, icon: Icons.business),
        _tf(_roleCtrl, "Job Role / Designation", required: true, icon: Icons.work),
        _tf(_industryCtrl, "Industry Type", icon: Icons.factory),
        _dd<String>(_employmentType, _employmentTypes, "Employment Type",
            onChanged: (v) { if (v != null) setState(() => _employmentType = v); }),
        _tf(_workTypeCtrl, "Work Type (Remote/Onsite/Hybrid)", icon: Icons.location_city),
        _tf(_locationCtrl, "Work Location", icon: Icons.location_on),
        _tf(_salaryCtrl, "Monthly Salary (₹)", kt: TextInputType.number, icon: Icons.currency_rupee),
        Row(
          children: [
            Expanded(child: _dateField(_startDateCtrl, "Start Date", required: true)),
            const SizedBox(width: 12),
            Expanded(child: _dateField(_endDateCtrl, "End Date", enabled: !_isCurrent)),
          ],
        ),
        _switchTile(_isCurrent, (v) => setState(() => _isCurrent = v), "Currently working here"),
        _tf(_descriptionCtrl, "Job Description", maxLines: 3, icon: Icons.description),
        _tf(_achievementsCtrl, "Achievements (one per line)", maxLines: 3, icon: Icons.emoji_events),
        _tf(_skillsUsedCtrl, "Skills Used (comma separated)", icon: Icons.build),
        if (!_isCurrent) _tf(_reasonForLeaveCtrl, "Reason for Leaving", icon: Icons.exit_to_app),
        _tf(_reportingManagerCtrl, "Reporting Manager", icon: Icons.people),
        _tf(_teamSizeCtrl, "Team Size", kt: TextInputType.number, icon: Icons.group),
        const SizedBox(height: 20),
        _actionButtons(
          onSave: _saveExperience,
          onCancel: _editingExpId != null ? _clearExpForm : null,
          saveLabel: _editingExpId == null ? "Add Experience" : "Update",
          color: Colors.blue,
        ),
      ],
    ),
  );

  Widget _expList() => _glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Work Experience", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(20)),
              child: Text("${_experienceList.length} Records",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_experienceList.isEmpty)
          _emptyState(Icons.work_off, "No work experience added yet")
        else
          ..._experienceList.map((e) => _expCard(e)),
      ],
    ),
  );

  Widget _expCard(Map<String, dynamic> exp) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.blue.shade100),
    ),
    child: ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.work, color: Colors.blue, size: 24),
      ),
      title: Text(exp['role'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      subtitle: Text("${exp['company'] ?? ''}\n${exp['start_date']} - ${exp['end_date'] ?? 'Present'}",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
            onPressed: () => _startEditExp(exp),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
            onPressed: () => _deleteExp(exp['_id']),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((exp['description'] ?? '').toString().isNotEmpty)
                _detail(Icons.description, "Description", exp['description']),
              if (exp['achievements'] != null && (exp['achievements'] as List).isNotEmpty)
                _listDetail(Icons.emoji_events, "Achievements", exp['achievements']),
              if (exp['skills_used'] != null && (exp['skills_used'] as List).isNotEmpty)
                _listDetail(Icons.build, "Skills", exp['skills_used']),
            ],
          ),
        ),
      ],
    ),
  );

  // ==================== INTERNSHIP TAB ====================
  Widget _internTab() => Column(
    children: [
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(_editingInternId == null ? "Add Internship" : "Edit Internship",
                _editingInternId == null ? Icons.add_circle_outline : Icons.edit),
            _tf(_internshipCompanyCtrl, "Company Name", required: true, icon: Icons.business),
            _tf(_internshipRoleCtrl, "Internship Role", required: true, icon: Icons.work),
            Row(
              children: [
                Expanded(child: _dateField(_internshipStartCtrl, "Start Date", required: true)),
                const SizedBox(width: 12),
                Expanded(child: _dateField(_internshipEndCtrl, "End Date", enabled: !_isCurrentInternship)),
              ],
            ),
            _switchTile(_isCurrentInternship, (v) => setState(() => _isCurrentInternship = v), "Currently ongoing"),
            _tf(_internshipDescCtrl, "Description", maxLines: 3, icon: Icons.description),
            _tf(_internshipStipendCtrl, "Stipend (₹)", kt: TextInputType.number, icon: Icons.currency_rupee),
            _tf(_internshipTechCtrl, "Technologies/Skills (comma separated)", icon: Icons.computer),
            const SizedBox(height: 20),
            _actionButtons(
              onSave: _saveInternship,
              onCancel: _editingInternId != null ? _clearInternForm : null,
              saveLabel: _editingInternId == null ? "Add Internship" : "Update",
              color: Colors.orange,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Internships", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text("${_internshipList.length} Records",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_internshipList.isEmpty)
              _emptyState(Icons.business_center, "No internships added yet")
            else
              ..._internshipList.map((e) => _internCard(e)),
          ],
        ),
      ),
    ],
  );

  Widget _internCard(Map<String, dynamic> intern) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.orange.shade100),
    ),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.business_center, color: Colors.orange, size: 24),
      ),
      title: Text(intern['role'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      subtitle: Text("${intern['company'] ?? ''}\n${intern['start_date']} - ${intern['end_date'] ?? 'Present'}",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.orange.shade700, size: 20),
            onPressed: () => _startEditIntern(intern),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
            onPressed: () => _deleteIntern(intern['_id']),
          ),
        ],
      ),
    ),
  );

  // ==================== SKILLS TAB ====================
  Widget _skillsTab() => Column(
    children: [
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(_editingSkillName == null ? "Add Skill" : "Edit Skill",
                _editingSkillName == null ? Icons.add_circle_outline : Icons.edit),
            _tf(_skillNameCtrl, "Skill Name", required: true, icon: Icons.build,
                hint: "e.g., Python, Communication, Tally"),
            _dd<String>(_skillCategory, _skillCategoryOptions, "Category",
                onChanged: (v) { if (v != null) setState(() => _skillCategory = v); }),
            _dd<String>(_skillProficiency, _proficiencyOptions, "Proficiency",
                onChanged: (v) { if (v != null) setState(() => _skillProficiency = v); }),
            _tf(_skillYearsCtrl, "Years of Experience", kt: TextInputType.number, icon: Icons.timer),
            const SizedBox(height: 20),
            _actionButtons(
              onSave: _saveSkill,
              onCancel: _editingSkillName != null ? () { _skillNameCtrl.clear(); _skillYearsCtrl.clear(); _editingSkillName = null; setState(() {}); } : null,
              saveLabel: _editingSkillName == null ? "Add Skill" : "Update",
              color: Colors.green,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Skills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text("${_skillsList.length} Skills",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_skillsList.isEmpty)
              _emptyState(Icons.build, "No skills added yet")
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skillsList.map((s) {
                  final name = s['name']?.toString() ?? '';
                  final proficiency = s['proficiency']?.toString() ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                            if (proficiency.isNotEmpty)
                              Text(proficiency, style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _deleteSkill(name),
                          child: Icon(Icons.close, size: 16, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    ],
  );

  // ==================== PROJECTS TAB ====================
  Widget _projectsTab() => Column(
    children: [
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(_editingProjectTitle == null ? "Add Project" : "Edit Project",
                _editingProjectTitle == null ? Icons.add_circle_outline : Icons.edit),
            _tf(_projectTitleCtrl, "Project Title", required: true, icon: Icons.title),
            _tf(_projectDescCtrl, "Description", maxLines: 3, icon: Icons.description),
            _tf(_projectTechCtrl, "Technologies (comma separated)", icon: Icons.computer),
            _tf(_projectRoleCtrl, "Your Role", icon: Icons.person),
            _tf(_projectDurationCtrl, "Duration", icon: Icons.timer, hint: "e.g., 3 months"),
            _tf(_projectUrlCtrl, "Live URL", kt: TextInputType.url, icon: Icons.link),
            _tf(_projectGithubCtrl, "GitHub URL", kt: TextInputType.url, icon: Icons.code),
            const SizedBox(height: 20),
            _actionButtons(
              onSave: _saveProject,
              onCancel: _editingProjectTitle != null ? () { _clearProjectForm(); } : null,
              saveLabel: _editingProjectTitle == null ? "Add Project" : "Update",
              color: Colors.purple,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Projects", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text("${_projectsList.length} Projects",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_projectsList.isEmpty)
              _emptyState(Icons.code, "No projects added yet")
            else
              ..._projectsList.map((p) => _projectCard(p)),
          ],
        ),
      ),
    ],
  );

  void _clearProjectForm() {
    _projectTitleCtrl.clear();
    _projectDescCtrl.clear();
    _projectTechCtrl.clear();
    _projectRoleCtrl.clear();
    _projectDurationCtrl.clear();
    _projectUrlCtrl.clear();
    _projectGithubCtrl.clear();
    _editingProjectTitle = null;
    setState(() {});
  }

  Widget _projectCard(Map<String, dynamic> p) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.purple.shade100),
    ),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.code, color: Colors.purple, size: 24),
      ),
      title: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((p['description'] ?? '').toString().isNotEmpty)
            Text(p['description'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2),
          if (p['technologies'] != null && (p['technologies'] as List).isNotEmpty)
            Text("Tech: ${(p['technologies'] as List).join(', ')}",
                style: TextStyle(fontSize: 11, color: Colors.purple.shade700)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.purple.shade700, size: 20),
            onPressed: () {
              _editingProjectTitle = p['title'];
              _projectTitleCtrl.text = p['title'] ?? '';
              _projectDescCtrl.text = p['description'] ?? '';
              _projectTechCtrl.text = (p['technologies'] as List?)?.join(', ') ?? '';
              _projectRoleCtrl.text = p['role'] ?? '';
              _projectDurationCtrl.text = p['duration'] ?? '';
              _projectUrlCtrl.text = p['url'] ?? '';
              _projectGithubCtrl.text = p['github_url'] ?? '';
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
            onPressed: () => _deleteProject(p['title']),
          ),
        ],
      ),
    ),
  );

  // ==================== CERTIFICATIONS TAB ====================
  Widget _certsTab() => Column(
    children: [
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(_editingCertName == null ? "Add Certification" : "Edit Certification",
                _editingCertName == null ? Icons.add_circle_outline : Icons.edit),
            _tf(_certNameCtrl, "Certification Name", required: true, icon: Icons.verified),
            _tf(_certIssuerCtrl, "Issuer / Organization", icon: Icons.business),
            _tf(_certYearCtrl, "Year", kt: TextInputType.number, icon: Icons.calendar_today),
            _tf(_certCredentialCtrl, "Credential ID", icon: Icons.badge),
            _tf(_certUrlCtrl, "Certificate URL", kt: TextInputType.url, icon: Icons.link),
            const SizedBox(height: 20),
            _actionButtons(
              onSave: _saveCert,
              onCancel: _editingCertName != null ? () { _clearCertForm(); } : null,
              saveLabel: _editingCertName == null ? "Add Certification" : "Update",
              color: Colors.teal,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Certifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text("${_certificationsList.length} Certs",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_certificationsList.isEmpty)
              _emptyState(Icons.verified, "No certifications added yet")
            else
              ..._certificationsList.map((c) => _certCard(c)),
          ],
        ),
      ),
    ],
  );

  void _clearCertForm() {
    _certNameCtrl.clear();
    _certIssuerCtrl.clear();
    _certYearCtrl.clear();
    _certCredentialCtrl.clear();
    _certUrlCtrl.clear();
    _editingCertName = null;
    setState(() {});
  }

  Widget _certCard(Map<String, dynamic> c) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.teal.shade100),
    ),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.verified, color: Colors.teal, size: 24),
      ),
      title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      subtitle: Text(
        "${c['issuer'] ?? ''}${c['year'] != null ? ' • ${c['year']}' : ''}",
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.teal.shade700, size: 20),
            onPressed: () {
              _editingCertName = c['name'];
              _certNameCtrl.text = c['name'] ?? '';
              _certIssuerCtrl.text = c['issuer'] ?? '';
              _certYearCtrl.text = c['year']?.toString() ?? '';
              _certCredentialCtrl.text = c['credential_id'] ?? '';
              _certUrlCtrl.text = c['url'] ?? '';
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
            onPressed: () => _deleteCert(c['name']),
          ),
        ],
      ),
    ),
  );

  // ==================== LANGUAGES TAB ====================
  Widget _langsTab() => Column(
    children: [
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(_editingLangName == null ? "Add Language" : "Edit Language",
                _editingLangName == null ? Icons.add_circle_outline : Icons.edit),
            _tf(_langNameCtrl, "Language Name", required: true, icon: Icons.language,
                hint: "e.g., Hindi, English, Marathi"),
            _dd<String>(_langProficiency, _langProficiencyOptions, "Proficiency",
                onChanged: (v) { if (v != null) setState(() => _langProficiency = v); }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _switchTile(_langRead, (v) => setState(() => _langRead = v), "Read")),
                Expanded(child: _switchTile(_langWrite, (v) => setState(() => _langWrite = v), "Write")),
                Expanded(child: _switchTile(_langSpeak, (v) => setState(() => _langSpeak = v), "Speak")),
              ],
            ),
            const SizedBox(height: 20),
            _actionButtons(
              onSave: _saveLanguage,
              onCancel: _editingLangName != null ? () { _clearLangForm(); } : null,
              saveLabel: _editingLangName == null ? "Add Language" : "Update",
              color: Colors.red,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Languages", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text("${_languagesList.length} Languages",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_languagesList.isEmpty)
              _emptyState(Icons.language, "No languages added yet")
            else
              ..._languagesList.map((l) => _langCard(l)),
          ],
        ),
      ),
    ],
  );

  void _clearLangForm() {
    _langNameCtrl.clear();
    _editingLangName = null;
    _langProficiency = 'Fluent';
    _langRead = _langWrite = _langSpeak = true;
    setState(() {});
  }

  Widget _langCard(Map<String, dynamic> l) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade100),
    ),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.language, color: Colors.red, size: 24),
      ),
      title: Text(l['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
      subtitle: Row(
        children: [
          if (l['proficiency'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(l['proficiency'].toString(),
                  style: TextStyle(fontSize: 10, color: Colors.red.shade900)),
            ),
          const SizedBox(width: 8),
          if (l['read'] == true) const Icon(Icons.menu_book, size: 14, color: Colors.grey),
          if (l['write'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.edit, size: 14, color: Colors.grey)),
          if (l['speak'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.record_voice_over, size: 14, color: Colors.grey)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.red.shade700, size: 20),
            onPressed: () {
              _editingLangName = l['name'];
              _langNameCtrl.text = l['name'] ?? '';
              _langProficiency = l['proficiency'] ?? 'Fluent';
              _langRead = l['read'] ?? true;
              _langWrite = l['write'] ?? true;
              _langSpeak = l['speak'] ?? true;
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
            onPressed: () => _deleteLanguage(l['name']),
          ),
        ],
      ),
    ),
  );

  // ==================== FRESHER EXTRAS ====================
  Widget _fresherExtras() => _glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Fresher Information", Icons.school),
        _tf(_internshipDetailsCtrl, "Internship Details", maxLines: 2, icon: Icons.school),
        _tf(_trainingProgramCtrl, "Training Programs", maxLines: 2, icon: Icons.assignment),
        _tf(_dailyWageCtrl, "Daily Wage (₹/day)", kt: TextInputType.number, icon: Icons.currency_rupee),
        _tf(_projectsDoneCtrl, "Projects Done", maxLines: 2, icon: Icons.code),
        _dd<String>(_labourType, _labourTypes, "Work Type",
            onChanged: (v) { if (v != null) setState(() => _labourType = v); }),
        const SizedBox(height: 20),
        _actionButtons(
          onSave: _saveFresher,
          saveLabel: "Save Fresher Info",
          color: Colors.green,
        ),
      ],
    ),
  );

  // ==================== HELPERS ====================
  // ✅ FIXED: Text field text color explicitly set to black87 for clear visibility
  Widget _tf(TextEditingController c, String label,
      {TextInputType kt = TextInputType.text, bool required = false,
      int maxLines = 1, String? hint, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextFormField(
          controller: c,
          keyboardType: kt,
          maxLines: maxLines,
          // ✅ Input text color — clearly visible
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            // ✅ Label text color — clearly visible
            labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            // ✅ Hint text color — clearly visible
            hintText: hint ?? (required ? null : "Optional"),
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600, size: 20) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) => required && (v == null || v.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  // ✅ FIXED: Dropdown menu text colors now clearly visible
  Widget _dd<T>(T? v, List<T> items, String label,
      {Function(T?)? onChanged, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonFormField<T>(
          value: v,
          // ✅ Dropdown menu background white — items clearly visible
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            // ✅ Label text color — clearly visible
            labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ),
          // ✅ Selected value text style — clearly visible
          style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
          items: items.map((i) => DropdownMenuItem<T>(
            value: i,
            // ✅ Item name text — black, 15px, medium weight
            child: Text(
              i.toString(),
              style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          )).toList(),
          onChanged: onChanged,
          isExpanded: true,
          validator: (val) => required && val == null ? "Required" : null,
        ),
      ),
    );
  }

  // ✅ FIXED: Date field text color explicitly set
  Widget _dateField(TextEditingController c, String label,
      {bool enabled = true, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextFormField(
          controller: c,
          readOnly: true,
          enabled: enabled,
          // ✅ Date text color — clearly visible
          style: TextStyle(color: enabled ? Colors.black87 : Colors.grey.shade500, fontSize: 15),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            // ✅ Label text color — clearly visible
            labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            prefixIcon: Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onTap: enabled ? () => _pickDate(c) : null,
          validator: (v) => required && (v == null || v.isEmpty) ? "Required" : null,
        ),
      ),
    );
  }

  Widget _switchTile(bool value, ValueChanged<bool> onChanged, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _actionButtons({
    required VoidCallback onSave,
    VoidCallback? onCancel,
    required String saveLabel,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(saveLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: const Text("Cancel", style: TextStyle(color: Colors.black87)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _emptyState(IconData icon, String title) => Container(
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
      ],
    ),
  );

  Widget _detail(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87))),
          const SizedBox(width: 8),
          Expanded(child: Text(value.toString(), style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _listDetail(IconData icon, String label, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black87))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => Text("• ${item.toString()}",
                  style: const TextStyle(fontSize: 13, color: Colors.black87))).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabData {
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  _TabData(this.label, this.icon, this.count, this.color);
}