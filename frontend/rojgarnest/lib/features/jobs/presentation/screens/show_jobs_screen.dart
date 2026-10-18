// lib/features/jobs/presentation/screens/show_jobs_screen.dart
// ✅ COMPACT CARD REDESIGN — Everything visible at a glance, NO SCROLLING
// ✅ Each job card shows: Organization, Post Name, Last Date, Edit, Delete
// ✅ Top dashboard shows: Total, Open, Closed, Applications, Views
// ✅ Modern glassmorphism + gradient design
// ✅ All functionality preserved (cache, refresh, navigation, filter)
// ✅ NEW: Compact horizontal layout — fits 4-5 jobs per screen height
// ✅ FIXED: Edit button now properly extracts and normalizes _id
// ✅ FIXED: Editing job data is normalized before passing to AddJobScreen

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/job_detail_screen.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/add_job_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ===============================================================
// AI SERVICE
// ===============================================================
class AdminJobAIService {
  static double calculateEngagementScore(Map<String, dynamic> job) {
    final applications = (job['applications_count'] ?? 0) as num;
    final views = (job['views_count'] ?? 0) as num;
    if (applications == 0 && views == 0) return 0;
    const maxApps = 100.0;
    const maxViews = 1000.0;
    final appScore = (applications / maxApps).clamp(0.0, 1.0) * 70;
    final viewScore = (views / maxViews).clamp(0.0, 1.0) * 30;
    return appScore + viewScore;
  }
}

// ===============================================================
// VIEW ENUM
// ===============================================================
enum _ShowJobsView { list, addJob, editJob }

// ===============================================================
// MAIN SCREEN
// ===============================================================
class ShowJobsScreen extends StatefulWidget {
  final String adminRole;
  final VoidCallback? onJobDeleted;
  final VoidCallback? onJobUpdated;

  const ShowJobsScreen({
    super.key,
    this.adminRole = 'admin',
    this.onJobDeleted,
    this.onJobUpdated,
  });

  @override
  State<ShowJobsScreen> createState() => _ShowJobsScreenState();
}

