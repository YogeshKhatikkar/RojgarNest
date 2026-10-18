// lib/features/admin/AI/admin_ai_dashboard.dart - Remove unused _selectedTab
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

class AdminAIDashboard extends StatefulWidget {
  const AdminAIDashboard({super.key});

  @override
  State<AdminAIDashboard> createState() => _AdminAIDashboardState();
}

class _AdminAIDashboardState extends State<AdminAIDashboard> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _rankedApplications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DioClient.dio.get('/admin/ai/dashboard'),
        DioClient.dio.get(
          '/admin/ai/applications/ranked',
          queryParameters: {'limit': 20},
        ),
      ]);

      if (mounted) {
        setState(() {
          _dashboard = results[0].data;
          _rankedApplications = results[1].data['ranked_applications'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to load AI dashboard: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("AI Admin Dashboard"),
          backgroundColor: Colors.blueAccent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: "Overview"),
                Tab(icon: Icon(Icons.leaderboard), text: "Rankings"),
                Tab(icon: Icon(Icons.trending_up), text: "Trends"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildRankingsTab(),
            _buildTrendsTab(),
          ],
        ),
      ),
    );
  }

  // Rest of the methods remain the same...
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMetricRow(),
          const SizedBox(height: 16),
          _buildFraudAlerts(),
          const SizedBox(height: 16),
          _buildAutoShortlistSuggestions(),
        ],
      ),
    );
  }

  Widget _buildMetricRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            "Total Applications",
            _dashboard['total_applications']?.toString() ?? "0",
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            "AI Shortlisted",
            _dashboard['auto_shortlist_ready']?.toString() ?? "0",
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            "High Risk",
            _dashboard['high_risk_applications']?.toString() ?? "0",
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFraudAlerts() {
    final highRisk = _dashboard['high_risk_applications'] ?? 0;
    if (highRisk == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text("No fraud alerts detected"),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text("$highRisk applications require fraud review")),
        ],
      ),
    );
  }

  Widget _buildAutoShortlistSuggestions() {
    final suggestions = _rankedApplications
        .where((a) => (a['match_score'] ?? 0) >= 85)
        .toList();
    if (suggestions.isEmpty) {
      return const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Auto-Shortlist Suggestions",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...suggestions
              .take(3)
              .map(
                (app) => ListTile(
                  leading: const Icon(Icons.person, color: Colors.amber),
                  title: Text(app['candidate_name'] ?? ''),
                  subtitle: Text(
                    "${app['job_title'] ?? ''} • Match: ${app['match_score'] ?? 0}%",
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Shortlist"),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildRankingsTab() {
    if (_rankedApplications.isEmpty) {
      return const Center(child: Text("No applications to rank"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rankedApplications.length,
      itemBuilder: (context, index) {
        final app = _rankedApplications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getScoreColor(app['match_score'] ?? 0),
              child: Text("${index + 1}"),
            ),
            title: Text(app['candidate_name'] ?? ''),
            subtitle: Text(
              "${app['job_title'] ?? ''} • ${app['status'] ?? 'pending'}",
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getScoreColor(
                  app['match_score'] ?? 0,
                ).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${app['match_score'] ?? 0}%",
                style: TextStyle(
                  color: _getScoreColor(app['match_score'] ?? 0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hiring Trends",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildTrendItem(
                  "Trend Direction",
                  _dashboard['trend_direction']?.toString() ?? "stable",
                ),
                _buildTrendItem(
                  "Predicted Next 30 Days",
                  "${_dashboard['predicted_next_30_days'] ?? 0} applications",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Top Job Categories",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...(_dashboard['top_job_categories'] ?? []).map(
                  (cat) => ListTile(
                    title: Text(cat['category'] ?? ''),
                    trailing: Text("${cat['count'] ?? 0} applications"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}
