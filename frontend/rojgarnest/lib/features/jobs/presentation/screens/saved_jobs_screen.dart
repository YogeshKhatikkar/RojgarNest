// lib/features/jobs/presentation/screens/saved_jobs_screen.dart
// COMPLETE FIXED VERSION - Shows only saved jobs (status='saved')
// Click on "View & Apply" button opens Job Details in right panel

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

class SavedJobsScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onJobSelected;
  final VoidCallback? onJobRemoved;
  final VoidCallback? onJobApplied;

  const SavedJobsScreen({
    super.key,
    this.onJobSelected,
    this.onJobRemoved,
    this.onJobApplied,
  });

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<dynamic> _savedJobs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSavedJobs();
  }

  Future<void> _fetchSavedJobs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        if (mounted) {
          setState(() {
            _savedJobs = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch ALL user applications
      final response = await DioClient.dio.get(
        '/jobs/my-applications',
      );

      if (!mounted) return;

      List<dynamic> allApplications = [];

      if (response.data is Map) {
        final data = response.data;
        if (data.containsKey('data') && data['data'] is Map) {
          allApplications = data['data']['applications'] ?? [];
        } else if (data.containsKey('applications')) {
          allApplications = data['applications'] ?? [];
        } else {
          allApplications = [];
        }
      } else {
        allApplications = response.data ?? [];
      }

      // Filter: ONLY saved jobs (status == 'saved')
      final savedApps = allApplications.where((app) {
        final status = app['status']?.toString().toLowerCase() ?? '';
        return status == 'saved';
      }).toList();

      debugPrint(
          "📊 Saved Jobs - Total apps: ${allApplications.length}, Saved: ${savedApps.length}");

      // Get applied job IDs to filter out already applied ones
      final appliedApps = allApplications.where((app) {
        final status = app['status']?.toString().toLowerCase() ?? '';
        return status != 'saved';
      }).toList();

      final Set<String> appliedJobIds = {};
      for (var app in appliedApps) {
        final jobId = app['job_id']?.toString();
        if (jobId != null && jobId.isNotEmpty) {
          appliedJobIds.add(jobId);
        }
      }

      // Fetch full job details for saved jobs
      final List<Map<String, dynamic>> completeJobs = [];

      for (var app in savedApps) {
        final jobId = app['job_id']?.toString();
        if (jobId == null || jobId.isEmpty) continue;

        // Skip if already applied
        if (appliedJobIds.contains(jobId)) {
          debugPrint("⏭️ Skipping already applied job: $jobId");
          continue;
        }

        try {
          final jobResponse = await DioClient.dio.get('/jobs/$jobId');
          Map<String, dynamic> job = jobResponse.data;

          if (job.containsKey('data') && job['data'] is Map) {
            job = job['data'];
          }

          job['saved_at'] = app['saved_at'];
          job['application_id'] = app['_id'];
          job['is_saved'] = true;

          completeJobs.add(job);
          debugPrint("✅ Added saved job: ${job['post_name']}");
        } catch (e) {
          debugPrint("❌ Error fetching job details for $jobId: $e");
        }
      }

      if (mounted) {
        setState(() {
          _savedJobs = completeJobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching saved jobs: $e");
      if (mounted) {
        setState(() {
          _savedJobs = [];
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _fetchSavedJobs();
  }

  Future<void> _removeSavedJob(String jobId, String jobTitle) async {
    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Remove Saved Job"),
        content: Text(
          "Are you sure you want to remove \"$jobTitle\" from saved jobs?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await DioClient.dio.delete('/jobs/save/$jobId');
      if (!mounted) return;
      await _fetchSavedJobs();
      if (mounted) {
        showMessage(context, "Job removed from saved");
        if (widget.onJobRemoved != null) {
          widget.onJobRemoved!();
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to remove job: $e", isError: true);
      }
    }
  }

  void _onJobSelected(Map<String, dynamic> job) {
    debugPrint(
        "📱 SavedJobsScreen - _onJobSelected called for: ${job['post_name']}");
    if (widget.onJobSelected != null) {
      widget.onJobSelected!(job);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Recently';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return '$diff days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _getFormattedTitle(Map<String, dynamic> job) {
    final jobTitle = job['post_name'] ?? '';
    final organization = job['organization'] ?? '';

    if (jobTitle.isEmpty && organization.isEmpty) {
      return 'Job Opportunity';
    }
    if (jobTitle.isNotEmpty && organization.isNotEmpty) {
      return '$jobTitle - $organization';
    }
    return jobTitle.isNotEmpty ? jobTitle : organization;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Saved Jobs"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _savedJobs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _savedJobs.length,
                        itemBuilder: (context, index) {
                          final job = _savedJobs[index];
                          return _buildSavedJobCard(job);
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            "Failed to load saved jobs",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? "Unknown error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchSavedJobs,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            "No saved jobs",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text("Jobs you save will appear here"),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.search),
            label: const Text("Browse Jobs"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedJobCard(Map<String, dynamic> job) {
    final formattedTitle = _getFormattedTitle(job);
    final savedDate = _formatDate(job['saved_at']);
    final jobType = job['job_type'] ?? 'private';
    final typeColor = _getJobTypeColor(jobType);
    final hasFees = job['has_application_fees'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          debugPrint("📱 SavedJobsCard tapped for: $formattedTitle");
          _onJobSelected(job);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Type Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      jobType.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formattedTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.bookmark, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text("Saved: $savedDate",
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              if (hasFees) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_rupee,
                          size: 12, color: Colors.teal),
                      const SizedBox(width: 4),
                      const Text("Application Fee Applicable",
                          style: TextStyle(fontSize: 11, color: Colors.teal)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    debugPrint("📱 View & Apply clicked for: $formattedTitle");
                    _onJobSelected(job);
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text("View & Apply",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _removeSavedJob(job['_id'].toString(), formattedTitle),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Remove from Saved",
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getJobTypeColor(String? type) {
    switch (type) {
      case 'private':
        return Colors.blue;
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
}
