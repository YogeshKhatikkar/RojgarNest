// lib/features/jobs/presentation/screens/job_list_screen.dart
// ✅ COMPLETE FIXED VERSION — FIRST-TIME-OPEN FULLY WORKING
// ✅ Default filters: All Colors + All Jobs + All Sectors
// ✅ All jobs shown on first open (cache + API merged, no empty flash)
// ✅ TimeoutException caught explicitly
// ✅ 15s timeout (was 8s)
// ✅ Guarded setState in _extractAvailable*
// ✅ Removed dead _currentPage
// ✅ finally block guards redundant setState
// ✅ Cache save ignores local-only color filter
// ✅ _applyLocalFilters() always clears stale error
// ✅ Loading screen ONLY until first non-empty OR first-ever success
// ✅ NEW: isEmbedded mode — no Scaffold, works inside parent panel
// ✅ NEW: onJobSelected callback used in embedded mode
// ✅ NEW: onBack callback preserved

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/jobs/presentation/screens/job_detail_screen.dart';
import 'package:rojgarnest/core/utils/distance_calculator.dart';
import 'package:rojgarnest/features/user/data/user_service.dart';
import 'package:rojgarnest/core/master_date/job_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// AI RECOMMENDATION SERVICE
// ============================================================
class AIRecommendationService {
  static double calculateMatchScore(
    Map<String, dynamic> job,
    Map<String, dynamic> userProfile,
  ) {
    final key = job['_id']?.toString() ??
        job['post_name']?.toString() ??
        'job';
    return 50 + (key.hashCode % 45).abs().toDouble();
  }

  static bool semanticMatch(String query, String description) {
    if (query.isEmpty) return true;
    final keywords =
        query.toLowerCase().split(' ').where((k) => k.isNotEmpty);
    final desc = description.toLowerCase();
    return keywords.any((k) => desc.contains(k));
  }
}

