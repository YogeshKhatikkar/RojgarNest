// lib/features/user/AI/user_career_roadmap_screen.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

class UserCareerRoadmapScreen extends StatefulWidget {
  const UserCareerRoadmapScreen({super.key});

  @override
  State<UserCareerRoadmapScreen> createState() =>
      _UserCareerRoadmapScreenState();
}

class _UserCareerRoadmapScreenState extends State<UserCareerRoadmapScreen> {
  final TextEditingController _targetCareerController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic> _roadmap = {};

  Future<void> _generateRoadmap() async {
    final target = _targetCareerController.text.trim();
    if (target.isEmpty) {
      showMessage(context, "Please enter a target career", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await DioClient.dio.post(
        '/user/ai/career-roadmap',
        data: {'target_career': target},
      );
      if (mounted) {
        setState(() => _roadmap = response.data);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, "Failed to generate roadmap: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Career Roadmap"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      "Enter your dream career",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetCareerController,
                      decoration: InputDecoration(
                        hintText: "e.g., Software Engineer, Data Scientist",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _generateRoadmap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Generate Roadmap"),
                    ),
                  ],
                ),
              ),
            ),
            if (_roadmap.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildCareerPathSection(),
              const SizedBox(height: 16),
              _buildSkillsSection(),
              const SizedBox(height: 16),
              _buildCertificationsSection(),
              const SizedBox(height: 16),
              _buildMilestonesSection(),
              const SizedBox(height: 16),
              _buildSalaryProgressionSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCareerPathSection() {
    final careerPath = _roadmap['career_path'] ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Career Path",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTimelineNode(
              "Entry",
              careerPath['entry_level'] ?? "Junior",
              "0-2",
            ),
            const Divider(),
            _buildTimelineNode(
              "Mid",
              careerPath['mid_level'] ?? "Professional",
              "2-5",
            ),
            const Divider(),
            _buildTimelineNode(
              "Senior",
              careerPath['senior_level'] ?? "Senior",
              "5-8",
            ),
            const Divider(),
            _buildTimelineNode(
              "Expert",
              careerPath['expert_level'] ?? "Lead",
              "8+",
            ),
            const SizedBox(height: 8),
            Text(
              "Estimated: ${careerPath['estimated_timeline'] ?? "5-8"} years",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineNode(String level, String role, String years) {
    return Row(
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            years,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(role, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsSection() {
    final skills = _roadmap['skills_to_acquire'] ?? [];
    if (skills.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Skills to Acquire",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...skills.map(
              (skill) => ListTile(
                leading: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(
                      skill['priority'],
                    ).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      skill['priority']
                              ?.toString()
                              .substring(0, 1)
                              .toUpperCase() ??
                          "M",
                    ),
                  ),
                ),
                title: Text(skill['skill'] ?? ''),
                subtitle: Text(
                  "Estimated: ${skill['estimated_time'] ?? '2-3 months'}",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificationsSection() {
    final certifications = _roadmap['certifications'] ?? [];
    if (certifications.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Recommended Certifications",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...certifications.map(
              (cert) => ListTile(
                leading: const Icon(Icons.verified, color: Colors.blue),
                title: Text(cert['name'] ?? ''),
                subtitle: Text(
                  "${cert['provider'] ?? ''} • ${cert['duration'] ?? ''}",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestonesSection() {
    final milestones = _roadmap['milestones'] ?? [];
    if (milestones.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Milestones",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...milestones.asMap().entries.map(
              (entry) => ListTile(
                leading: CircleAvatar(child: Text("${entry.key + 1}")),
                title: Text(entry.value['milestone'] ?? ''),
                subtitle: Text(
                  "Target: ${entry.value['target_date'] ?? 'TBD'}",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryProgressionSection() {
    final salary = _roadmap['salary_progression'] ?? [];
    if (salary.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Salary Progression",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...salary.map(
              (level) => ListTile(
                leading: Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    level['level'] ?? '',
                    textAlign: TextAlign.center,
                  ),
                ),
                title: Text(level['range'] ?? ''),
                subtitle: Text(level['timeframe'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
