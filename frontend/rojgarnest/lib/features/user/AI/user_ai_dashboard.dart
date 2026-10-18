// lib/features/user/AI/user_ai_dashboard.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/user/AI/user_ai_service.dart';

class UserAIDashboard extends StatefulWidget {
  const UserAIDashboard({super.key});

  @override
  State<UserAIDashboard> createState() => _UserAIDashboardState();
}

class _UserAIDashboardState extends State<UserAIDashboard> {
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
        UserAIService.getCareerAnalysis(),
        UserAIService.getJobRecommendations(limit: 10),
        UserAIService.getSkillGapAnalysis(),
        UserAIService.getProfileComparison(),
      ]);

      if (mounted) {
        setState(() {
          _careerAnalysis = results[0];
          _jobRecommendations = results[1];
          _skillGap = results[2];
          _profileComparison = results[3];
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

  Future<void> _refreshData() async {
    await _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "AI is analyzing your profile...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("AI Career Intelligence"),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.analytics), text: "Overview"),
                Tab(icon: Icon(Icons.work), text: "Jobs"),
                Tab(icon: Icon(Icons.build), text: "Skills"),
                Tab(icon: Icon(Icons.compare), text: "Compare"),
                Tab(icon: Icon(Icons.timeline), text: "Growth"),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: "Refresh AI Insights",
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: TabBarView(
            children: [
              _buildOverviewTab(),
              _buildJobsTab(),
              _buildSkillsTab(),
              _buildComparisonTab(),
              _buildGrowthTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TAB 1: OVERVIEW ====================
  Widget _buildOverviewTab() {
    final summary = _careerAnalysis['career_summary'] ?? {};
    final overallScore = _careerAnalysis['overall_score'] ?? 50;
    final completion = _careerAnalysis['profile_completion_percentage'] ?? 0;
    final experienceYears = _careerAnalysis['experience_years'] ?? 0;
    final skillScore = _careerAnalysis['skill_score'] ?? 0;
    final educationScore = _careerAnalysis['education_score'] ?? 0;
    final growthProj = _careerAnalysis['growth_projection'] ?? {};
    final actionPlan = _careerAnalysis['action_plan'] ?? {};
    final aiRecs = _careerAnalysis['ai_recommendations'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(completion),
          const SizedBox(height: 20),
          _buildScoreCardRow(overallScore, completion, skillScore),
          const SizedBox(height: 12),
          _buildSecondScoreCardRow(educationScore, experienceYears, growthProj),
          const SizedBox(height: 20),
          _buildCareerScoreDashboard(overallScore),
          const SizedBox(height: 20),
          _buildStrengthsWeaknessesRow(summary),
          const SizedBox(height: 20),
          _buildGrowthProjectionChart(growthProj),
          const SizedBox(height: 20),
          _buildActionPlan(actionPlan),
          const SizedBox(height: 20),
          _buildAIMessage(aiRecs),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(int completion) {
    final name = _careerAnalysis['user_name']?.split(' ').first ?? 'User';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, $name!",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your AI Career Assistant is ready to guide you",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: completion / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Profile Completion: $completion%",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCardRow(int overallScore, int completion, int skillScore) {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            "Career Score",
            "$overallScore%",
            _getScoreColor(overallScore),
            Icons.star,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(
            "Profile",
            "$completion%",
            Colors.blue,
            Icons.verified,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(
            "Skills",
            "$skillScore%",
            Colors.green,
            Icons.build,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondScoreCardRow(
    int educationScore,
    double experienceYears,
    Map<String, dynamic> growthProj,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            "Education",
            "$educationScore%",
            Colors.purple,
            Icons.school,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(
            "Experience",
            "${(experienceYears * 20).toInt()}%",
            Colors.orange,
            Icons.work,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildScoreCard(
            "Growth",
            "${growthProj['next_1_year'] ?? 75}%",
            Colors.teal,
            Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCareerScoreDashboard(int score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
      ),
      child: Column(
        children: [
          const Text(
            "Career Readiness Score",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            width: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: _getScoreColor(score),
                ),
                Text(
                  "$score%",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(score),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getScoreMessage(score),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsWeaknessesRow(Map<String, dynamic> summary) {
    final strengths = summary['strengths'] ?? [];
    final weaknesses = summary['weaknesses'] ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.thumb_up, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      "Strengths",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...strengths.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      "Growth Areas",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...weaknesses.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.error, size: 14, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthProjectionChart(Map<String, dynamic> projection) {
    final now = projection['current_score'] ?? 65;
    final sixMonths = projection['next_6_months'] ?? 65;
    final oneYear = projection['next_1_year'] ?? 75;
    final threeYears = projection['next_3_years'] ?? 90;
    final fiveYears = projection['next_5_years'] ?? 95;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Career Growth Projection",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _buildLineChart(
              now,
              sixMonths,
              oneYear,
              threeYears,
              fiveYears,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(
    double now,
    double sixMonths,
    double oneYear,
    double threeYears,
    double fiveYears,
  ) {
    return CustomPaint(
      painter: _LineChartPainter(
        now,
        sixMonths,
        oneYear,
        threeYears,
        fiveYears,
      ),
      size: const Size(double.infinity, 200),
    );
  }

  Widget _buildActionPlan(Map<String, dynamic> actionPlan) {
    final nextSteps = actionPlan['next_steps'] ?? [];
    final timeline = actionPlan['timeline'] ?? "3-6 months";
    final priorityActions = actionPlan['priority_actions'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📋 Your Action Plan",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (priorityActions.isNotEmpty) ...[
            const Text(
              "Priority Actions:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            ...priorityActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.priority_high,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(action.toString())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            "Next Steps:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...nextSteps
              .take(5)
              .map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(step.toString())),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(child: Text("Estimated Timeline: $timeline")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIMessage(Map<String, dynamic> aiRecs) {
    final message =
        aiRecs['personalized_message'] ??
        "Complete your profile to get personalized career guidance!";
    final quickWins = aiRecs['quick_wins'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                "AI Recommendation",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(height: 1.5)),
          if (quickWins.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Quick Wins:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...quickWins.map(
              (win) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        win.toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== TAB 2: JOBS ====================
  Widget _buildJobsTab() {
    final jobs = _jobRecommendations['data'] ?? [];

    if (jobs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text("No job recommendations yet", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              "Complete your profile for personalized recommendations",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final matchScore = job['match_score'] ?? 50;
        final type = job['type'] ?? 'private';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getJobTypeColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: _getJobTypeColor(type),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "$matchScore% Match",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  job['title'] ?? 'Job Title',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (job['salary_range'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "💰 ${job['salary_range']}",
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
                const SizedBox(height: 8),
                Text(job['reason'] ?? 'Suitable based on your profile'),
                if (job['required_skills'] != null &&
                    (job['required_skills'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: (job['required_skills'] as List)
                        .take(3)
                        .map(
                          (skill) => Chip(
                            label: Text(
                              skill.toString(),
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.blue.shade50,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== TAB 3: SKILLS ====================
  Widget _buildSkillsTab() {
    final currentSkills = _skillGap['current_skills'] ?? [];
    final missingSkills = _skillGap['missing_skills'] ?? [];
    final improvementPriorities = _skillGap['improvement_priorities'] ?? [];
    final recommendedCourses = _skillGap['recommended_courses'] ?? [];
    final estimatedTime = _skillGap['estimated_learning_time'] ?? "3-6 months";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "✅ Your Current Skills",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (currentSkills.isEmpty)
                  const Text(
                    "No skills added yet. Add your skills to get better recommendations.",
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: currentSkills
                        .map(
                          (s) => Chip(
                            label: Text(s.toString()),
                            backgroundColor: Colors.green.shade100,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📚 Skills to Develop",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (missingSkills.isEmpty)
                  const Text(
                    "Great job! You have all the recommended skills.",
                    style: TextStyle(color: Colors.green),
                  )
                else
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
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🎯 Improvement Priorities",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...improvementPriorities.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.priority_high,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(p.toString())),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (recommendedCourses.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📖 Recommended Courses",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...recommendedCourses.map(
                    (c) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.play_circle,
                          color: Colors.blue,
                        ),
                        title: Text(c['name'] ?? 'Course'),
                        subtitle: Text(
                          "${c['platform'] ?? 'Online'} • ${c['duration'] ?? 'Self-paced'}",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("Estimated Learning Time: $estimatedTime"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 4: COMPARISON ====================
  Widget _buildComparisonTab() {
    final overallMatch = _profileComparison['overall_match'] ?? 50;
    final strengths = _profileComparison['strength_areas'] ?? [];
    final improvements = _profileComparison['improvement_areas'] ?? [];
    final recommendations =
        _profileComparison['specific_recommendations'] ?? [];
    final successProbability =
        _profileComparison['estimated_success_probability'] ?? 50;
    final insights = _profileComparison['comparison_insights'] ?? "";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  "Profile Match with Successful Candidates",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: CircularProgressIndicator(
                        value: overallMatch / 100,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        color: Colors.amber,
                      ),
                    ),
                    Text(
                      "$overallMatch%",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Success Probability: $successProbability%",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.thumb_up, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      "Your Strengths",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...strengths.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.toString())),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      "Areas to Improve",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...improvements.map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.error, size: 14, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(i.toString())),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      "Recommendations",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recommendations.map(
                  (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Text("• ", style: TextStyle(fontSize: 14)),
                        Expanded(child: Text(rec.toString())),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                insights,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== TAB 5: GROWTH ====================
  Widget _buildGrowthTab() {
    final growthProj = _careerAnalysis['growth_projection'] ?? {};
    final salaryProj = growthProj['estimated_salary_progression'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Salary Progression",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...salaryProj.map(
                  (level) => ListTile(
                    leading: Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        level['year']?.toString() ?? '',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    title: Text(level['salary'] ?? ''),
                    trailing: const Icon(
                      Icons.trending_up,
                      color: Colors.green,
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

  // ==================== HELPER METHODS ====================
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreMessage(int score) {
    if (score >= 80) return "Excellent! You're ready for advanced roles.";
    if (score >= 60) return "Good progress! Focus on skill enhancement.";
    if (score >= 40) return "Complete your profile for better insights.";
    return "Add education and skills to unlock AI guidance.";
  }

  Color _getJobTypeColor(String type) {
    switch (type) {
      case 'government':
        return Colors.green;
      case 'private':
        return Colors.blue;
      case 'remote':
        return Colors.purple;
      case 'internship':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

// ==================== CUSTOM LINE CHART PAINTER ====================
class _LineChartPainter extends CustomPainter {
  final double now, sixMonths, oneYear, threeYears, fiveYears;

  _LineChartPainter(
    this.now,
    this.sixMonths,
    this.oneYear,
    this.threeYears,
    this.fiveYears,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = [
      Offset(size.width * 0, size.height * (1 - now / 100)),
      Offset(size.width * 0.2, size.height * (1 - sixMonths / 100)),
      Offset(size.width * 0.4, size.height * (1 - oneYear / 100)),
      Offset(size.width * 0.7, size.height * (1 - threeYears / 100)),
      Offset(size.width * 0.9, size.height * (1 - fiveYears / 100)),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()..color = Colors.green;
    for (var point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
