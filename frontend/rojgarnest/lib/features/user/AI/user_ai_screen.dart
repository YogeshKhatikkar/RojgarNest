// lib/features/user/AI/user_ai_screen.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

class UserAIScreen extends StatefulWidget {
  const UserAIScreen({super.key});

  @override
  State<UserAIScreen> createState() => _UserAIScreenState();
}

class _UserAIScreenState extends State<UserAIScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _careerAnalysis = {};
  Map<String, dynamic> _jobRecommendations = {};
  Map<String, dynamic> _skillGap = {};
  Map<String, dynamic> _profileComparison = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DioClient.dio.get('/user/ai/career-analysis'),
        DioClient.dio.get('/user/ai/job-recommendations'),
        DioClient.dio.get('/user/ai/skill-gap-analysis'),
        DioClient.dio.get('/user/ai/profile-comparison'),
      ]);

      if (mounted) {
        setState(() {
          // Convert LinkedMap to Map<String, dynamic>
          _careerAnalysis = _toMap(results[0].data);
          _jobRecommendations = _toMap(results[1].data);
          _skillGap = _toMap(results[2].data);
          _profileComparison = _toMap(results[3].data);
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to load AI insights: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper method to convert any Map-like object to Map<String, dynamic>
  Map<String, dynamic> _toMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("AI Career Assistant"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.analytics), text: "Career"),
                Tab(icon: Icon(Icons.work), text: "Jobs"),
                Tab(icon: Icon(Icons.build), text: "Skills"),
                Tab(icon: Icon(Icons.compare), text: "Compare"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildCareerTab(),
            _buildJobsTab(),
            _buildSkillsTab(),
            _buildComparisonTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerTab() {
    // Safely extract data with proper casting
    final summaryData = _careerAnalysis['career_summary'];
    final Map<String, dynamic> summary = summaryData is Map
        ? Map<String, dynamic>.from(summaryData)
        : {};

    final overallScore = _careerAnalysis['overall_score'] is int
        ? _careerAnalysis['overall_score'] as int
        : (_careerAnalysis['overall_score'] ?? 50);

    final growthData = _careerAnalysis['growth_projection'];
    final Map<String, dynamic> growthProj = growthData is Map
        ? Map<String, dynamic>.from(growthData)
        : {};

    final actionData = _careerAnalysis['action_plan'];
    final Map<String, dynamic> actionPlan = actionData is Map
        ? Map<String, dynamic>.from(actionData)
        : {};

    final aiData = _careerAnalysis['ai_recommendations'];
    final Map<String, dynamic> aiRecs = aiData is Map
        ? Map<String, dynamic>.from(aiData)
        : {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildScoreCard(
            "Career Score",
            "$overallScore%",
            _getScoreColor(overallScore),
          ),
          const SizedBox(height: 16),
          _buildStrengthsWeaknesses(summary),
          const SizedBox(height: 16),
          _buildGrowthProjection(growthProj),
          const SizedBox(height: 16),
          _buildActionPlan(actionPlan),
          const SizedBox(height: 16),
          _buildAIMessage(aiRecs),
        ],
      ),
    );
  }

  Widget _buildJobsTab() {
    final jobsData = _jobRecommendations['data'];
    final List<dynamic> jobs = jobsData is List
        ? List<dynamic>.from(jobsData)
        : [];

    if (jobs.isEmpty) {
      return const Center(
        child: Text("No job recommendations yet. Complete your profile first."),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final jobData = jobs[index];
        final Map<String, dynamic> job = jobData is Map
            ? Map<String, dynamic>.from(jobData)
            : {};
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.work, color: Colors.blue),
            title: Text(job['title'] ?? 'Job Title'),
            subtitle: Text(job['reason'] ?? ''),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("${job['match_score'] ?? 0}% Match"),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkillsTab() {
    final currentData = _skillGap['current_skills'];
    final List<dynamic> currentSkills = currentData is List
        ? List<dynamic>.from(currentData)
        : [];

    final missingData = _skillGap['missing_skills'];
    final List<dynamic> missingSkills = missingData is List
        ? List<dynamic>.from(missingData)
        : [];

    final coursesData = _skillGap['recommended_courses'];
    final List<dynamic> recommendations = coursesData is List
        ? List<dynamic>.from(coursesData)
        : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Skills",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: currentSkills
                .map((s) => Chip(label: Text(s.toString())))
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            "Skills to Develop",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: missingSkills
                .map(
                  (s) => Chip(
                    label: Text(s.toString()),
                    backgroundColor: Colors.orange.shade100,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            "Recommended Courses",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...recommendations.map((c) {
            final Map<String, dynamic> course = c is Map
                ? Map<String, dynamic>.from(c)
                : {};
            return ListTile(
              leading: const Icon(Icons.play_circle, color: Colors.blue),
              title: Text(course['name'] ?? ''),
              subtitle: Text(
                "${course['platform'] ?? ''} • ${course['duration'] ?? ''}",
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparisonTab() {
    final overallMatch = _profileComparison['overall_match'] is int
        ? _profileComparison['overall_match'] as int
        : (_profileComparison['overall_match'] ?? 50);

    final strengthsData = _profileComparison['strength_areas'];
    final List<dynamic> strengths = strengthsData is List
        ? List<dynamic>.from(strengthsData)
        : [];

    final improvementsData = _profileComparison['improvement_areas'];
    final List<dynamic> improvements = improvementsData is List
        ? List<dynamic>.from(improvementsData)
        : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildScoreCard("Profile Match", "$overallMatch%", Colors.purple),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Strengths",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                ...strengths.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(s.toString()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Areas to Improve",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ...improvements.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(s.toString()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsWeaknesses(Map<String, dynamic> summary) {
    final strengthsData = summary['strengths'];
    final List<dynamic> strengths = strengthsData is List
        ? List<dynamic>.from(strengthsData)
        : [];

    final weaknessesData = summary['weaknesses'];
    final List<dynamic> weaknesses = weaknessesData is List
        ? List<dynamic>.from(weaknessesData)
        : [];

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.thumb_up, color: Colors.green),
                const SizedBox(height: 4),
                ...strengths.map(
                  (s) =>
                      Text(s.toString(), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(height: 4),
                ...weaknesses.map(
                  (s) =>
                      Text(s.toString(), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthProjection(Map<String, dynamic> projection) {
    final next6Months = projection['next_6_months'] ?? 65;
    final next1Year = projection['next_1_year'] ?? 75;
    final next3Years = projection['next_3_years'] ?? 85;
    final next5Years = projection['next_5_years'] ?? 90;

    // Convert to int safely
    final int val6Months = next6Months is int
        ? next6Months
        : (next6Months ?? 65);
    final int val1Year = next1Year is int ? next1Year : (next1Year ?? 75);
    final int val3Years = next3Years is int ? next3Years : (next3Years ?? 85);
    final int val5Years = next5Years is int ? next5Years : (next5Years ?? 90);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Growth Projection",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildProgressItem("6 Months", val6Months),
          _buildProgressItem("1 Year", val1Year),
          _buildProgressItem("3 Years", val3Years),
          _buildProgressItem("5 Years", val5Years),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text("$value%")],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.grey.shade200,
          ),
        ],
      ),
    );
  }

  Widget _buildActionPlan(Map<String, dynamic> actionPlan) {
    final nextStepsData = actionPlan['next_steps'];
    final List<dynamic> nextSteps = nextStepsData is List
        ? List<dynamic>.from(nextStepsData)
        : [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Action Plan",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...nextSteps.map(
            (step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(step.toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIMessage(Map<String, dynamic> aiRecs) {
    final message =
        aiRecs['personalized_message'] ??
        "Complete your profile for personalized guidance.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.purple, Colors.blue]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}
