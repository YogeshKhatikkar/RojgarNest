// lib/features/user/presentation/screens/education_screen.dart
// ✅ COMPLETE AI-BASED MODERN DESIGN
// ✅ ADDED: Achievements field
// ✅ ADDED: Duplicate prevention (same level + degree + institute)
// ✅ FIXED: Toggle switch loading
// ✅ FIXED: Edit & Delete buttons working properly
// ✅ FIXED: Delete now works with proper error surfacing
// ✅ ADDED: Auto-scroll to form on edit + editing highlight
// ✅ FIXED: Robust ID extraction (String / MongoDB $oid / nested maps / int)
// ✅ FIXED: Qualification Level visible in saved records
// ✅ FIXED: NO duplicate level (chip shows level; title shows degree/stream only)
// ✅ FIXED: _getLevelColor returns MaterialColor (so .shadeXXX works)
// ✅ FIXED: No stray characters at end of file
// ✅ FIXED: Dropdown selection list names now clearly visible

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/user/data/user_service.dart';
import 'package:rojgarnest/core/master_date/education.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  List<Map<String, dynamic>> _educationList = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEducated = true;

  final _instituteCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _percentageCtrl = TextEditingController();
  final _mediumCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _subjectsCtrl = TextEditingController();
  final _backlogsCtrl = TextEditingController();
  final _certificateUrlCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _achievementsCtrl = TextEditingController();

  String _selectedLevel = '10th';
  String _selectedDegree = '';
  String _selectedStream = '';
  String _selectedBoard = '';
  String _selectedResultType = 'Percentage';

  List<String> _degreeOptions = [];
  List<String> _streamOptions = [];
  List<String> _boardOptions = [];

  bool _canRead = false;
  bool _canWrite = false;
  String _basicLevel = 'None';
  final _nonEduLanguages = TextEditingController();
  final _nonEduSkills = TextEditingController();

  String? _editingId;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  final List<String> _levels = const [
    '10th', '12th', 'Diploma', 'Graduation', 'Post Graduation', 'PhD',
    'Certificate', 'Vocational', 'ITI',
  ];

  final List<String> _resultTypes = const ['Percentage', 'CGPA', 'GPA', 'Grade'];
  final List<String> _basicLevels = const [
    'None', 'Below 5th', '5th Pass', '8th Pass'
  ];

  @override
  void initState() {
    super.initState();
    _loadEducation();
    _updateOptionsForLevel(_selectedLevel);
  }

  @override
  void dispose() {
    _instituteCtrl.dispose();
    _yearCtrl.dispose();
    _percentageCtrl.dispose();
    _mediumCtrl.dispose();
    _gradeCtrl.dispose();
    _subjectsCtrl.dispose();
    _backlogsCtrl.dispose();
    _certificateUrlCtrl.dispose();
    _boardCtrl.dispose();
    _achievementsCtrl.dispose();
    _nonEduLanguages.dispose();
    _nonEduSkills.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isNonEmpty(dynamic v) =>
      v != null && v.toString().trim().isNotEmpty;

  /// Extra identifier shown NEXT to the level chip (degree / stream).
  /// Returns EMPTY when level alone is enough (10th / 12th without stream).
  String _getEducationTitle(Map<String, dynamic> edu) {
    final degree = (edu['degree'] ?? '').toString().trim();
    final stream = (edu['stream'] ?? '').toString().trim();
    final level = (edu['level'] ?? '').toString().trim();

    if (degree.isNotEmpty) return degree;

    if (stream.isNotEmpty &&
        (level == '12th' || level == 'Vocational')) {
      return stream;
    }
    return '';
  }

  /// Full title for snackbars / delete dialog (level + degree fallback).
  String _getEducationFullTitle(Map<String, dynamic> edu) {
    final degree = (edu['degree'] ?? '').toString().trim();
    final level = (edu['level'] ?? '').toString().trim();
    if (degree.isNotEmpty) {
      return level.isNotEmpty ? '$level • $degree' : degree;
    }
    return level.isNotEmpty ? level : 'Education';
  }

  void _rebuildOptionsForLevel(String level) {
    _degreeOptions = [];
    _streamOptions = [];
    _boardOptions = [];

    if (level == '10th') {
      _boardOptions = List.from(EducationMasterData.tenthBoards);
    } else if (level == '12th') {
      _boardOptions = List.from(EducationMasterData.twelfthBoards);
      _streamOptions = List.from(EducationMasterData.getTwelfthStreams());
    } else if (level == 'Diploma') {
      _degreeOptions = List.from(EducationMasterData.getDiplomaCourseNames());
    } else if (level == 'Graduation' || level == 'Post Graduation') {
      _degreeOptions = List.from(EducationMasterData.getDegreeNames());
    } else if (level == 'PhD') {
      _degreeOptions =
          List.from(EducationMasterData.getDegreeNamesByType('Doctoral'));
    } else if (level == 'Certificate') {
      _degreeOptions = List.from(EducationMasterData.getCertificationNames());
    } else if (level == 'Vocational') {
      _streamOptions = List.from(EducationMasterData.getTwelfthStreams());
    } else if (level == 'ITI') {
      _degreeOptions = List.from(EducationMasterData.getItiTradeNames());
    }

    if (_selectedDegree.isNotEmpty &&
        !_degreeOptions.contains(_selectedDegree)) {
      _degreeOptions = [_selectedDegree, ..._degreeOptions];
    }
    if (_selectedStream.isNotEmpty &&
        !_streamOptions.contains(_selectedStream)) {
      _streamOptions = [_selectedStream, ..._streamOptions];
    }
    if (_selectedBoard.isNotEmpty && !_boardOptions.contains(_selectedBoard)) {
      _boardOptions = [_selectedBoard, ..._boardOptions];
    }
  }

  void _updateOptionsForLevel(String level) {
    setState(() {
      _selectedDegree = '';
      _selectedStream = '';
      _selectedBoard = '';
      _rebuildOptionsForLevel(level);

      _selectedDegree =
          _degreeOptions.isNotEmpty ? _degreeOptions.first : '';
      _selectedStream =
          _streamOptions.isNotEmpty ? _streamOptions.first : '';
      _selectedBoard = _boardOptions.isNotEmpty ? _boardOptions.first : '';
    });
  }

  void _onStreamChanged(String stream) {
    setState(() {
      _selectedStream = stream;
    });
    if (_selectedLevel == '12th' && stream.isNotEmpty) {
      final subjects = EducationMasterData.getSubjectsForStream(stream);
      if (subjects.isNotEmpty && _subjectsCtrl.text.isEmpty) {
        _subjectsCtrl.text = subjects.take(5).join(', ');
      }
    }
  }

  Future<void> _loadEducation({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await UserService.getProfileWithApplications(
          forceRefresh: forceRefresh);
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      final isEdu = profile['is_educated'] ?? true;

      if (mounted) {
        setState(() {
          _isEducated = isEdu;
          if (isEdu) {
            _educationList = List<Map<String, dynamic>>.from(
                profile['academic_records'] ?? []);
            _nonEduLanguages.clear();
            _nonEduSkills.clear();
          } else {
            _canRead = profile['can_read'] ?? false;
            _canWrite = profile['can_write'] ?? false;
            _basicLevel = profile['basic_education_level'] ?? 'None';
            _nonEduLanguages.text =
                (profile['languages_known'] as List?)?.join(', ') ?? '';
            _nonEduSkills.text =
                (profile['basic_skills'] as List?)?.join(', ') ?? '';
            _educationList = [];
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading education: $e");
      if (mounted) {
        showMessage(context, "Failed to load education: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isDuplicateEducation() {
    return _educationList.any((edu) {
      final eduId = _getId(edu);
      if (eduId != null && eduId == _editingId) return false;
      final sameLevel =
          (edu['level'] ?? '').toString().toLowerCase() ==
              _selectedLevel.toLowerCase();
      final sameDegree =
          (edu['degree'] ?? '').toString().toLowerCase() ==
              _selectedDegree.toLowerCase();
      final sameInstitute =
          (edu['institute'] ?? '').toString().toLowerCase() ==
              _instituteCtrl.text.trim().toLowerCase();
      return sameLevel && sameDegree && sameInstitute;
    });
  }

  String? _extractId(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.trim().isEmpty ? null : raw.trim();
    if (raw is Map) {
      if (raw.containsKey(r'$oid')) {
        final v = raw[r'$oid']?.toString().trim();
        return (v == null || v.isEmpty) ? null : v;
      }
      if (raw.containsKey('oid')) {
        final v = raw['oid']?.toString().trim();
        return (v == null || v.isEmpty) ? null : v;
      }
      if (raw.containsKey('id')) {
        return _extractId(raw['id']);
      }
      if (raw.containsKey(r'$id')) {
        return _extractId(raw[r'$id']);
      }
    }
    final s = raw.toString().trim();
    return (s.isEmpty || s == 'null' || s == 'undefined') ? null : s;
  }

  String? _getId(Map<String, dynamic> item) {
    final id = _extractId(item['_id']) ??
        _extractId(item['id']) ??
        _extractId(item['education_id']) ??
        _extractId(item['educationId']) ??
        _extractId(item['record_id']) ??
        _extractId(item['recordId']);

    if (id == null) {
      debugPrint('⚠️ No ID found for record: ${item.keys.toList()}');
    }
    return id;
  }

  void _scrollToForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _formKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.05,
        );
      }
    });
  }

  void _startEdit(Map<String, dynamic> item) {
    setState(() {
      _editingId = _getId(item);

      _selectedLevel = (item['level'] ?? '10th').toString();
      _selectedDegree = (item['degree'] ?? '').toString();
      _selectedStream = (item['stream'] ?? '').toString();
      _selectedBoard = (item['board_university'] ?? '').toString();
      _selectedResultType =
          (item['result_type'] ?? 'Percentage').toString();

      _instituteCtrl.text = (item['institute'] ?? '').toString();
      _yearCtrl.text = item['year_of_passing']?.toString() ?? '';
      _percentageCtrl.text = item['cgpa_percentage']?.toString() ?? '';
      _mediumCtrl.text = (item['medium'] ?? '').toString();
      _gradeCtrl.text = (item['grade'] ?? '').toString();
      _subjectsCtrl.text =
          (item['subjects'] as List?)?.join(', ') ?? '';
      _backlogsCtrl.text = item['backlogs']?.toString() ?? '0';
      _certificateUrlCtrl.text =
          (item['certificate_url'] ?? '').toString();
      _boardCtrl.text = (item['board_university'] ?? '').toString();
      _achievementsCtrl.text =
          (item['achievements'] as List?)?.join('\n') ?? '';

      _rebuildOptionsForLevel(_selectedLevel);
    });

    showMessage(context, "✏️ Editing: ${_getEducationFullTitle(item)}");
    _scrollToForm();
  }

  void _clearForm() {
    _editingId = null;
    _selectedLevel = '10th';
    _selectedDegree = '';
    _selectedStream = '';
    _selectedBoard = '';
    _selectedResultType = 'Percentage';
    _instituteCtrl.clear();
    _yearCtrl.clear();
    _percentageCtrl.clear();
    _mediumCtrl.clear();
    _gradeCtrl.clear();
    _subjectsCtrl.clear();
    _backlogsCtrl.clear();
    _certificateUrlCtrl.clear();
    _boardCtrl.clear();
    _achievementsCtrl.clear();
    _updateOptionsForLevel('10th');
  }

  void _cancelEdit() {
    setState(() => _clearForm());
    showMessage(context, "Edit cancelled");
  }

  Future<void> _toggleEducationMode(bool value) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (value) {
        if (_nonEduLanguages.text.isNotEmpty ||
            _nonEduSkills.text.isNotEmpty ||
            _canRead ||
            _canWrite) {
          await _saveNonEducated();
        }
        await UserService.saveProfile({'is_educated': true});
        _nonEduLanguages.clear();
        _nonEduSkills.clear();
        _canRead = false;
        _canWrite = false;
        _basicLevel = 'None';
        await _loadEducation(forceRefresh: true);
        if (mounted) {
          showMessage(context, "✅ Switched to Formal Education Mode.");
        }
      } else {
        await UserService.saveProfile({'is_educated': false});
        _educationList = [];
        _clearForm();
        await _loadEducation(forceRefresh: true);
        if (mounted) {
          showMessage(context, "✅ Switched to Basic Literacy Mode.");
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to switch mode: $e", isError: true);
      }
      if (mounted) setState(() => _isEducated = !value);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveEducation() async {
    if (!_isEducated) {
      await _saveNonEducated();
      return;
    }

    if (_instituteCtrl.text.trim().isEmpty ||
        _yearCtrl.text.trim().isEmpty) {
      showMessage(context, "Institute and Year are required",
          isError: true);
      return;
    }

    if (_isDuplicateEducation()) {
      showMessage(context,
          "⚠️ This education record already exists!",
          isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'level': _selectedLevel,
      'degree': _degreeOptions.isNotEmpty ? _selectedDegree : '',
      'stream': _streamOptions.isNotEmpty ? _selectedStream : '',
      'institute': _instituteCtrl.text.trim(),
      'board_university':
          _boardOptions.isNotEmpty ? _selectedBoard : _boardCtrl.text.trim(),
      'year_of_passing': int.tryParse(_yearCtrl.text.trim()) ?? 0,
      'cgpa_percentage': double.tryParse(_percentageCtrl.text.trim()),
      'result_type': _selectedResultType,
      'grade': _gradeCtrl.text.trim(),
      'medium': _mediumCtrl.text.trim(),
      'subjects': _subjectsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'backlogs': int.tryParse(_backlogsCtrl.text.trim()) ?? 0,
      'certificate_url': _certificateUrlCtrl.text.trim(),
      'achievements': _achievementsCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    final wasEditing = _editingId != null;

    try {
      if (wasEditing) {
        await UserService.updateEducation(_editingId!, payload);
      } else {
        await UserService.addEducation(payload);
      }
      setState(() => _clearForm());
      await _loadEducation(forceRefresh: true);
      if (mounted) {
        showMessage(
            context,
            wasEditing
                ? "Education updated successfully!"
                : "Education saved successfully!");
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveNonEducated() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'is_educated': false,
        'can_read': _canRead,
        'can_write': _canWrite,
        'basic_education_level': _basicLevel,
        'languages_known': _nonEduLanguages.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'basic_skills': _nonEduSkills.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      };
      await UserService.saveProfile(data);
      await _loadEducation(forceRefresh: true);
      if (mounted) {
        showMessage(context, "Non-Educated information saved!");
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEducation(String? id, String degree) async {
    debugPrint('🗑️ _deleteEducation called → id=$id, degree=$degree');

    if (id == null || id.isEmpty) {
      if (mounted) {
        showMessage(
          context,
          "❌ Cannot delete: record ID is missing. Please refresh the page.",
          isError: true,
        );
      }
      return;
    }

    if (_isSaving) {
      debugPrint('⚠️ Delete already in progress, skipping');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child:
                  Text("Delete Education", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$degree"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      await UserService.deleteEducation(id);

      if (_editingId == id) {
        _clearForm();
      }
      await _loadEducation(forceRefresh: true);
      if (mounted) {
        showMessage(context, "✅ Education deleted successfully!");
      }
    } catch (e, st) {
      debugPrint('❌ Delete failed: $e\n$st');
      if (mounted) {
        final msg = e.toString().replaceAll('Exception:', '').trim();
        showMessage(
          context,
          "❌ Failed to delete: ${msg.isEmpty ? 'Unknown error' : msg}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getLevelIcon(String level) {
    switch (level) {
      case '10th':
        return '🎓';
      case '12th':
        return '📚';
      case 'Diploma':
        return '📜';
      case 'Graduation':
        return '🎓';
      case 'Post Graduation':
        return '🏆';
      case 'PhD':
        return '🥇';
      default:
        return '📖';
    }
  }

  // ✅ Return type is MaterialColor so .shade50 / .shade100 / .shade700 work.
  MaterialColor _getLevelColor(String level) {
    switch (level) {
      case '10th':
        return Colors.blue;
      case '12th':
        return Colors.green;
      case 'Diploma':
        return Colors.orange;
      case 'Graduation':
        return Colors.purple;
      case 'Post Graduation':
        return Colors.teal;
      case 'PhD':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildEducatedToggle(),
                const SizedBox(height: 20),
                if (_isEducated) ...[
                  _buildForm(),
                  const SizedBox(height: 24),
                  _buildRecordsList(),
                  const SizedBox(height: 16),
                  _buildInfoNote(),
                ] else ...[
                  _buildNonEducatedSection(),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
                        gradient: const LinearGradient(colors: [
                          Color(0xFF6C63FF),
                          Color(0xFFFF6588)
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF)
                                .withOpacity(0.3),
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
                  );
                },
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)])
                    .createShader(bounds),
                child: const Text(
                  "AI is loading your education...",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
              ),
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
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.school_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Education Details",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEducated
                      ? "Add your academic qualifications"
                      : "Add your basic reading/writing skills",
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8)),
                ),
              ],
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
        border:
            Border.all(color: Colors.white.withOpacity(0.5), width: 1),
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

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          Container(
            width: 30,
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducatedToggle() {
    final isEducated = _isEducated;
    return _buildGlassContainer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEducated
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEducated ? Icons.school : Icons.text_fields,
                  color: isEducated
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEducated ? "Formal Education" : "Basic Literacy",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEducated
                          ? Colors.blue.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                  Text(
                    isEducated
                        ? "Add your academic qualifications"
                        : "Add your basic reading/writing skills",
                    style: TextStyle(
                      fontSize: 12,
                      color: isEducated
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isEducated
                  ? Colors.blue.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (isEducated ? Colors.blue : Colors.green)
                      .withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isEducated,
                onChanged: _toggleEducationMode,
                activeColor: Colors.white,
                activeTrackColor: Colors.blue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.green,
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
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            hintText: hintText ?? (required ? null : "Optional"),
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey.shade600, size: 20)
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
          validator: (value) =>
              required && (value == null || value.isEmpty)
                  ? "Required"
                  : null,
        ),
      ),
    );
  }

  // ✅ FIXED: Dropdown selection list names now clearly visible
  Widget _buildAIDropdown<T>(
    T? value,
    List<T> items,
    String label, {
    void Function(T?)? onChanged,
    bool required = false,
  }) {
    final T? safeValue =
        (value != null && items.contains(value)) ? value : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: DropdownButtonFormField<T>(
          value: safeValue,
          // ✅ Dropdown menu background white — items clearly visible
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            suffixIcon:
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ),
          // ✅ Selected value text style — clearly visible
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  // ✅ Item name text — black, 15px, medium weight
                  child: Text(
                    item.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
          validator: (value) =>
              required && value == null ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      key: _formKey,
      child: _buildGlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editingId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit,
                        size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You are editing an existing record",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            _sectionHeader(
              _editingId == null
                  ? "Add New Education"
                  : "Edit Education",
              _editingId == null
                  ? Icons.add_circle_outline
                  : Icons.edit,
            ),
            _buildAIDropdown<String>(
              _selectedLevel,
              _levels,
              "Qualification Level",
              required: true,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedLevel = v;
                    _updateOptionsForLevel(_selectedLevel);
                  });
                }
              },
            ),
            if (_degreeOptions.isNotEmpty)
              _buildAIDropdown<String>(
                _selectedDegree.isNotEmpty ? _selectedDegree : null,
                _degreeOptions,
                "Degree/Course Name",
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDegree = v);
                },
              ),
            if (_streamOptions.isNotEmpty)
              _buildAIDropdown<String>(
                _selectedStream.isNotEmpty ? _selectedStream : null,
                _streamOptions,
                "Stream/Specialization",
                onChanged: (v) {
                  if (v != null) _onStreamChanged(v);
                },
              ),
            _buildAITextField(
                _instituteCtrl, "School/College/Institute",
                required: true, prefixIcon: Icons.business),
            if (_boardOptions.isNotEmpty)
              _buildAIDropdown<String>(
                _selectedBoard.isNotEmpty ? _selectedBoard : null,
                _boardOptions,
                "Board/University",
                onChanged: (v) {
                  if (v != null) setState(() => _selectedBoard = v);
                },
              )
            else
              _buildAITextField(_boardCtrl, "Board/University",
                  prefixIcon: Icons.account_balance),
            _buildAITextField(_yearCtrl, "Year of Passing",
                required: true,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.calendar_today),
            _buildAIDropdown<String>(
              _selectedResultType,
              _resultTypes,
              "Result Type",
              onChanged: (v) {
                if (v != null) setState(() => _selectedResultType = v);
              },
            ),
            _buildAITextField(
                _percentageCtrl, "$_selectedResultType (Optional)",
                keyboardType: TextInputType.number,
                prefixIcon: Icons.percent),
            if (_selectedResultType == 'Grade')
              _buildAITextField(_gradeCtrl,
                  "Grade (e.g., A+, B, etc.)",
                  prefixIcon: Icons.grade),
            _buildAITextField(_mediumCtrl, "Medium of Instruction",
                prefixIcon: Icons.language),
            _buildAITextField(
                _subjectsCtrl, "Subjects (comma separated)",
                prefixIcon: Icons.subject, maxLines: 2),
            _buildAITextField(
                _backlogsCtrl, "Number of Backlogs (if any)",
                keyboardType: TextInputType.number,
                prefixIcon: Icons.warning),
            _buildAITextField(
                _certificateUrlCtrl, "Certificate URL (Optional)",
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link),
            _buildAITextField(
              _achievementsCtrl,
              "Achievements (one per line)",
              prefixIcon: Icons.emoji_events,
              maxLines: 3,
              hintText:
                  "e.g.,\nScored 95% in Mathematics\nWon inter-school quiz",
            ),
            const SizedBox(height: 20),
            _buildActionButtons(
              onSave: _saveEducation,
              onCancel: _editingId != null ? _cancelEdit : null,
              isSaving: _isSaving,
              saveLabel: _editingId == null
                  ? "Add Education"
                  : "Update Education",
              buttonColor:
                  _editingId == null ? Colors.blue : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required VoidCallback onSave,
    VoidCallback? onCancel,
    required bool isSaving,
    required String saveLabel,
    required Color buttonColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [buttonColor, buttonColor.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _editingId == null
                                ? Icons.save
                                : Icons.update,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(saveLabel,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.black87)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordsList() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text("Your Education Records",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "${_educationList.length} Records",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_educationList.isEmpty)
            _buildEmptyState(
              icon: Icons.school_outlined,
              title: "No education records added yet",
              subtitle:
                  "Add your first education record using the form above",
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _educationList.length,
              itemBuilder: (context, index) {
                final edu = _educationList[index];
                final id = _getId(edu) ?? 'idx_$index';
                return _buildEducationCard(edu, index, key: ValueKey(id));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return Tooltip(
      message: disabled ? "$tooltip (unavailable)" : tooltip,
      child: Material(
        color: disabled ? Colors.grey.shade200 : bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: disabled ? null : onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              color: disabled ? Colors.grey.shade500 : iconColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEducationCard(Map<String, dynamic> edu, int index,
      {Key? key}) {
    final levelColor = _getLevelColor(edu['level'] ?? '');
    final achievements = edu['achievements'] as List? ?? [];
    final id = _getId(edu);
    final isEditing = _editingId != null && _editingId == id;

    // ✅ FIX: title shows ONLY degree / stream (empty for 10th / 12th w/o stream)
    final displayTitle = _getEducationTitle(edu);

    final yearStr = _isNonEmpty(edu['year_of_passing'])
        ? edu['year_of_passing'].toString()
        : '-';
    final scoreStr = edu['cgpa_percentage'] != null
        ? ' | ${edu['result_type'] ?? "Score"}: ${edu['cgpa_percentage']}'
        : '';

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isEditing ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing ? Colors.orange : levelColor.withOpacity(0.3),
          width: isEditing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Text(_getLevelIcon(edu['level'] ?? ''),
              style: const TextStyle(fontSize: 24)),
        ),
        title: Row(
          children: [
            // ✅ Level chip — ALWAYS shown
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (edu['level'] ?? 'Education').toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: levelColor.shade700,
                  ),
                ),
              ),
            ),

            // ✅ Extra title (degree / stream) — only if non-empty
            if (displayTitle.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),

            if (isEditing)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text("Editing",
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isNonEmpty(edu['institute']))
              Text(
                edu['institute'].toString(),
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 13),
              ),
            Text(
              "Year: $yearStr$scoreStr",
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionIcon(
              icon: Icons.edit,
              iconColor: isEditing
                  ? Colors.orange.shade800
                  : Colors.blue.shade700,
              bgColor: isEditing
                  ? Colors.orange.shade100
                  : Colors.blue.shade50,
              tooltip: "Edit",
              onTap: (id == null || _isSaving)
                  ? null
                  : () => _startEdit(edu),
            ),
            const SizedBox(width: 6),
            _buildActionIcon(
              icon: Icons.delete,
              iconColor: Colors.red.shade700,
              bgColor: Colors.red.shade50,
              tooltip: "Delete",
              onTap: _isSaving
                  ? null
                  : () => _deleteEducation(id, _getEducationFullTitle(edu)),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isNonEmpty(edu['level']))
                  _buildDetailRow(Icons.school, "Level",
                      edu['level'].toString()),
                if (_isNonEmpty(edu['degree']))
                  _buildDetailRow(Icons.workspace_premium, "Degree",
                      edu['degree'].toString()),
                if (_isNonEmpty(edu['stream']))
                  _buildDetailRow(
                      Icons.category, "Stream", edu['stream'].toString()),
                if (_isNonEmpty(edu['board_university']))
                  _buildDetailRow(Icons.account_balance,
                      "Board/University", edu['board_university'].toString()),
                if (_isNonEmpty(edu['medium']))
                  _buildDetailRow(
                      Icons.language, "Medium", edu['medium'].toString()),
                if (_isNonEmpty(edu['grade']))
                  _buildDetailRow(
                      Icons.grade, "Grade", edu['grade'].toString()),
                if (edu['backlogs'] != null)
                  _buildDetailRow(Icons.warning, "Backlogs",
                      edu['backlogs'].toString()),
                if (_isNonEmpty(edu['certificate_url']))
                  _buildDetailRow(Icons.link, "Certificate",
                      edu['certificate_url'].toString()),
                if (edu['subjects'] != null &&
                    (edu['subjects'] as List).isNotEmpty)
                  _buildListRow(
                      Icons.subject, "Subjects", edu['subjects']),
                if (achievements.isNotEmpty)
                  _buildListRow(
                      Icons.emoji_events, "Achievements", achievements),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black87)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade800))),
        ],
      ),
    );
  }

  Widget _buildListRow(
      IconData icon, String label, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black87)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text("• ",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800)),
                          Expanded(
                            child: Text(item.toString(),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800)),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title,
              style:
                  TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You can add, edit, or delete your education records as needed. Duplicate entries are automatically prevented.",
              style: TextStyle(
                  fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonEducatedSection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              "Basic Literacy & Skills Information", Icons.text_fields),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  value: _canRead,
                  onChanged: (v) => setState(() => _canRead = v),
                  title: "Can Read",
                  subtitle: "Ability to read and understand text",
                  color: Colors.green,
                ),
                _buildSwitchTile(
                  value: _canWrite,
                  onChanged: (v) => setState(() => _canWrite = v),
                  title: "Can Write",
                  subtitle: "Ability to write and express thoughts",
                  color: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildAIDropdown<String>(
            _basicLevel,
            _basicLevels,
            "Basic Education Level",
            onChanged: (v) {
              if (v != null) setState(() => _basicLevel = v);
            },
          ),
          _buildAITextField(
              _nonEduLanguages, "Languages Known (comma separated)",
              prefixIcon: Icons.language),
          _buildAITextField(
              _nonEduSkills, "Basic Skills (comma separated)",
              prefixIcon: Icons.build, maxLines: 2),
          const SizedBox(height: 20),
          _buildActionButtons(
            onSave: _saveNonEducated,
            isSaving: _isSaving,
            saveLabel: "Save Information",
            buttonColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: color,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}