class _ShowJobsScreenState extends State<ShowJobsScreen>
    with TickerProviderStateMixin {
  List<dynamic> jobs = [];
  List<dynamic> _filteredJobs = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;

  static const String _cacheKey = 'admin_jobs_cache';
  String _filterStatus = 'all';

  _ShowJobsView _view = _ShowJobsView.list;
  Map<String, dynamic>? _editingJob;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _entranceController;

  // ============================================================
  // ✅ SAFE ID EXTRACTION HELPER
  // Handles: String, MongoDB $oid object, int, nested maps
  // ============================================================
  String? _extractId(dynamic raw) {
    if (raw == null) return null;

    // Plain string
    if (raw is String) {
      final s = raw.trim();
      return s.isEmpty ? null : s;
    }

    // MongoDB $oid object: {"$oid": "507f1f77bcf86cd799439011"}
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

    // Fallback to string
    final s = raw.toString().trim();
    return (s.isEmpty || s == 'null' || s == 'undefined') ? null : s;
  }

  // ============================================================
  // ✅ NORMALIZE JOB FOR EDIT
  // Converts MongoDB types to plain Dart types for the edit form
  // ============================================================
  Map<String, dynamic> _normalizeJobForEdit(Map<String, dynamic> job) {
    final normalized = Map<String, dynamic>.from(job);

    // ✅ Ensure _id is a plain String
    final id = _extractId(job['_id']) ?? _extractId(job['id']);
    if (id != null) {
      normalized['_id'] = id;
    }

    // ✅ Normalize multiple_posts — convert age_min/age_max to String
    final multiplePosts = normalized['multiple_posts'];
    if (multiplePosts is List) {
      normalized['multiple_posts'] = multiplePosts.map((e) {
        if (e is! Map) return e;
        final postMap = Map<String, dynamic>.from(e);

        // Convert age_min/age_max to String (AddJobScreen expects String)
        if (postMap.containsKey('age_min')) {
          final v = postMap['age_min'];
          if (v is int) {
            postMap['age_min'] = v.toString();
          } else if (v is double) {
            postMap['age_min'] = v == v.truncateToDouble()
                ? v.toInt().toString()
                : v.toString();
          } else if (v == null) {
            postMap['age_min'] = '';
          } else {
            postMap['age_min'] = v.toString().trim();
          }
        }

        if (postMap.containsKey('age_max')) {
          final v = postMap['age_max'];
          if (v is int) {
            postMap['age_max'] = v.toString();
          } else if (v is double) {
            postMap['age_max'] = v == v.truncateToDouble()
                ? v.toInt().toString()
                : v.toString();
          } else if (v == null) {
            postMap['age_max'] = '';
          } else {
            postMap['age_max'] = v.toString().trim();
          }
        }

        // Normalize pay_scales to List<Map<String, dynamic>>
        if (postMap['pay_scales'] is List) {
          postMap['pay_scales'] = (postMap['pay_scales'] as List)
              .whereType<Map>()
              .map((ps) => Map<String, dynamic>.from(ps))
              .toList();
        } else {
          postMap['pay_scales'] = [];
        }

        // Normalize category_vacancies to List<Map<String, dynamic>>
        if (postMap['category_vacancies'] is List) {
          postMap['category_vacancies'] =
              (postMap['category_vacancies'] as List)
                  .whereType<Map>()
                  .map((cv) => Map<String, dynamic>.from(cv))
                  .toList();
        } else {
          postMap['category_vacancies'] = [];
        }

        return postMap;
      }).toList();
    } else {
      normalized['multiple_posts'] = [];
    }

    // ✅ Normalize job_location map
    if (normalized['job_location'] is Map) {
      normalized['job_location'] =
          Map<String, dynamic>.from(normalized['job_location'] as Map);
    }

    // ✅ Normalize application_fees map
    if (normalized['application_fees'] is Map) {
      normalized['application_fees'] = Map<String, dynamic>.from(
          normalized['application_fees'] as Map);
    }

    // ✅ Normalize age_relaxation_by_category map
    if (normalized['age_relaxation_by_category'] is Map) {
      normalized['age_relaxation_by_category'] =
          Map<String, dynamic>.from(
              normalized['age_relaxation_by_category'] as Map);
    }

    // ✅ Normalize physical_eligibility map
    if (normalized['physical_eligibility'] is Map) {
      normalized['physical_eligibility'] = Map<String, dynamic>.from(
          normalized['physical_eligibility'] as Map);
    }

    // ✅ Normalize training_details map
    if (normalized['training_details'] is Map) {
      normalized['training_details'] = Map<String, dynamic>.from(
          normalized['training_details'] as Map);
    }

    // ✅ Ensure lists are actual lists
    if (normalized['benefits'] is! List) {
      normalized['benefits'] = [];
    }
    if (normalized['languages_required'] is! List) {
      normalized['languages_required'] = [];
    }
    if (normalized['exam_cities'] is! List) {
      normalized['exam_cities'] = [];
    }
    if (normalized['interview_documents'] is! List) {
      normalized['interview_documents'] = [];
    }
    if (normalized['selection_stages'] is! List) {
      normalized['selection_stages'] = [];
    }
    if (normalized['required_skills'] is! List) {
      normalized['required_skills'] = [];
    }

    return normalized;
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _loadCachedJobs();
    _fetchJobs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  // ================= CACHING =================
  Future<void> _loadCachedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final List<dynamic> cachedJobs = jsonDecode(cached);
        if (cachedJobs.isNotEmpty) {
          setState(() {
            jobs = cachedJobs;
            _applyFilters();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _saveJobsToCache(List<dynamic> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(jobs));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  // ================= API =================
  String _getApiEndpoint() {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs';
      case 'superadmin':
        return '/superadmin/jobs';
      default:
        return '/admin/jobs';
    }
  }

  String _getDeleteEndpoint(String jobId) {
    switch (widget.adminRole.toLowerCase()) {
      case 'customadmin':
        return '/customadmin/jobs/$jobId';
      case 'superadmin':
        return '/superadmin/jobs/$jobId';
      default:
        return '/admin/jobs/$jobId';
    }
  }

  Future<void> _fetchJobs() async {
    if (!mounted) return;
    setState(() {
      isRefreshing = true;
      errorMessage = null;
    });

    try {
      final response = await DioClient.dio.get(_getApiEndpoint());
      if (!mounted) return;

      dynamic jobsData = [];
      if (response.data is Map) {
        if (response.data.containsKey('data') && response.data['data'] is Map) {
          jobsData = response.data['data']['jobs'] ?? [];
        } else if (response.data.containsKey('jobs')) {
          jobsData = response.data['jobs'] ?? [];
        } else {
          jobsData = response.data['data'] ?? [];
        }
      } else {
        jobsData = response.data ?? [];
      }

      setState(() {
        jobs = jobsData is List ? jobsData : [];
        _applyFilters();
      });

      if (jobs.isNotEmpty) await _saveJobsToCache(jobs);
      _entranceController..reset()..forward();
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = e.toString());
        if (jobs.isEmpty) {
          showMessage(context, "Failed to load jobs: $e", isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  // ================= FILTERS =================
  void _applyFilters() {
    List<dynamic> filtered = List.from(jobs);
    if (_filterStatus != 'all') {
      filtered = filtered.where((job) => job['status'] == _filterStatus).toList();
    }
    setState(() => _filteredJobs = filtered);
  }

  int _countByStatus(String status) {
    if (status == 'all') return jobs.length;
    return jobs.where((j) => j['status'] == status).length;
  }

  // ================= DELETE =================
  Future<void> _deleteJob(String jobId, String jobTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Job"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete \"$jobTitle\"?\n\nAll associated applications will also be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DioClient.dio.delete(_getDeleteEndpoint(jobId));
      if (!mounted) return;
      showMessage(context, "Job deleted successfully");
      await _fetchJobs();
      widget.onJobDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, "Failed to delete job: $e", isError: true);
    }
  }

  // ================= NAVIGATION =================
  void _onJobTap(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
    ).then((_) => _fetchJobs());
  }

  void _openAddJobView() {
    setState(() {
      _view = _ShowJobsView.addJob;
      _editingJob = null;
    });
  }

  // ============================================================
  // ✅ FIXED: _openEditJobView
  // - Extracts _id safely (handles $oid, String, int)
  // - Normalizes job data structure for AddJobScreen
  // - Logs debug info
  // ============================================================
  void _openEditJobView(Map<String, dynamic> job) {
    debugPrint("=" * 70);
    debugPrint("📝 OPENING EDIT VIEW");
    debugPrint("   Job keys: ${job.keys.toList()}");
    debugPrint("   _id raw: ${job['_id']} (type: ${job['_id'].runtimeType})");

    // ✅ Extract _id safely
    final rawId = job['_id'] ?? job['id'];
    final extractedId = _extractId(rawId);

    debugPrint("   Extracted ID: $extractedId");

    if (extractedId == null || extractedId.isEmpty) {
      debugPrint("❌ Cannot edit: missing or invalid _id");
      if (mounted) {
        showMessage(
          context,
          "❌ Cannot edit: Job ID is missing. Please refresh the list.",
          isError: true,
        );
      }
      return;
    }

    // ✅ Normalize the job data for AddJobScreen
    final normalizedJob = _normalizeJobForEdit(job);

    debugPrint("   Normalized _id: ${normalizedJob['_id']}");
    debugPrint("   Normalized keys: ${normalizedJob.keys.toList()}");
    debugPrint("=" * 70);

    setState(() {
      _view = _ShowJobsView.editJob;
      _editingJob = normalizedJob;
    });
  }

  void _closeAddJobView() {
    setState(() {
      _view = _ShowJobsView.list;
      _editingJob = null;
    });
    _fetchJobs();
    widget.onJobUpdated?.call();
  }

  void _closeEditJobView() {
    setState(() {
      _view = _ShowJobsView.list;
      _editingJob = null;
    });
    _fetchJobs();
    widget.onJobUpdated?.call();
  }

  // ================= HELPERS =================
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getJobTypeColor(String? type) {
    switch (type) {
      case 'private':
        return const Color(0xFF3B82F6);
      case 'remote':
        return const Color(0xFF8B5CF6);
      case 'government':
        return const Color(0xFF10B981);
      case 'hybrid':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
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

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    if (_view == _ShowJobsView.addJob) {
      return Column(
        children: [
          _buildInlineHeader(
            title: "Add New Job",
            subtitle: "Fill all 8 tabs and publish",
            onBack: _closeAddJobView,
            icon: Icons.add_circle_outline,
          ),
          Expanded(
            child: AddJobScreen(
              adminRole: widget.adminRole,
              onJobAdded: () => widget.onJobUpdated?.call(),
            ),
          ),
        ],
      );
    }

    if (_view == _ShowJobsView.editJob && _editingJob != null) {
      return Column(
        children: [
          _buildInlineHeader(
            title: "Edit Job",
            subtitle: _editingJob!['post_name'] ?? "Update job details",
            onBack: _closeEditJobView,
            icon: Icons.edit,
          ),
          Expanded(
            child: AddJobScreen(
              adminRole: widget.adminRole,
              editingJob: _editingJob,
              isEditMode: true,
              onJobAdded: () => widget.onJobUpdated?.call(),
              onJobUpdated: () {
                _closeEditJobView();
              },
            ),
          ),
        ],
      );
    }

    if (isLoading && jobs.isEmpty) return _buildLoadingScreen();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildGradientBackground(),
        child: Column(
          children: [
            _buildCompactDashboard(),
            _buildCompactFilterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ============================================================
  // ✅ COMPACT DASHBOARD — ALL stats in ONE row, fits without scroll
  // ============================================================
  Widget _buildCompactDashboard() {
    final total = jobs.length;
    final open = _countByStatus('open');
    final closed = _countByStatus('closed');
    final totalApps =
        jobs.fold<int>(0, (sum, j) => sum + ((j['applications_count'] ?? 0) as int));
    final totalViews =
        jobs.fold<int>(0, (sum, j) => sum + ((j['views_count'] ?? 0) as int));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCompactStat("Total", "$total", Icons.work_rounded),
          _buildDivider(),
          _buildCompactStat("Open", "$open", Icons.check_circle_rounded),
          _buildDivider(),
          _buildCompactStat("Closed", "$closed", Icons.cancel_rounded),
          _buildDivider(),
          _buildCompactStat("Apps", "$totalApps", Icons.assignment_rounded),
          _buildDivider(),
          _buildCompactStat("Views", "$totalViews", Icons.visibility_rounded),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withOpacity(0.20),
    );
  }

  // ============================================================
  // ✅ COMPACT FILTER BAR — single row, small pills
  // ============================================================
  Widget _buildCompactFilterBar() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterPill(
                  label: 'All',
                  count: _countByStatus('all'),
                  value: 'all',
                  color: const Color(0xFF6C63FF),
                  icon: Icons.apps_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  label: 'Open',
                  count: _countByStatus('open'),
                  value: 'open',
                  color: const Color(0xFF10B981),
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  label: 'Closed',
                  count: _countByStatus('closed'),
                  value: 'closed',
                  color: const Color(0xFFEF4444),
                  icon: Icons.cancel_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required int count,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _filterStatus == value;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _filterStatus = value;
            _applyFilters();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: isSelected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= BODY =================
  Widget _buildBody() {
    if (errorMessage != null && jobs.isEmpty) return _buildErrorState();
    if (_filteredJobs.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _fetchJobs,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
        itemCount: _filteredJobs.length,
        itemBuilder: (context, index) {
          final double start = (index * 0.04).clamp(0.0, 0.5);
          final curved = CurvedAnimation(
            parent: _entranceController,
            curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: _buildCompactJobCard(_filteredJobs[index], index),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ✅ COMPACT JOB CARD
  // ============================================================
  Widget _buildCompactJobCard(Map<String, dynamic> job, int index) {
    // SAFE EXTRACTION
    final rawOrg = (job['organization'] ?? job['company'] ?? '').toString().trim();
    final organization = rawOrg.isEmpty ? 'Unknown Organization' : rawOrg;

    final rawTitle = job['post_name']?.toString().trim() ?? '';
    final jobTitle = rawTitle.isEmpty ? 'Untitled Post' : rawTitle;

    final jobType = job['job_type'] ?? 'private';
    final typeColor = _getJobTypeColor(jobType);
    final status = job['status'] ?? 'open';
    final lastDate = _formatDate(
      job['last_date'] ?? job['application_end_date'] ?? job['deadline'],
    );
    final applicationsCount = (job['applications_count'] ?? 0) as int;
    final viewsCount = (job['views_count'] ?? 0) as int;

    final engagementScore = AdminJobAIService.calculateEngagementScore(job);
    final bool isHighEngagement = engagementScore >= 50;
    final bool isExpired = _isExpired(job['last_date'] ?? job['application_end_date']);

    // Colors
    const Color orgPrimary = Color(0xFF0EA5E9);
    const Color orgSecondary = Color(0xFF06B6D4);
    const Color titlePrimary = Color(0xFF6C63FF);
    const Color titleSecondary = Color(0xFF8B7FFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighEngagement
              ? const Color(0xFF6C63FF).withOpacity(0.25)
              : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighEngagement
                ? const Color(0xFF6C63FF).withOpacity(0.10)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onJobTap(job),
          splashColor: const Color(0xFF6C63FF).withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =====================================================
                // ROW 1: Status + Type + AI + Menu
                // =====================================================
                Row(
                  children: [
                    _buildMiniStatusPill(status),
                    const SizedBox(width: 6),
                    _buildMiniTypePill(jobType, typeColor),
                    if (isExpired) ...[
                      const SizedBox(width: 6),
                      _buildExpiredPill(),
                    ],
                    const Spacer(),
                    if (isHighEngagement)
                      _buildMiniAIRing(engagementScore, size: 32),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: const [
                              Icon(Icons.visibility_outlined,
                                  size: 18, color: Color(0xFF0EA5E9)),
                              SizedBox(width: 10),
                              Text("View"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: const [
                              Icon(Icons.edit_outlined,
                                  size: 18, color: Color(0xFF6C63FF)),
                              SizedBox(width: 10),
                              Text("Edit"),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text("Delete"),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'view') {
                          _onJobTap(job);
                        } else if (value == 'edit') {
                          _openEditJobView(job);
                        } else if (value == 'delete') {
                          final id = _extractId(job['_id']) ?? _extractId(job['id']);
                          if (id == null || id.isEmpty) {
                            showMessage(context,
                                "❌ Cannot delete: Job ID is missing.",
                                isError: true);
                            return;
                          }
                          _deleteJob(id, jobTitle);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ORGANIZATION BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        orgPrimary.withOpacity(0.12),
                        orgSecondary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: orgPrimary.withOpacity(0.35),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [orgPrimary, orgSecondary],
                          ),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: orgPrimary.withOpacity(0.30),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ORGANIZATION",
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: orgPrimary.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              organization,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 7),

                // POST NAME BOX
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        titlePrimary.withOpacity(0.10),
                        titleSecondary.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: titlePrimary.withOpacity(0.30),
                      width: 1.3,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [titlePrimary, titleSecondary],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: titlePrimary.withOpacity(0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.work_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "POST NAME",
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: titlePrimary.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              jobTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ROW 4: Chips
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactChip(
                        icon: Icons.event_rounded,
                        label: "Last Date",
                        value: lastDate,
                        color: isExpired
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactChip(
                        icon: Icons.assignment_rounded,
                        label: "Apps",
                        value: "$applicationsCount",
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildCompactChip(
                        icon: Icons.visibility_rounded,
                        label: "Views",
                        value: "$viewsCount",
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ROW 5: Edit + Delete buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => _openEditJobView(job),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text(
                            "Edit",
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C63FF),
                            side: const BorderSide(
                                color: Color(0xFF6C63FF), width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final id = _extractId(job['_id']) ?? _extractId(job['id']);
                            if (id == null || id.isEmpty) {
                              showMessage(context,
                                  "❌ Cannot delete: Job ID is missing.",
                                  isError: true);
                              return;
                            }
                            _deleteJob(id, jobTitle);
                          },
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text(
                            "Delete",
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(
                                color: Color(0xFFEF4444), width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatusPill(String status) {
    final bool isOpen = status == 'open';
    final color = isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTypePill(String jobType, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        jobType.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildExpiredPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: const Text(
        "EXPIRED",
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFFEF4444),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMiniAIRing(double score, {double size = 32}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 2.5,
              backgroundColor: const Color(0xFF6C63FF).withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6C63FF),
              ),
            ),
          ),
          Text(
            "${score.round()}",
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.85),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isExpired(String? lastDate) {
    if (lastDate == null || lastDate.isEmpty) return false;
    try {
      final date = DateTime.parse(lastDate);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // ================= INLINE HEADER =================
  Widget _buildInlineHeader({
    required String title,
    required String subtitle,
    required VoidCallback onBack,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFF6C63FF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        size: 16, color: Color(0xFF6C63FF)),
                    SizedBox(width: 4),
                    Text(
                      "Back",
                      style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= LOADING SCREEN =================
  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome,
                        color: Colors.white, size: 44),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "AI is loading your jobs...",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= APP BAR =================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'My Jobs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _openAddJobView,
          tooltip: 'Add Job',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchJobs,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ================= FAB =================
  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _openAddJobView,
        icon: const Icon(Icons.add),
        label: const Text(
          "Add Job",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  // ================= ERROR STATE =================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.red.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load jobs',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchJobs,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.work_off_outlined,
                  size: 48, color: Color(0xFF6C63FF)),
              const SizedBox(height: 16),
              const Text(
                'No jobs found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filterStatus != 'all'
                    ? 'Try changing the filter'
                    : 'Click "Add Job" to create your first posting',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openAddJobView,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}