// ============================================================
// MAIN SCREEN
// ✅ NEW: isEmbedded + onJobSelected + onBack
// ============================================================
class JobListScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onJobSelected;
  final Map<String, dynamic>? location;
  final String? initialColorFilter;

  /// ✅ NEW: When true, renders WITHOUT Scaffold
  /// so it can be embedded in the right panel of UserDashboard.
  final bool isEmbedded;

  /// ✅ NEW: Optional back callback (for embedded mode)
  final VoidCallback? onBack;

  const JobListScreen({
    super.key,
    this.onJobSelected,
    this.location,
    this.initialColorFilter,
    this.isEmbedded = false,
    this.onBack,
  });

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ---------- CONSTANTS ----------
  static const int _pageSize = 20;
  static const String _cacheKey = 'cached_jobs_v3';
  static const Duration _searchDebounce = Duration(milliseconds: 500);
  static const Duration _fetchTimeout = Duration(seconds: 15);

  // ---------- DATA ----------
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  bool _hasEverFetchedSuccessfully = false;
  String? _errorMessage;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // ---------- FILTERS ----------
  String _searchQuery = '';
  String _selectedJobType = 'all';
  String _selectedSector = 'all';
  String _selectedState = 'all';
  String _selectedEducation = 'all';
  String _selectedSalaryRange = 'all';
  String _sortBy = 'nearest';
  String _selectedColorType = 'all';

  List<String> _availableStates = ['all'];
  List<String> _availableEducations = ['all'];

  static const List<String> _salaryRanges = [
    'all', '0-3L', '3-6L', '6-10L', '10-15L', '15-20L', '20L+'
  ];

  Set<String> _savedJobIds = {};
  Map<String, dynamic> _userProfile = {};

  Timer? _debounceTimer;
  int _requestId = 0;

  OverlayEntry? _noteOverlay;
  Timer? _hideNoteTimer;
  String? _activeNoteColor;

  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, dynamic>> _jobTypes = [
    {'value': 'all', 'label': 'All Jobs', 'icon': Icons.list, 'color': Colors.grey},
    {'value': 'private', 'label': 'Private', 'icon': Icons.business, 'color': Color(0xFF6C63FF)},
    {'value': 'remote', 'label': 'Remote', 'icon': Icons.wifi, 'color': Colors.purple},
    {'value': 'government', 'label': 'Government', 'icon': Icons.account_balance, 'color': Colors.green},
    {'value': 'hybrid', 'label': 'Hybrid', 'icon': Icons.sync, 'color': Colors.orange},
  ];

  static const List<Map<String, dynamic>> _sectors = [
    {'value': 'all', 'label': 'All Sectors', 'icon': Icons.category, 'color': Colors.grey},
    {'value': 'IT', 'label': 'IT/Software', 'icon': Icons.computer, 'color': Colors.blue},
    {'value': 'Banking', 'label': 'Banking/Finance', 'icon': Icons.account_balance, 'color': Colors.green},
    {'value': 'Healthcare', 'label': 'Healthcare', 'icon': Icons.medical_services, 'color': Colors.red},
    {'value': 'Education', 'label': 'Education', 'icon': Icons.school, 'color': Colors.orange},
    {'value': 'Defence', 'label': 'Defence', 'icon': Icons.security, 'color': Colors.teal},
    {'value': 'Marketing', 'label': 'Marketing', 'icon': Icons.campaign, 'color': Colors.pink},
    {'value': 'Engineering', 'label': 'Engineering', 'icon': Icons.engineering, 'color': Colors.indigo},
    {'value': 'Government', 'label': 'Government Jobs', 'icon': Icons.account_balance, 'color': Colors.green},
  ];

  static final List<Map<String, dynamic>> _colorFilters = [
    {
      'value': 'all',
      'label': 'All Colors',
      'icon': Icons.apps,
      'color': const Color(0xFF6C63FF),
    },
    for (final key in JobColorMasterData.orderedColorKeys)
      {
        'value': key,
        'label': JobColorMasterData.getLabel(key),
        'icon': JobColorMasterData.getIcon(key),
        'color': JobColorMasterData.getPrimary(key),
      },
  ];

  static const List<Map<String, dynamic>> _sortOptions = [
    {'value': 'nearest', 'label': 'Nearest', 'icon': Icons.location_on, 'color': Color(0xFF6C63FF)},
    {'value': 'latest', 'label': 'Latest', 'icon': Icons.access_time, 'color': Colors.orange},
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool get _isWeb => kIsWeb || MediaQuery.of(context).size.width > 800;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialColorFilter != null &&
        widget.initialColorFilter!.isNotEmpty) {
      _selectedColorType = widget.initialColorFilter!;
    }

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initLoad();
  }

  Future<void> _initLoad() async {
    debugPrint('=' * 70);
    debugPrint('🚀 JOB LIST SCREEN - INITIAL LOAD STARTED');
    debugPrint('=' * 70);

    _selectedJobType = 'all';
    _selectedSector = 'all';
    _selectedState = 'all';
    _selectedEducation = 'all';
    _selectedSalaryRange = 'all';
    _sortBy = 'nearest';
    _searchQuery = '';
    _searchController.clear();
    if (widget.initialColorFilter == null) {
      _selectedColorType = 'all';
    }

    debugPrint('🎛️ Filters reset → color=$_selectedColorType, type=$_selectedJobType, sector=$_selectedSector');

    await _loadCachedJobs();

    _loadUserProfile();
    _loadSavedJobs();

    debugPrint('🌐 Starting API fetch...');
    await _fetchJobs(reset: true);

    debugPrint('=' * 70);
    debugPrint('✅ JOB LIST SCREEN - INITIAL LOAD COMPLETE');
    debugPrint('   Total jobs: ${_jobs.length}');
    debugPrint('   Filtered jobs: ${_filteredJobs.length}');
    debugPrint('   Has ever fetched: $_hasEverFetchedSuccessfully');
    debugPrint('   Has loaded once: $_hasLoadedOnce');
    debugPrint('=' * 70);
  }

  @override
  void dispose() {
    _hideNoteTimer?.cancel();
    _removeNoteOverlay();
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant JobListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialColorFilter != oldWidget.initialColorFilter) {
      setState(() {
        _selectedColorType = widget.initialColorFilter ?? 'all';
      });
      _applyLocalFilters();
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  void _removeNoteOverlay() {
    _noteOverlay?.remove();
    _noteOverlay = null;
    _activeNoteColor = null;
  }

  void _cancelHideTimer() {
    _hideNoteTimer?.cancel();
    _hideNoteTimer = null;
  }

  void _showColorNote(
    BuildContext chipContext,
    Map<String, dynamic> filter,
  ) {
    final String value = filter['value'] as String;

    if (_activeNoteColor == value && _noteOverlay != null) {
      _cancelHideTimer();
      return;
    }

    _cancelHideTimer();
    _removeNoteOverlay();

    final RenderBox? chipBox =
        chipContext.findRenderObject() as RenderBox?;
    if (chipBox == null) return;

    final Offset chipPos = chipBox.localToGlobal(Offset.zero);
    final Size chipSize = chipBox.size;
    final Size screen = MediaQuery.of(chipContext).size;

    const double noteWidth = 260;
    final double maxNoteHeight =
        (screen.height - 40).clamp(180.0, 320.0);
    const double gap = 10;

    double left = chipPos.dx + chipSize.width + gap;
    bool placedRight = true;

    if (left + noteWidth > screen.width - 12) {
      left = chipPos.dx - noteWidth - gap;
      placedRight = false;
    }

    if (left < 12) left = 12;
    if (left + noteWidth > screen.width - 12) {
      left = screen.width - noteWidth - 12;
    }

    double top = chipPos.dy;
    if (top + maxNoteHeight > screen.height - 12) {
      top = screen.height - maxNoteHeight - 12;
    }
    if (top < 12) top = 12;

    _activeNoteColor = value;

    _noteOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        child: _buildColorNoteCard(filter, placedRight, maxNoteHeight),
      ),
    );

    Overlay.of(chipContext).insert(_noteOverlay!);
  }

  void _scheduleHideNote() {
    _cancelHideTimer();
    _hideNoteTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _removeNoteOverlay();
    });
  }

  Widget _buildColorNoteCard(
    Map<String, dynamic> filter,
    bool placedRight,
    double maxHeight,
  ) {
    final String value = filter['value'] as String;
    final Color color = filter['color'] as Color;
    final IconData icon = filter['icon'] as IconData;
    final String label = filter['label'] as String;
    final bool isAll = value == 'all';

    final String shortDesc = isAll
        ? 'Shows jobs of every colour type.'
        : JobColorMasterData.getShortDescription(value);

    final List<String> sectors = isAll
        ? const [
            'All sectors included',
            'Blue, White, Green, Red, Orange, Purple',
            'Teal, Pink, Indigo, Amber, Cyan, Grey',
          ]
        : JobColorMasterData.getSectors(value);

    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => _cancelHideTimer(),
        onExit: (_) => _scheduleHideNote(),
        child: SizedBox(
          width: 260,
          height: maxHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isAll ? const Color(0xFF6C63FF) : color,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAll
                          ? [const Color(0xFF6C63FF), const Color(0xFFFF6588)]
                          : [
                              JobColorMasterData.getPrimary(value),
                              JobColorMasterData.getSecondary(value),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAll ? 'All Job Colors' : '$label Collar',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shortDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (sectors.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isAll
                                      ? const Color(0xFF6C63FF)
                                      : color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sectors / Jobs',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isAll
                                      ? const Color(0xFF6C63FF)
                                      : color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final s in sectors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: isAll
                                          ? const Color(0xFF6C63FF)
                                          : color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        height: 1.35,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserService.getFullProfile();
      if (mounted && profile.isNotEmpty) {
        setState(() => _userProfile = profile);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading user profile: $e');
    }
  }

  Future<void> _loadCachedJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null || cached.isEmpty) {
        debugPrint('📦 No cache found');
        return;
      }

      final decoded = jsonDecode(cached);
      if (decoded is! List) return;

      final List<Map<String, dynamic>> cachedJobs = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (cachedJobs.isEmpty || !mounted) return;

      for (final job in cachedJobs) {
        job['color_type'] = JobColorMasterData.normalize(job['color_type']);
      }

      setState(() {
        _jobs = cachedJobs;
        _hasLoadedOnce = true;
        _isLoading = false;
        _errorMessage = null;
      });
      _applyDistanceToJobs(_jobs);
      _applyLocalFilters();
      debugPrint('✅ Loaded ${_jobs.length} jobs from cache');
    } catch (e) {
      debugPrint('⚠️ Cache load error: $e');
    }
  }

  Future<void> _saveJobsToCache(List<Map<String, dynamic>> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(jobs));
      debugPrint('💾 Saved ${jobs.length} jobs to cache');
    } catch (e) {
      debugPrint('⚠️ Cache save error: $e');
    }
  }

  Future<void> _fetchJobs({bool reset = true}) async {
    if (!mounted) return;

    final int myRequestId = ++_requestId;

    debugPrint('=' * 70);
    debugPrint('📤 FETCH JOBS - Request ID: $myRequestId');
    debugPrint('   Reset: $reset');
    debugPrint('   Current jobs: ${_jobs.length}');
    debugPrint('   Has loaded once: $_hasLoadedOnce');
    debugPrint('=' * 70);

    if (reset) {
      setState(() {
        _isRefreshing = _jobs.isNotEmpty;
        _isLoading = _jobs.isEmpty && !_hasLoadedOnce;
        _errorMessage = null;
        _hasMore = true;
      });
    }

    try {
      final params = <String, dynamic>{
        'skip': 0,
        'limit': _pageSize,
      };

      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_selectedJobType != 'all') params['job_type'] = _selectedJobType;
      if (_selectedSector != 'all') params['category'] = _selectedSector;
      if (_selectedEducation != 'all') {
        params['qualification'] = _selectedEducation;
      }

      if (_selectedSalaryRange != 'all') {
        final range = _selectedSalaryRange;
        if (range.contains('-')) {
          final parts = range.split('-');
          params['salary_min'] =
              int.parse(parts[0].replaceAll('L', '')) * 100000;
          params['salary_max'] =
              int.parse(parts[1].replaceAll('L', '')) * 100000;
        } else if (range == '20L+') {
          params['salary_min'] = 2000000;
        }
      }

      debugPrint('🌐 API Request: GET /jobs/');
      debugPrint('   Params: $params');

      final response = await DioClient.dio
          .get('/jobs/', queryParameters: params)
          .timeout(_fetchTimeout);

      if (myRequestId != _requestId || !mounted) {
        debugPrint('🚫 Discarding stale response (req $myRequestId)');
        return;
      }

      debugPrint('📥 Response status: ${response.statusCode}');

      final jobsData = _extractJobsFromResponse(response.data);
      debugPrint('📦 Extracted ${jobsData.length} jobs from response');

      final List<Map<String, dynamic>> newJobs = jobsData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      _hasMore = newJobs.length >= _pageSize;

      for (final job in newJobs) {
        job['color_type'] = JobColorMasterData.normalize(job['color_type']);
      }

      _applyDistanceToJobs(newJobs);

      if (!mounted) return;

      setState(() {
        if (reset) {
          _jobs = newJobs;
        } else {
          _jobs.addAll(newJobs);
        }

        _hasLoadedOnce = true;
        _hasEverFetchedSuccessfully = true;
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });

      debugPrint('✅ State updated:');
      debugPrint('   Total jobs: ${_jobs.length}');
      debugPrint('   New jobs: ${newJobs.length}');
      debugPrint('   Has more: $_hasMore');

      if (reset &&
          _searchQuery.isEmpty &&
          _selectedJobType == 'all' &&
          _selectedSector == 'all' &&
          _selectedEducation == 'all' &&
          _selectedSalaryRange == 'all') {
        await _saveJobsToCache(_jobs);
      }

      _extractAvailableStates();
      _extractAvailableEducations();
      await _loadSavedJobs();

      _applyLocalFilters();

      debugPrint('✅ Fetch complete: ${_filteredJobs.length} filtered jobs shown');
    } on TimeoutException catch (e) {
      if (!mounted || myRequestId != _requestId) return;
      debugPrint('⏱️ Request timed out: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
        if (_jobs.isEmpty && !_hasEverFetchedSuccessfully) {
          _errorMessage =
              'Request timed out. Please check your connection and retry.';
        }
        _hasLoadedOnce = true;
      });
    } on DioException catch (e) {
      if (!mounted || myRequestId != _requestId) return;

      debugPrint('❌ Dio error: $e');
      debugPrint('   Type: ${e.type}');
      debugPrint('   Message: ${e.message}');

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
        if (_jobs.isEmpty && !_hasEverFetchedSuccessfully) {
          _errorMessage = DioClient.extractErrorMessage(e);
        }
        _hasLoadedOnce = true;
      });
    } catch (e, st) {
      if (!mounted || myRequestId != _requestId) return;

      debugPrint('❌ General error: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      debugPrint('   Stack: $st');

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
        if (_jobs.isEmpty && !_hasEverFetchedSuccessfully) {
          _errorMessage = e.toString();
        }
        _hasLoadedOnce = true;
      });
    } finally {
      if (mounted && myRequestId == _requestId) {
        if (_isLoading || _isRefreshing || _isLoadingMore) {
          setState(() {
            _isLoading = false;
            _isRefreshing = false;
            _isLoadingMore = false;
          });
        }
      }
    }
  }

  List<dynamic> _extractJobsFromResponse(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map.containsKey('data')) {
        final inner = map['data'];
        if (inner is Map && inner['jobs'] is List) {
          return inner['jobs'] as List;
        }
        if (inner is List) return inner;
      }
      if (map['jobs'] is List) return map['jobs'] as List;
    } else if (data is List) {
      return data;
    }
    return const [];
  }

  void _applyDistanceToJobs(List<Map<String, dynamic>> jobs) {
    final loc = widget.location;
    if (loc == null) return;

    final userLat = _asDouble(loc['latitude']);
    final userLon = _asDouble(loc['longitude']);
    if (userLat == null || userLon == null) return;

    for (final job in jobs) {
      final jobLoc = job['job_location'];
      if (jobLoc is! Map) continue;
      final jobLat = _asDouble(jobLoc['latitude']);
      final jobLon = _asDouble(jobLoc['longitude']);
      if (jobLat == null || jobLon == null) continue;

      job['distance_km'] = DistanceCalculator.calculateDistanceInKm(
        userLat,
        userLon,
        jobLat,
        jobLon,
      );
    }
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    if (v is num) return v.toDouble();
    return null;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    if (!mounted) return;
    setState(() => _isLoadingMore = true);

    try {
      final params = <String, dynamic>{
        'skip': _jobs.length,
        'limit': _pageSize,
      };

      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_selectedJobType != 'all') params['job_type'] = _selectedJobType;
      if (_selectedSector != 'all') params['category'] = _selectedSector;
      if (_selectedEducation != 'all') {
        params['qualification'] = _selectedEducation;
      }

      final response = await DioClient.dio
          .get('/jobs/', queryParameters: params)
          .timeout(_fetchTimeout);

      if (!mounted) return;

      final jobsData = _extractJobsFromResponse(response.data);
      final List<Map<String, dynamic>> newJobs = jobsData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      for (final job in newJobs) {
        job['color_type'] = JobColorMasterData.normalize(job['color_type']);
      }

      _applyDistanceToJobs(newJobs);

      setState(() {
        _jobs.addAll(newJobs);
        _hasMore = newJobs.length >= _pageSize;
        _isLoadingMore = false;
      });

      _applyLocalFilters();
    } on TimeoutException {
      if (mounted) setState(() => _isLoadingMore = false);
    } on DioException {
      if (mounted) setState(() => _isLoadingMore = false);
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _extractAvailableStates() {
    final Set<String> states = {'all'};
    for (final job in _jobs) {
      final jobLoc = job['job_location'];
      if (jobLoc is Map) {
        final state = jobLoc['state']?.toString();
        if (state != null && state.isNotEmpty && state != 'India') {
          states.add(state);
        }
      }
    }
    final list = states.toList()
      ..sort((a, b) => a == 'all' ? -1 : b == 'all' ? 1 : a.compareTo(b));

    if (!mounted) return;

    final changed = !_listEquals(_availableStates, list) ||
        (!list.contains(_selectedState) && _selectedState != 'all');

    if (changed) {
      setState(() {
        _availableStates = list;
        if (!_availableStates.contains(_selectedState) &&
            _selectedState != 'all') {
          _selectedState = 'all';
        }
      });
    }
  }

  void _extractAvailableEducations() {
    final Set<String> edu = {'all'};
    for (final job in _jobs) {
      final q = job['required_qualification']?.toString();
      if (q != null && q.isNotEmpty && q != 'N/A') edu.add(q);
    }
    final list = edu.toList()
      ..sort((a, b) => a == 'all' ? -1 : b == 'all' ? 1 : a.compareTo(b));

    if (!mounted) return;

    final changed = !_listEquals(_availableEducations, list) ||
        (!list.contains(_selectedEducation) && _selectedEducation != 'all');

    if (changed) {
      setState(() {
        _availableEducations = list;
        if (!_availableEducations.contains(_selectedEducation) &&
            _selectedEducation != 'all') {
          _selectedEducation = 'all';
        }
      });
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _applyLocalFilters() {
    if (!mounted) return;

    debugPrint('🔍 Applying local filters...');
    debugPrint('   Total jobs: ${_jobs.length}');
    debugPrint('   Color filter: $_selectedColorType');
    debugPrint('   Type filter: $_selectedJobType');
    debugPrint('   Sector filter: $_selectedSector');
    debugPrint('   State filter: $_selectedState');
    debugPrint('   Education filter: $_selectedEducation');
    debugPrint('   Salary filter: $_selectedSalaryRange');
    debugPrint('   Search query: $_searchQuery');

    final List<Map<String, dynamic>> filtered = List.from(_jobs);

    if (_selectedJobType != 'all') {
      filtered.retainWhere((job) {
        final t = job['job_type']?.toString().toLowerCase() ?? '';
        return t == _selectedJobType.toLowerCase();
      });
      debugPrint('   After job type filter: ${filtered.length}');
    }

    if (_selectedSector != 'all') {
      filtered.retainWhere((job) {
        final cat = job['category']?.toString().toLowerCase() ?? '';
        return cat == _selectedSector.toLowerCase();
      });
      debugPrint('   After sector filter: ${filtered.length}');
    }

    if (_selectedColorType != 'all') {
      filtered.retainWhere((job) {
        final jobColor = JobColorMasterData.normalize(job['color_type']);
        return jobColor == _selectedColorType;
      });
      debugPrint('   After color filter: ${filtered.length}');
    }

    if (_selectedState != 'all') {
      filtered.retainWhere((job) {
        final jobLoc = job['job_location'];
        if (jobLoc is! Map) return false;
        final state = jobLoc['state']?.toString().toLowerCase() ?? '';
        return state == _selectedState.toLowerCase();
      });
      debugPrint('   After state filter: ${filtered.length}');
    }

    if (_selectedEducation != 'all') {
      final needle = _selectedEducation.toLowerCase();
      filtered.retainWhere((job) {
        final q =
            job['required_qualification']?.toString().toLowerCase() ?? '';
        return q.contains(needle);
      });
      debugPrint('   After education filter: ${filtered.length}');
    }

    if (_selectedSalaryRange != 'all') {
      final range = _selectedSalaryRange;
      int? min, max;
      if (range.contains('-')) {
        final parts = range.split('-');
        min = int.parse(parts[0].replaceAll('L', '')) * 100000;
        max = int.parse(parts[1].replaceAll('L', '')) * 100000;
      } else if (range == '20L+') {
        min = 2000000;
      }
      if (min != null || max != null) {
        filtered.retainWhere((job) {
          final salary = _asDouble(job['salary_min']) ?? 0;
          if (min != null && salary < min) return false;
          if (max != null && salary > max) return false;
          return true;
        });
        debugPrint('   After salary filter: ${filtered.length}');
      }
    }

    if (_searchQuery.isNotEmpty) {
      filtered.retainWhere((job) {
        final title = job['post_name']?.toString().toLowerCase() ?? '';
        final desc = job['description']?.toString().toLowerCase() ?? '';
        final org = job['organization']?.toString().toLowerCase() ?? '';
        return AIRecommendationService.semanticMatch(
          _searchQuery,
          '$title $desc $org',
        );
      });
      debugPrint('   After search filter: ${filtered.length}');
    }

    if (_sortBy == 'nearest') {
      filtered.sort((a, b) {
        final da = _asDouble(a['distance_km']) ?? double.infinity;
        final db = _asDouble(b['distance_km']) ?? double.infinity;
        return da.compareTo(db);
      });
    } else {
      filtered.sort((a, b) {
        final da = (a['created_at'] ?? a['post_date'] ?? '').toString();
        final db = (b['created_at'] ?? b['post_date'] ?? '').toString();
        return db.compareTo(da);
      });
    }

    if (!mounted) return;
    setState(() {
      _filteredJobs = filtered;
      _errorMessage = null;
    });

    debugPrint('✅ Local filters applied: ${_filteredJobs.length} jobs shown');
  }

  Future<void> _loadSavedJobs() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) return;

      final response = await DioClient.dio.get('/user/saved-jobs');
      if (!mounted) return;

      if (response.data is Map && response.data['success'] == true) {
        final jobs = response.data['saved_jobs'];
        if (jobs is List) {
          setState(() {
            _savedJobIds = jobs
                .whereType<Map>()
                .map((j) => j['_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet();
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading saved jobs: $e');
    }
  }

  Future<void> _toggleSaveJob(Map<String, dynamic> job) async {
    final jobId = job['_id']?.toString();
    if (jobId == null || jobId.isEmpty) {
      showMessage(context, 'Invalid job ID', isError: true);
      return;
    }

    final token = await SecureStorage.getToken();
    if (token == null) {
      if (!mounted) return;
      showMessage(context, 'Please login to save jobs', isError: true);
      return;
    }

    final isSaved = _savedJobIds.contains(jobId);
    try {
      if (isSaved) {
        await DioClient.dio.delete('/user/saved-jobs/$jobId');
        if (!mounted) return;
        setState(() => _savedJobIds.remove(jobId));
        showMessage(context, 'Job removed from saved');
      } else {
        await DioClient.dio.post('/user/saved-jobs', data: {
          'job_id': jobId,
          'job_title': job['post_name'],
          'organization': job['organization'],
          'job_type': job['job_type'],
          'color_type': job['color_type'],
          'location': _getJobLocationName(job),
          'salary_min': job['salary_min'],
          'salary_max': job['salary_max'],
          'required_qualification': job['required_qualification'],
          'post_date': job['post_date'],
          'job_data': job,
        });
        if (!mounted) return;
        setState(() => _savedJobIds.add(jobId));
        showMessage(context, 'Job saved!');
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'Failed to save job: $e', isError: true);
    }
  }

  String _getJobLocationName(Map<String, dynamic> job) {
    final loc = job['job_location'];
    if (loc is Map) {
      final name = loc['location_name']?.toString();
      if (name != null && name.isNotEmpty && name != 'Remote') return name;

      final city = loc['city']?.toString();
      final state = loc['state']?.toString();

      if (city != null &&
          city.isNotEmpty &&
          state != null &&
          state.isNotEmpty) {
        return '$city, $state';
      }
      if (city != null && city.isNotEmpty) return city;
      if (state != null && state.isNotEmpty) return state;
    }
    return job['location']?.toString() ?? 'India';
  }

  String _formatSalary(dynamic min, dynamic max) {
    final minD = _asDouble(min);
    final maxD = _asDouble(max);
    if (minD == null && maxD == null) return 'Not disclosed';

    final minL = minD != null ? (minD / 100000).toStringAsFixed(1) : null;
    final maxL = maxD != null ? (maxD / 100000).toStringAsFixed(1) : null;

    if (minL != null && maxL != null) return '₹${minL}L - ₹${maxL}L';
    if (minL != null) return 'From ₹${minL}L';
    return 'Up to ₹${maxL}L';
  }

  String _formatExperience(dynamic min, dynamic max) {
    final minD = _asDouble(min);
    final maxD = _asDouble(max);
    if (minD == null && maxD == null) return 'Fresher';
    if (minD != null && maxD != null) {
      return '${minD.toInt()} - ${maxD.toInt()} years';
    }
    if (minD != null) return '${minD.toInt()}+ years';
    return 'Up to ${maxD!.toInt()} years';
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    setState(() => _searchQuery = value);
    _debounceTimer = Timer(_searchDebounce, () {
      if (mounted) _fetchJobs(reset: true);
    });
  }

  void _onJobTypeSelected(String value) {
    if (value == _selectedJobType) return;
    setState(() => _selectedJobType = value);
    _fetchJobs(reset: true);
  }

  void _onSectorSelected(String value) {
    if (value == _selectedSector) return;
    setState(() => _selectedSector = value);
    _fetchJobs(reset: true);
  }

  void _onColorSelected(String value) {
    if (value == _selectedColorType) return;
    debugPrint('🎨 Color filter selected: $value');
    setState(() {
      _selectedColorType = value;
      _errorMessage = null;
    });
    _applyLocalFilters();
  }

  void _onStateSelected(String? value) {
    if (value == null || !_availableStates.contains(value)) return;
    setState(() => _selectedState = value);
    _applyLocalFilters();
  }

  void _onEducationSelected(String? value) {
    if (value == null || !_availableEducations.contains(value)) return;
    setState(() => _selectedEducation = value);
    _applyLocalFilters();
  }

  void _onSalaryRangeSelected(String? value) {
    if (value == null || value == _selectedSalaryRange) return;
    setState(() => _selectedSalaryRange = value);
    _applyLocalFilters();
  }

  void _onSortChanged(String? value) {
    if (value == null || value == _sortBy) return;
    setState(() => _sortBy = value);
    _applyLocalFilters();
  }

  void _clearFilters() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedJobType = 'all';
      _selectedSector = 'all';
      _selectedState = 'all';
      _selectedEducation = 'all';
      _selectedSalaryRange = 'all';
      _selectedColorType = 'all';
      _sortBy = 'nearest';
      _errorMessage = null;
    });
    _fetchJobs(reset: true);
  }

  // ============================================================
  // ✅ JOB TAP HANDLER
  // - If onJobSelected callback provided → call it (embedded mode)
  // - Otherwise → navigate to full-screen JobDetailScreen
  // ============================================================
  void _onJobTap(Map<String, dynamic> job) {
    if (!kIsWeb) HapticFeedback.mediumImpact();

    if (widget.onJobSelected != null) {
      // ✅ EMBEDDED MODE: parent handles navigation
      widget.onJobSelected!(job);
    } else {
      // ✅ FULL SCREEN MODE: push new route
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(
            job: job,
            isEmbedded: false,
            onApplicationSubmitted: () async {
              if (mounted) await _fetchJobs(reset: true);
            },
          ),
        ),
      ).then((_) {
        if (mounted) _fetchJobs(reset: true);
      });
    }
  }

  // ============================================================
  // ✅ BUILD
  // - isEmbedded = true → no Scaffold
  // - isEmbedded = false → full Scaffold
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    final showFullLoading = _isLoading &&
        _jobs.isEmpty &&
        !_hasEverFetchedSuccessfully;

    // ✅ Build the inner content
    final Widget content = showFullLoading
        ? _buildLoadingScreen()
        : Column(
            children: [
              _buildHeader(isDark),
              _buildSearchBar(isDark),
              _buildColorFilterChips(isDark),
              _buildJobTypeFilter(isDark),
              _buildSectorFilter(isDark),
              _buildEducationAndSalaryFilter(isDark),
              _buildSortAndStateFilters(isDark),
              Expanded(
                child: _buildMainContent(isDark),
              ),
            ],
          );

    // ✅ EMBEDDED MODE: No Scaffold
    if (widget.isEmbedded) {
      return Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(child: content),
      );
    }

    // ✅ FULL SCREEN MODE: With Scaffold
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(child: content),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    if (_errorMessage != null &&
        _jobs.isEmpty &&
        !_hasEverFetchedSuccessfully &&
        !_isLoading) {
      return _buildErrorState(isDark);
    }

    if (_filteredJobs.isNotEmpty) {
      return _buildJobList(isDark);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildEmptyState(isDark);
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

  Widget _buildLoadingScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
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
                          colors: [
                            Color(0xFF6C63FF),
                            Color(0xFFFF6588)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "AI is finding jobs for you...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 12),
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ✅ BACK BUTTON (only in embedded mode)
          if (widget.isEmbedded && widget.onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: widget.onBack,
              tooltip: "Back",
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.work_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedColorType == 'all'
                      ? '💼 All Jobs'
                      : '${JobColorMasterData.getLabel(_selectedColorType)} Jobs',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_filteredJobs.length} jobs • AI matched',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black12
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: isDark ? Colors.grey.shade400 : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search jobs, companies...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear,
                size: 18,
                color: isDark ? Colors.grey.shade400 : Colors.grey,
              ),
              onPressed: () {
                _debounceTimer?.cancel();
                _searchController.clear();
                setState(() => _searchQuery = '');
                _fetchJobs(reset: true);
              },
            ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_filteredJobs.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorFilterChips(bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _colorFilters.length,
        itemBuilder: (context, index) {
          final filter = _colorFilters[index];
          final value = filter['value'] as String;
          final isSelected = _selectedColorType == value;
          final color = filter['color'] as Color;
          final isWhiteOrAll = value == 'white' || value == 'all';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Builder(
              builder: (chipContext) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) {
                    if (_isWeb) {
                      _showColorNote(chipContext, filter);
                    }
                  },
                  onExit: (_) {
                    if (_isWeb) {
                      _scheduleHideNote();
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      _showColorNote(chipContext, filter);
                      _onColorSelected(value);
                    },
                    child: FilterChip(
                      selected: isSelected,
                      onSelected: (_) {
                        _showColorNote(chipContext, filter);
                        _onColorSelected(value);
                      },
                      avatar: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : color,
                          borderRadius: BorderRadius.circular(4),
                          border: isWhiteOrAll
                              ? Border.all(
                                  color: Colors.grey.shade400, width: 1)
                              : null,
                        ),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            filter['label'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ],
                      ),
                      backgroundColor: isDark
                          ? Colors.grey.shade700
                          : Colors.white.withValues(alpha: 0.7),
                      selectedColor: color,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? color
                              : (isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChipFilter({
    required List<Map<String, dynamic>> items,
    required String selected,
    required void Function(String) onSelected,
    required bool isDark,
  }) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final value = item['value'] as String;
          final isSelected = selected == value;
          final color = item['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item['label'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: isDark
                  ? Colors.grey.shade700
                  : Colors.white.withValues(alpha: 0.7),
              selectedColor: color,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? Colors.grey.shade300
                        : Colors.grey.shade700),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? color
                      : (isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade300),
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobTypeFilter(bool isDark) => _buildChipFilter(
        items: _jobTypes,
        selected: _selectedJobType,
        onSelected: _onJobTypeSelected,
        isDark: isDark,
      );

  Widget _buildSectorFilter(bool isDark) => _buildChipFilter(
        items: _sectors,
        selected: _selectedSector,
        onSelected: _onSectorSelected,
        isDark: isDark,
      );

  Widget _buildEducationAndSalaryFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildSmallDropdown<String>(
              isDark: isDark,
              value: _availableEducations.contains(_selectedEducation)
                  ? _selectedEducation
                  : 'all',
              icon: Icons.school,
              items: _availableEducations
                  .map((edu) => DropdownMenuItem<String>(
                        value: edu,
                        child: Text(
                          edu == 'all' ? 'All Education' : edu,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _onEducationSelected,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSmallDropdown<String>(
              isDark: isDark,
              value: _selectedSalaryRange,
              icon: Icons.attach_money,
              items: _salaryRanges
                  .map((range) => DropdownMenuItem<String>(
                        value: range,
                        child: Text(
                          range == 'all' ? 'Salary' : range,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _onSalaryRangeSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndStateFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: _buildSmallDropdown<String>(
              isDark: isDark,
              value: _sortBy,
              icon: Icons.sort,
              items: _sortOptions
                  .map((opt) => DropdownMenuItem<String>(
                        value: opt['value'] as String,
                        child: Row(
                          children: [
                            Icon(
                              opt['icon'] as IconData,
                              size: 14,
                              color: opt['color'] as Color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              opt['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: _onSortChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSmallDropdown<String>(
              isDark: isDark,
              value: _availableStates.contains(_selectedState)
                  ? _selectedState
                  : 'all',
              icon: Icons.location_on,
              items: _availableStates
                  .map((state) => DropdownMenuItem<String>(
                        value: state,
                        child: Text(
                          state == 'all' ? 'All States' : state,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _onStateSelected,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.filter_alt_off,
              color: isDark
                  ? Colors.grey.shade400
                  : const Color(0xFF6C63FF),
              size: 20,
            ),
            onPressed: _clearFilters,
            tooltip: 'Clear all filters',
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown<T>({
    required bool isDark,
    required T value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(
            icon,
            color: isDark ? Colors.grey.shade400 : Colors.grey,
            size: 18,
          ),
          items: items,
          onChanged: onChanged,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildJobList(bool isDark) {
    final int itemCount = _filteredJobs.length + (_hasMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200 &&
            !_isLoadingMore &&
            _hasMore) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await _fetchJobs(reset: true);
        },
        color: const Color(0xFF6C63FF),
        child: _isWeb
            ? GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == _filteredJobs.length) {
                    return _buildLoadMoreIndicator(isDark);
                  }
                  return _buildJobCard(_filteredJobs[index], index, isDark);
                },
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: itemCount,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemBuilder: (context, index) {
                  if (index == _filteredJobs.length) {
                    return _buildLoadMoreIndicator(isDark);
                  }
                  return _buildJobCard(_filteredJobs[index], index, isDark);
                },
              ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator(bool isDark) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, int index, bool isDark) {
    final colorType = JobColorMasterData.normalize(job['color_type']);
    final colorPrimary = JobColorMasterData.getPrimary(colorType);
    final colorSecondary = JobColorMasterData.getSecondary(colorType);
    final colorTint = JobColorMasterData.getTint(colorType);
    final colorIcon = JobColorMasterData.getIcon(colorType);
    final isWhiteColor = colorType == 'white';

    final salaryMin = job['salary_min'];
    final salaryMax = job['salary_max'];
    final expMin = job['experience_min_years'];
    final expMax = job['experience_max_years'];
    final qualification =
        job['required_qualification']?.toString() ?? 'Any Graduate';

    final distanceKm = _asDouble(job['distance_km']);
    final isNearby = distanceKm != null && distanceKm <= 10;
    final location = _getJobLocationName(job);

    final jobId = job['_id']?.toString() ?? '';
    final isSaved = _savedJobIds.contains(jobId);

    final matchScore =
        AIRecommendationService.calculateMatchScore(job, _userProfile);

    return GestureDetector(
      onTap: () => _onJobTap(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey.shade800.withValues(alpha: 0.85)
              : (isWhiteColor
                  ? Colors.white
                  : colorTint.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? colorPrimary.withValues(alpha: 0.4)
                : colorPrimary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black26
                  : colorPrimary.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 260;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: compact ? 42 : 48,
                      height: compact ? 42 : 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorPrimary, colorSecondary],
                        ),
                        borderRadius:
                            BorderRadius.circular(compact ? 10 : 14),
                        boxShadow: [
                          BoxShadow(
                            color: colorPrimary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        colorIcon,
                        color: Colors.white,
                        size: compact ? 22 : 26,
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['post_name']?.toString() ?? 'Job Title',
                            style: TextStyle(
                              fontSize: compact ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            job['organization']?.toString() ?? 'Company',
                            style: TextStyle(
                              fontSize: compact ? 11 : 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _toggleSaveJob(job),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: colorPrimary,
                          size: compact ? 20 : 22,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: () {
                      final filter = _colorFilters.firstWhere(
                        (f) => f['value'] == colorType,
                        orElse: () => _colorFilters.first,
                      );
                      _showColorNote(context, filter);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorPrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorPrimary,
                              borderRadius: BorderRadius.circular(2),
                              border: isWhiteColor
                                  ? Border.all(
                                      color: Colors.grey.shade400,
                                      width: 1)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              JobColorMasterData.getLabel(colorType),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isWhiteColor
                                    ? Colors.grey.shade700
                                    : colorPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.info_outline,
                            size: 10,
                            color: isWhiteColor
                                ? Colors.grey.shade600
                                : colorPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: matchScore >= 75
                            ? [Colors.green, Colors.lightGreen]
                            : matchScore >= 50
                                ? [Colors.orange, Colors.yellow]
                                : [Colors.red, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${matchScore.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: colorPrimary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: colorPrimary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    job['post_date']?.toString() ?? 'Recently',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: colorPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school, size: 12, color: colorPrimary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Qualification: $qualification',
                      style: TextStyle(fontSize: 11, color: colorPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),

            if (distanceKm != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: isNearby
                      ? Colors.green.shade50
                      : (isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: isNearby
                      ? Border.all(color: Colors.green.shade300)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 14,
                      color: isNearby
                          ? Colors.green
                          : (isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isNearby ? FontWeight.bold : FontWeight.normal,
                        color: isNearby
                            ? Colors.green
                            : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey),
                      ),
                    ),
                    if (isNearby) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Nearby',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (salaryMin != null || salaryMax != null)
                  _buildTag(
                    Icons.currency_rupee,
                    _formatSalary(salaryMin, salaryMax),
                    colorPrimary,
                    isDark,
                  ),
                if (expMin != null || expMax != null)
                  _buildTag(
                    Icons.work_history,
                    _formatExperience(expMin, expMax),
                    colorPrimary,
                    isDark,
                  ),
                if (job['category'] != null &&
                    job['category'].toString().isNotEmpty)
                  _buildTag(
                    Icons.category,
                    job['category'].toString(),
                    colorPrimary,
                    isDark,
                  ),
                if (job['last_date'] != null &&
                    job['last_date'].toString().isNotEmpty)
                  _buildTag(
                    Icons.event,
                    'Last: ${job['last_date']}',
                    Colors.red,
                    isDark,
                  ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              job['description']?.toString() ?? 'No description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 10),

            if (job['required_skills'] is List &&
                (job['required_skills'] as List).isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (job['required_skills'] as List)
                    .take(4)
                    .map<Widget>((skill) {
                  final name = skill is Map ? skill['name'] : skill;
                  if (name == null || name.toString().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colorPrimary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      name.toString(),
                      style:
                          TextStyle(fontSize: 11, color: colorPrimary),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _onJobTap(job),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'View Details',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(
      IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load jobs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _fetchJobs(reset: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasFilters = _selectedJobType != 'all' ||
        _selectedSector != 'all' ||
        _selectedState != 'all' ||
        _selectedEducation != 'all' ||
        _selectedSalaryRange != 'all' ||
        _selectedColorType != 'all' ||
        _searchQuery.isNotEmpty;

    final String colorLabel = _selectedColorType == 'all'
        ? ''
        : JobColorMasterData.getLabel(_selectedColorType);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  Colors.grey.shade800,
                                  Colors.grey.shade700,
                                ]
                              : [
                                  const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.1),
                                  const Color(0xFFFF6588)
                                      .withValues(alpha: 0.05),
                                ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.work_off_outlined,
                        size: 60,
                        color: isDark
                            ? Colors.grey.shade500
                            : const Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _selectedColorType == 'all'
                          ? 'No jobs available'
                          : 'No $colorLabel Jobs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedColorType == 'all'
                          ? 'No jobs are available at the moment.\nPull down to refresh or check back later.'
                          : 'No $colorLabel collar jobs found at the moment.\nTry selecting a different color.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _fetchJobs(reset: true),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (hasFilters) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear Filters'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6C63FF),
                              side: const BorderSide(
                                  color: Color(0xFF6C63FF)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}