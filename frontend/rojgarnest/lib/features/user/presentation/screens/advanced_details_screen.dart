// lib/features/user/presentation/screens/advanced_details_screen.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/user/data/user_service.dart';

class AdvancedDetailsScreen extends StatefulWidget {
  const AdvancedDetailsScreen({super.key});

  @override
  State<AdvancedDetailsScreen> createState() => _AdvancedDetailsScreenState();
}

class _AdvancedDetailsScreenState extends State<AdvancedDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;

  // ==================== SKILL ASSESSMENTS ====================
  List<Map<String, dynamic>> _skillAssessments = [];

  // ==================== CAREER GOALS ====================
  final TextEditingController _shortTermGoals = TextEditingController();
  final TextEditingController _shortTermTargetRole = TextEditingController();
  final TextEditingController _shortTermTargetIndustry =
      TextEditingController();
  final TextEditingController _shortTermTargetSalary = TextEditingController();
  final TextEditingController _mediumTermGoals = TextEditingController();
  final TextEditingController _mediumTermTargetRole = TextEditingController();
  final TextEditingController _mediumTermTargetIndustry =
      TextEditingController();
  final TextEditingController _mediumTermTargetSalary = TextEditingController();
  final TextEditingController _longTermGoals = TextEditingController();
  final TextEditingController _longTermTargetRole = TextEditingController();
  final TextEditingController _longTermTargetIndustry = TextEditingController();
  final TextEditingController _longTermTargetSalary = TextEditingController();
  final TextEditingController _dreamRole = TextEditingController();
  final TextEditingController _dreamCompany = TextEditingController();
  final TextEditingController _dreamIndustry = TextEditingController();
  bool _willingToChangeCareer = false;
  List<String> _interestedDifferentDomains = [];
  String _preferredWorkLifeBalance = 'balanced';
  String _careerAmbition = 'grow';

  // ==================== PERSONALITY TRAITS ====================
  int? _openness;
  int? _conscientiousness;
  int? _extraversion;
  int? _agreeableness;
  int? _neuroticism;
  bool _prefersIndependentWork = false;
  bool _prefersTeamWork = true;
  bool _prefersLeadershipRole = false;
  bool _prefersCreativeWork = false;
  bool _prefersAnalyticalWork = false;
  String _stressTolerance = 'medium';
  String _deadlinePreference = 'flexible';
  String _communicationStyle = 'balanced';
  String _learningStyle = 'visual';

  // ==================== WORK ENVIRONMENT PREFERENCES ====================
  String _preferredCompanySize = 'any';
  List<String> _preferredCompanyType = ['private'];
  List<String> _preferredCulture = [];
  String _deskType = 'any';
  String _noiseLevel = 'moderate';
  String _teamSizePreference = 'medium';
  String _collaborationFrequency = 'daily';
  bool _flexibleHoursRequired = false;
  bool _coreHoursRequired = true;
  bool _weekendWorkWilling = false;
  bool _overtimeWilling = false;
  int _healthInsuranceImportance = 8;
  int _retirementBenefitsImportance = 6;
  int _learningBudgetImportance = 7;
  int _workFromHomeImportance = 5;
  int _gymMembershipImportance = 3;

  // ==================== COMPENSATION EXPECTATIONS ====================
  final TextEditingController _expectedSalaryMinCtrl = TextEditingController();
  final TextEditingController _expectedSalaryMaxCtrl = TextEditingController();
  String _expectedSalaryCurrency = 'INR';
  bool _isSalaryNegotiable = true;
  int _expectedFixedSalaryPercentage = 70;
  int _expectedVariableSalaryPercentage = 30;
  bool _expectedESOPs = false;
  List<String> _mustHaveBenefits = [];
  List<String> _niceToHaveBenefits = [];
  List<String> _desiredPerks = [];
  int _expectedAnnualIncrementPercentage = 10;

  // ==================== JOB SEARCH PREFERENCES ====================
  String _jobAlertFrequency = 'daily';
  List<String> _jobAlertChannels = ['email', 'whatsapp'];
  bool _autoApplyForMatchingJobs = false;
  int _autoApplyThresholdPercentage = 85;
  bool _requireManualReviewBeforeApply = true;
  bool _receiveSimilarJobAlerts = true;
  bool _receiveCareerTips = true;
  bool _receiveMarketUpdates = true;
  List<String> _excludeCompanies = [];
  List<String> _preferredCompanies = [];
  final TextEditingController _noticePeriodDays = TextEditingController();
  bool _canJoinImmediately = false;
  final TextEditingController _availabilityDate = TextEditingController();

  // ==================== EDUCATIONAL GOALS ====================
  bool _wantsHigherEducation = false;
  List<String> _interestedDegrees = [];
  List<String> _interestedInstitutes = [];
  bool _willingToStudyAbroad = false;
  List<String> _preferredStudyCountries = [];
  final TextEditingController _educationBudgetCtrl = TextEditingController();
  bool _needScholarship = false;
  bool _partTimeStudyPreferred = false;
  bool _onlineCoursePreferred = true;

  // ==================== CERTIFICATION GOALS ====================
  List<String> _interestedCertifications = [];
  final TextEditingController _certificationBudgetCtrl =
      TextEditingController();
  bool _willingToGetCertified = true;
  String _preferredCertificationMode = 'online';

  // ==================== LEARNING PREFERENCES ====================
  String _preferredLearningMethod = 'online';
  int _availableLearningHoursPerWeek = 5;
  final TextEditingController _learningBudgetPerMonthCtrl =
      TextEditingController();
  List<String> _interestedCertificationsList = [];
  List<String> _interestedSkillCategories = [];
  List<String> _preferredLearningPlatforms = [];
  bool _mentorshipRequired = false;
  bool _studyGroupInterest = false;

  // ==================== PORTFOLIO LINKS ====================
  final TextEditingController _portfolioGithubUrl = TextEditingController();
  final TextEditingController _portfolioLinkedinUrl = TextEditingController();
  final TextEditingController _portfolioWebsite = TextEditingController();
  final TextEditingController _behanceUrl = TextEditingController();
  final TextEditingController _dribbbleUrl = TextEditingController();
  final TextEditingController _mediumBlog = TextEditingController();
  final TextEditingController _stackoverflowUrl = TextEditingController();
  final TextEditingController _leetcodeUrl = TextEditingController();
  final TextEditingController _hackerrankUrl = TextEditingController();
  final TextEditingController _codeforcesUrl = TextEditingController();
  final TextEditingController _youtubeChannel = TextEditingController();
  final TextEditingController _personalBlog = TextEditingController();

  // ==================== INCOME & EXPENSE ====================
  final TextEditingController _currentMonthlyIncomeCtrl =
      TextEditingController();
  final TextEditingController _expectedMonthlyIncomeCtrl =
      TextEditingController();
  final TextEditingController _monthlyExpensesCtrl = TextEditingController();
  final TextEditingController _monthlySavingsCtrl = TextEditingController();
  bool _existingLoans = false;
  final TextEditingController _loanAmountCtrl = TextEditingController();
  final TextEditingController _loanEMICtrl = TextEditingController();
  int _dependentsCount = 0;
  int _earningMembersCount = 0;

  // ==================== ADDITIONAL DETAILS ====================
  final TextEditingController _additionalSoftSkills = TextEditingController();
  final TextEditingController _videoResumeUrl = TextEditingController();

  // ==================== DROPDOWN OPTIONS ====================
  final List<String> _workLifeBalanceOptions = [
    'balanced',
    'work_focused',
    'life_focused',
    'flexible',
  ];
  final List<String> _careerAmbitionOptions = [
    'grow',
    'leadership',
    'expertise',
    'stability',
    'entrepreneurship',
  ];
  final List<String> _stressToleranceOptions = ['low', 'medium', 'high'];
  final List<String> _deadlineOptions = ['strict', 'flexible', 'self_managed'];
  final List<String> _communicationStyleOptions = [
    'direct',
    'diplomatic',
    'balanced',
    'formal',
  ];
  final List<String> _learningStyleOptions = [
    'visual',
    'auditory',
    'kinesthetic',
    'reading',
    'mixed',
  ];
  final List<String> _companySizeOptions = [
    'startup',
    'small',
    'medium',
    'large',
    'any',
  ];
  final List<String> _companyTypeOptions = [
    'private',
    'public',
    'government',
    'nonprofit',
    'startup',
  ];
  final List<String> _jobAlertFrequencyOptions = [
    'daily',
    'weekly',
    'instant',
    'never',
  ];
  final List<String> _certificationModeOptions = [
    'online',
    'offline',
    'hybrid',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadAdvancedData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shortTermGoals.dispose();
    _shortTermTargetRole.dispose();
    _shortTermTargetIndustry.dispose();
    _shortTermTargetSalary.dispose();
    _mediumTermGoals.dispose();
    _mediumTermTargetRole.dispose();
    _mediumTermTargetIndustry.dispose();
    _mediumTermTargetSalary.dispose();
    _longTermGoals.dispose();
    _longTermTargetRole.dispose();
    _longTermTargetIndustry.dispose();
    _longTermTargetSalary.dispose();
    _dreamRole.dispose();
    _dreamCompany.dispose();
    _dreamIndustry.dispose();
    _expectedSalaryMinCtrl.dispose();
    _expectedSalaryMaxCtrl.dispose();
    _portfolioGithubUrl.dispose();
    _portfolioLinkedinUrl.dispose();
    _portfolioWebsite.dispose();
    _behanceUrl.dispose();
    _dribbbleUrl.dispose();
    _mediumBlog.dispose();
    _stackoverflowUrl.dispose();
    _leetcodeUrl.dispose();
    _hackerrankUrl.dispose();
    _codeforcesUrl.dispose();
    _youtubeChannel.dispose();
    _personalBlog.dispose();
    _noticePeriodDays.dispose();
    _availabilityDate.dispose();
    _educationBudgetCtrl.dispose();
    _certificationBudgetCtrl.dispose();
    _learningBudgetPerMonthCtrl.dispose();
    _currentMonthlyIncomeCtrl.dispose();
    _expectedMonthlyIncomeCtrl.dispose();
    _monthlyExpensesCtrl.dispose();
    _monthlySavingsCtrl.dispose();
    _loanAmountCtrl.dispose();
    _loanEMICtrl.dispose();
    _additionalSoftSkills.dispose();
    _videoResumeUrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdvancedData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profile = await UserService.getFullProfile();

      if (mounted && profile.isNotEmpty) {
        // Load Career Goals
        final careerGoals = _safeMap(profile, 'career_goals');
        _shortTermGoals.text = _safeStringList(careerGoals, 'short_term_goals');
        _shortTermTargetRole.text = _safeString(
          careerGoals,
          'short_term_target_role',
        );
        _shortTermTargetIndustry.text = _safeString(
          careerGoals,
          'short_term_target_industry',
        );
        _shortTermTargetSalary.text = _safeString(
          careerGoals,
          'short_term_target_salary',
        );
        _mediumTermGoals.text = _safeStringList(
          careerGoals,
          'medium_term_goals',
        );
        _mediumTermTargetRole.text = _safeString(
          careerGoals,
          'medium_term_target_role',
        );
        _mediumTermTargetIndustry.text = _safeString(
          careerGoals,
          'medium_term_target_industry',
        );
        _mediumTermTargetSalary.text = _safeString(
          careerGoals,
          'medium_term_target_salary',
        );
        _longTermGoals.text = _safeStringList(careerGoals, 'long_term_goals');
        _longTermTargetRole.text = _safeString(
          careerGoals,
          'long_term_target_role',
        );
        _longTermTargetIndustry.text = _safeString(
          careerGoals,
          'long_term_target_industry',
        );
        _longTermTargetSalary.text = _safeString(
          careerGoals,
          'long_term_target_salary',
        );
        _dreamRole.text = _safeString(careerGoals, 'dream_role');
        _dreamCompany.text = _safeString(careerGoals, 'dream_company');
        _dreamIndustry.text = _safeString(careerGoals, 'dream_industry');
        _willingToChangeCareer = careerGoals['willing_to_change_career'] is bool
            ? careerGoals['willing_to_change_career']
            : false;
        _interestedDifferentDomains = _safeList(
          careerGoals,
          'interested_in_different_domain',
        );
        _preferredWorkLifeBalance = _safeString(
          careerGoals,
          'preferred_work_life_balance',
          'balanced',
        );
        _careerAmbition = _safeString(careerGoals, 'career_ambition', 'grow');

        // Load Personality Traits
        final personality = _safeMap(profile, 'personality_traits');
        _openness = personality['openness'] as int?;
        _conscientiousness = personality['conscientiousness'] as int?;
        _extraversion = personality['extraversion'] as int?;
        _agreeableness = personality['agreeableness'] as int?;
        _neuroticism = personality['neuroticism'] as int?;
        _prefersIndependentWork =
            personality['prefers_independent_work'] is bool
            ? personality['prefers_independent_work']
            : false;
        _prefersTeamWork = personality['prefers_team_work'] is bool
            ? personality['prefers_team_work']
            : true;
        _prefersLeadershipRole = personality['prefers_leadership_role'] is bool
            ? personality['prefers_leadership_role']
            : false;
        _prefersCreativeWork = personality['prefers_creative_work'] is bool
            ? personality['prefers_creative_work']
            : false;
        _prefersAnalyticalWork = personality['prefers_analytical_work'] is bool
            ? personality['prefers_analytical_work']
            : false;
        _stressTolerance = _safeString(
          personality,
          'stress_tolerance',
          'medium',
        );
        _deadlinePreference = _safeString(
          personality,
          'deadline_preference',
          'flexible',
        );
        _communicationStyle = _safeString(
          personality,
          'communication_style',
          'balanced',
        );
        _learningStyle = _safeString(personality, 'learning_style', 'visual');

        // Load Work Environment Preferences
        final workEnv = _safeMap(profile, 'work_environment_preferences');
        _preferredCompanySize = _safeString(
          workEnv,
          'preferred_company_size',
          'any',
        );
        _preferredCompanyType = _safeList(workEnv, 'preferred_company_type', [
          'private',
        ]);
        _preferredCulture = _safeList(workEnv, 'preferred_culture');
        _deskType = _safeString(workEnv, 'desk_type', 'any');
        _noiseLevel = _safeString(workEnv, 'noise_level', 'moderate');
        _teamSizePreference = _safeString(
          workEnv,
          'team_size_preference',
          'medium',
        );
        _collaborationFrequency = _safeString(
          workEnv,
          'collaboration_frequency',
          'daily',
        );
        _flexibleHoursRequired = workEnv['flexible_hours_required'] is bool
            ? workEnv['flexible_hours_required']
            : false;
        _coreHoursRequired = workEnv['core_hours_required'] is bool
            ? workEnv['core_hours_required']
            : true;
        _weekendWorkWilling = workEnv['weekend_work_willing'] is bool
            ? workEnv['weekend_work_willing']
            : false;
        _overtimeWilling = workEnv['overtime_willing'] is bool
            ? workEnv['overtime_willing']
            : false;
        _healthInsuranceImportance =
            workEnv['health_insurance_importance'] as int? ?? 8;
        _retirementBenefitsImportance =
            workEnv['retirement_benefits_importance'] as int? ?? 6;
        _learningBudgetImportance =
            workEnv['learning_budget_importance'] as int? ?? 7;
        _workFromHomeImportance =
            workEnv['work_from_home_importance'] as int? ?? 5;
        _gymMembershipImportance =
            workEnv['gym_membership_importance'] as int? ?? 3;

        // Load Compensation Expectations
        final compensation = _safeMap(profile, 'compensation_expectations');
        _expectedSalaryMinCtrl.text = _safeString(
          compensation,
          'expected_salary_min',
        );
        _expectedSalaryMaxCtrl.text = _safeString(
          compensation,
          'expected_salary_max',
        );
        _expectedSalaryCurrency = _safeString(
          compensation,
          'expected_salary_currency',
          'INR',
        );
        _isSalaryNegotiable = compensation['is_salary_negotiable'] is bool
            ? compensation['is_salary_negotiable']
            : true;
        _expectedFixedSalaryPercentage =
            compensation['expected_fixed_salary_percentage'] as int? ?? 70;
        _expectedVariableSalaryPercentage =
            compensation['expected_variable_salary_percentage'] as int? ?? 30;
        _expectedESOPs = compensation['expected_esops'] is bool
            ? compensation['expected_esops']
            : false;
        _mustHaveBenefits = _safeList(compensation, 'must_have_benefits');
        _niceToHaveBenefits = _safeList(compensation, 'nice_to_have_benefits');
        _desiredPerks = _safeList(compensation, 'desired_perks');
        _expectedAnnualIncrementPercentage =
            compensation['expected_annual_increment_percentage'] as int? ?? 10;

        // Load Job Search Preferences
        final jobSearch = _safeMap(profile, 'job_search_preferences');
        _jobAlertFrequency = _safeString(
          jobSearch,
          'job_alert_frequency',
          'daily',
        );
        _jobAlertChannels = _safeList(jobSearch, 'job_alert_channels', [
          'email',
          'whatsapp',
        ]);
        _autoApplyForMatchingJobs =
            jobSearch['auto_apply_for_matching_jobs'] is bool
            ? jobSearch['auto_apply_for_matching_jobs']
            : false;
        _autoApplyThresholdPercentage =
            jobSearch['auto_apply_threshold_percentage'] as int? ?? 85;
        _requireManualReviewBeforeApply =
            jobSearch['require_manual_review_before_apply'] is bool
            ? jobSearch['require_manual_review_before_apply']
            : true;
        _receiveSimilarJobAlerts =
            jobSearch['receive_similar_job_alerts'] is bool
            ? jobSearch['receive_similar_job_alerts']
            : true;
        _receiveCareerTips = jobSearch['receive_career_tips'] is bool
            ? jobSearch['receive_career_tips']
            : true;
        _receiveMarketUpdates = jobSearch['receive_market_updates'] is bool
            ? jobSearch['receive_market_updates']
            : true;
        _excludeCompanies = _safeList(jobSearch, 'exclude_companies');
        _preferredCompanies = _safeList(jobSearch, 'preferred_companies');
        _noticePeriodDays.text = _safeString(jobSearch, 'notice_period_days');
        _canJoinImmediately = jobSearch['can_join_immediately'] is bool
            ? jobSearch['can_join_immediately']
            : false;

        // Load Educational Goals
        final eduGoals = _safeMap(profile, 'education_goals');
        _wantsHigherEducation = eduGoals['wants_higher_education'] is bool
            ? eduGoals['wants_higher_education']
            : false;
        _interestedDegrees = _safeList(eduGoals, 'interested_degrees');
        _interestedInstitutes = _safeList(eduGoals, 'interested_institutes');
        _willingToStudyAbroad = eduGoals['willing_to_study_abroad'] is bool
            ? eduGoals['willing_to_study_abroad']
            : false;
        _preferredStudyCountries = _safeList(
          eduGoals,
          'preferred_study_countries',
        );
        _educationBudgetCtrl.text = _safeString(eduGoals, 'education_budget');
        _needScholarship = eduGoals['need_scholarship'] is bool
            ? eduGoals['need_scholarship']
            : false;
        _partTimeStudyPreferred = eduGoals['part_time_study_preferred'] is bool
            ? eduGoals['part_time_study_preferred']
            : false;
        _onlineCoursePreferred = eduGoals['online_course_preferred'] is bool
            ? eduGoals['online_course_preferred']
            : true;

        // Load Certification Goals
        final certGoals = _safeMap(profile, 'certification_goals');
        _interestedCertifications = _safeList(
          certGoals,
          'interested_certifications',
        );
        _certificationBudgetCtrl.text = _safeString(
          certGoals,
          'certification_budget',
        );
        _willingToGetCertified = certGoals['willing_to_get_certified'] is bool
            ? certGoals['willing_to_get_certified']
            : true;
        _preferredCertificationMode = _safeString(
          certGoals,
          'preferred_certification_mode',
          'online',
        );

        // Load Learning Preferences
        final learning = _safeMap(profile, 'learning_preferences');
        _preferredLearningMethod = _safeString(
          learning,
          'preferred_learning_method',
          'online',
        );
        _availableLearningHoursPerWeek =
            learning['available_learning_hours_per_week'] as int? ?? 5;
        _learningBudgetPerMonthCtrl.text = _safeString(
          learning,
          'learning_budget_per_month',
        );
        _interestedCertificationsList = _safeList(
          learning,
          'interested_certifications',
        );
        _interestedSkillCategories = _safeList(
          learning,
          'interested_skill_categories',
        );
        _preferredLearningPlatforms = _safeList(
          learning,
          'preferred_learning_platforms',
        );
        _mentorshipRequired = learning['mentorship_required'] is bool
            ? learning['mentorship_required']
            : false;
        _studyGroupInterest = learning['study_group_interest'] is bool
            ? learning['study_group_interest']
            : false;

        // Load Portfolio
        final portfolio = _safeMap(profile, 'portfolio');
        _portfolioGithubUrl.text = _safeString(portfolio, 'github_url');
        _portfolioLinkedinUrl.text = _safeString(portfolio, 'linkedin_url');
        _portfolioWebsite.text = _safeString(portfolio, 'portfolio_website');
        _behanceUrl.text = _safeString(portfolio, 'behance_url');
        _dribbbleUrl.text = _safeString(portfolio, 'dribbble_url');
        _mediumBlog.text = _safeString(portfolio, 'medium_blog');
        _stackoverflowUrl.text = _safeString(portfolio, 'stackoverflow_url');
        _leetcodeUrl.text = _safeString(portfolio, 'leetcode_url');
        _hackerrankUrl.text = _safeString(portfolio, 'hackerrank_url');
        _codeforcesUrl.text = _safeString(portfolio, 'codeforces_url');
        _youtubeChannel.text = _safeString(portfolio, 'youtube_channel');
        _personalBlog.text = _safeString(portfolio, 'personal_blog');

        // Load Income & Expense
        final incomeExpense = _safeMap(profile, 'income_expense');
        _currentMonthlyIncomeCtrl.text = _safeString(
          incomeExpense,
          'current_monthly_income',
        );
        _expectedMonthlyIncomeCtrl.text = _safeString(
          incomeExpense,
          'expected_monthly_income',
        );
        _monthlyExpensesCtrl.text = _safeString(
          incomeExpense,
          'monthly_expenses',
        );
        _monthlySavingsCtrl.text = _safeString(
          incomeExpense,
          'monthly_savings',
        );
        _existingLoans = incomeExpense['existing_loans'] is bool
            ? incomeExpense['existing_loans']
            : false;
        _loanAmountCtrl.text = _safeString(incomeExpense, 'loan_amount');
        _loanEMICtrl.text = _safeString(incomeExpense, 'loan_emi');
        _dependentsCount = incomeExpense['dependents_count'] as int? ?? 0;
        _earningMembersCount =
            incomeExpense['earning_members_count'] as int? ?? 0;

        // Load Additional Details
        final additional = _safeMap(profile, 'additional_details');
        _additionalSoftSkills.text = _safeStringList(additional, 'soft_skills');
        _videoResumeUrl.text = _safeString(additional, 'video_resume_url');

        // Load Skill Assessments
        final skillAssessments = profile['skill_assessments'];
        if (skillAssessments is List) {
          _skillAssessments = List<Map<String, dynamic>>.from(skillAssessments);
        }
      }
    } catch (e) {
      debugPrint("Error loading advanced data: $e");
      if (mounted) {
        showMessage(context, "Error loading advanced data: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Safe helper methods
  String _safeString(
    Map<String, dynamic> map,
    String key, [
    String defaultValue = '',
  ]) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  String _safeStringList(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is List) return value.join('\n');
    return '';
  }

  List<String> _safeList(
    Map<String, dynamic> map,
    String key, [
    List<String> defaultValue = const [],
  ]) {
    final value = map[key];
    if (value is List) {
      return List<String>.from(value.map((e) => e.toString()));
    }
    return defaultValue;
  }

  Map<String, dynamic> _safeMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    return {};
  }

  Future<void> _saveAdvancedData() async {
    setState(() => _isSaving = true);

    try {
      final data = {
        'career_goals': {
          'short_term_goals': _splitText(_shortTermGoals.text),
          'short_term_target_role': _shortTermTargetRole.text.trim(),
          'short_term_target_industry': _shortTermTargetIndustry.text.trim(),
          'short_term_target_salary': int.tryParse(
            _shortTermTargetSalary.text.trim(),
          ),
          'medium_term_goals': _splitText(_mediumTermGoals.text),
          'medium_term_target_role': _mediumTermTargetRole.text.trim(),
          'medium_term_target_industry': _mediumTermTargetIndustry.text.trim(),
          'medium_term_target_salary': int.tryParse(
            _mediumTermTargetSalary.text.trim(),
          ),
          'long_term_goals': _splitText(_longTermGoals.text),
          'long_term_target_role': _longTermTargetRole.text.trim(),
          'long_term_target_industry': _longTermTargetIndustry.text.trim(),
          'long_term_target_salary': int.tryParse(
            _longTermTargetSalary.text.trim(),
          ),
          'dream_role': _dreamRole.text.trim(),
          'dream_company': _dreamCompany.text.trim(),
          'dream_industry': _dreamIndustry.text.trim(),
          'willing_to_change_career': _willingToChangeCareer,
          'interested_in_different_domain': _interestedDifferentDomains,
          'preferred_work_life_balance': _preferredWorkLifeBalance,
          'career_ambition': _careerAmbition,
        },
        'personality_traits': {
          'openness': _openness,
          'conscientiousness': _conscientiousness,
          'extraversion': _extraversion,
          'agreeableness': _agreeableness,
          'neuroticism': _neuroticism,
          'prefers_independent_work': _prefersIndependentWork,
          'prefers_team_work': _prefersTeamWork,
          'prefers_leadership_role': _prefersLeadershipRole,
          'prefers_creative_work': _prefersCreativeWork,
          'prefers_analytical_work': _prefersAnalyticalWork,
          'stress_tolerance': _stressTolerance,
          'deadline_preference': _deadlinePreference,
          'communication_style': _communicationStyle,
          'learning_style': _learningStyle,
        },
        'work_environment_preferences': {
          'preferred_company_size': _preferredCompanySize,
          'preferred_company_type': _preferredCompanyType,
          'preferred_culture': _preferredCulture,
          'desk_type': _deskType,
          'noise_level': _noiseLevel,
          'team_size_preference': _teamSizePreference,
          'collaboration_frequency': _collaborationFrequency,
          'flexible_hours_required': _flexibleHoursRequired,
          'core_hours_required': _coreHoursRequired,
          'weekend_work_willing': _weekendWorkWilling,
          'overtime_willing': _overtimeWilling,
          'health_insurance_importance': _healthInsuranceImportance,
          'retirement_benefits_importance': _retirementBenefitsImportance,
          'learning_budget_importance': _learningBudgetImportance,
          'work_from_home_importance': _workFromHomeImportance,
          'gym_membership_importance': _gymMembershipImportance,
        },
        'compensation_expectations': {
          'expected_salary_min': int.tryParse(
            _expectedSalaryMinCtrl.text.trim(),
          ),
          'expected_salary_max': int.tryParse(
            _expectedSalaryMaxCtrl.text.trim(),
          ),
          'expected_salary_currency': _expectedSalaryCurrency,
          'is_salary_negotiable': _isSalaryNegotiable,
          'expected_fixed_salary_percentage': _expectedFixedSalaryPercentage,
          'expected_variable_salary_percentage':
              _expectedVariableSalaryPercentage,
          'expected_esops': _expectedESOPs,
          'must_have_benefits': _mustHaveBenefits,
          'nice_to_have_benefits': _niceToHaveBenefits,
          'desired_perks': _desiredPerks,
          'expected_annual_increment_percentage':
              _expectedAnnualIncrementPercentage,
        },
        'job_search_preferences': {
          'job_alert_frequency': _jobAlertFrequency,
          'job_alert_channels': _jobAlertChannels,
          'auto_apply_for_matching_jobs': _autoApplyForMatchingJobs,
          'auto_apply_threshold_percentage': _autoApplyThresholdPercentage,
          'require_manual_review_before_apply': _requireManualReviewBeforeApply,
          'receive_similar_job_alerts': _receiveSimilarJobAlerts,
          'receive_career_tips': _receiveCareerTips,
          'receive_market_updates': _receiveMarketUpdates,
          'exclude_companies': _excludeCompanies,
          'preferred_companies': _preferredCompanies,
          'notice_period_days': int.tryParse(_noticePeriodDays.text.trim()),
          'can_join_immediately': _canJoinImmediately,
        },
        'education_goals': {
          'wants_higher_education': _wantsHigherEducation,
          'interested_degrees': _interestedDegrees,
          'interested_institutes': _interestedInstitutes,
          'willing_to_study_abroad': _willingToStudyAbroad,
          'preferred_study_countries': _preferredStudyCountries,
          'education_budget': int.tryParse(_educationBudgetCtrl.text.trim()),
          'need_scholarship': _needScholarship,
          'part_time_study_preferred': _partTimeStudyPreferred,
          'online_course_preferred': _onlineCoursePreferred,
        },
        'certification_goals': {
          'interested_certifications': _interestedCertifications,
          'certification_budget': int.tryParse(
            _certificationBudgetCtrl.text.trim(),
          ),
          'willing_to_get_certified': _willingToGetCertified,
          'preferred_certification_mode': _preferredCertificationMode,
        },
        'learning_preferences': {
          'preferred_learning_method': _preferredLearningMethod,
          'available_learning_hours_per_week': _availableLearningHoursPerWeek,
          'learning_budget_per_month': int.tryParse(
            _learningBudgetPerMonthCtrl.text.trim(),
          ),
          'interested_certifications': _interestedCertificationsList,
          'interested_skill_categories': _interestedSkillCategories,
          'preferred_learning_platforms': _preferredLearningPlatforms,
          'mentorship_required': _mentorshipRequired,
          'study_group_interest': _studyGroupInterest,
        },
        'portfolio': {
          'github_url': _portfolioGithubUrl.text.trim(),
          'linkedin_url': _portfolioLinkedinUrl.text.trim(),
          'portfolio_website': _portfolioWebsite.text.trim(),
          'behance_url': _behanceUrl.text.trim(),
          'dribbble_url': _dribbbleUrl.text.trim(),
          'medium_blog': _mediumBlog.text.trim(),
          'stackoverflow_url': _stackoverflowUrl.text.trim(),
          'leetcode_url': _leetcodeUrl.text.trim(),
          'hackerrank_url': _hackerrankUrl.text.trim(),
          'codeforces_url': _codeforcesUrl.text.trim(),
          'youtube_channel': _youtubeChannel.text.trim(),
          'personal_blog': _personalBlog.text.trim(),
        },
        'income_expense': {
          'current_monthly_income': int.tryParse(
            _currentMonthlyIncomeCtrl.text.trim(),
          ),
          'expected_monthly_income': int.tryParse(
            _expectedMonthlyIncomeCtrl.text.trim(),
          ),
          'monthly_expenses': int.tryParse(_monthlyExpensesCtrl.text.trim()),
          'monthly_savings': int.tryParse(_monthlySavingsCtrl.text.trim()),
          'existing_loans': _existingLoans,
          'loan_amount': int.tryParse(_loanAmountCtrl.text.trim()),
          'loan_emi': int.tryParse(_loanEMICtrl.text.trim()),
          'dependents_count': _dependentsCount,
          'earning_members_count': _earningMembersCount,
        },
        'additional_details': {
          'soft_skills': _additionalSoftSkills.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          'video_resume_url': _videoResumeUrl.text.trim(),
        },
        'skill_assessments': _skillAssessments,
      };

      await UserService.saveProfile(data);

      if (mounted) {
        showMessage(context, "Advanced details saved successfully!");
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) {
        showMessage(context, "Save failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<String> _splitText(String text) {
    return text
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.blue.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    int value,
    int min,
    int max,
    Function(int) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.toInt()),
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildChipField(
    String title,
    List<String> selectedValues,
    List<String> availableOptions,
    Function(String) onToggle,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableOptions.map((option) {
              final isSelected = selectedValues.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => onToggle(option),
                backgroundColor: Colors.grey.shade200,
                selectedColor: Colors.blue.shade100,
                checkmarkColor: Colors.blue,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => onChanged(v.toInt()),
              activeColor: Colors.blue,
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Advanced Profile Details"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blueAccent,
              tabs: const [
                Tab(text: "Career Goals", icon: Icon(Icons.track_changes)),
                Tab(text: "Personality", icon: Icon(Icons.psychology)),
                Tab(text: "Work Preferences", icon: Icon(Icons.work_outline)),
                Tab(text: "Compensation", icon: Icon(Icons.currency_rupee)),
                Tab(text: "Job Search", icon: Icon(Icons.search)),
                Tab(text: "Education & Cert", icon: Icon(Icons.school)),
                Tab(text: "Portfolio", icon: Icon(Icons.link)),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveAdvancedData,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCareerGoalsTab(),
          _buildPersonalityTab(),
          _buildWorkPreferencesTab(),
          _buildCompensationTab(),
          _buildJobSearchTab(),
          _buildEducationCertTab(),
          _buildPortfolioTab(),
        ],
      ),
    );
  }

  Widget _buildCareerGoalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Career Goals",
            Icons.track_changes,
            subtitle: "Define your career aspirations and targets",
          ),
          _buildTextField(
            _shortTermGoals,
            "Short Term Goals (one per line)",
            maxLines: 3,
          ),
          _buildTextField(_shortTermTargetRole, "Short Term Target Role"),
          _buildTextField(
            _shortTermTargetIndustry,
            "Short Term Target Industry",
          ),
          _buildTextField(
            _shortTermTargetSalary,
            "Short Term Target Salary (₹ LPA)",
            keyboardType: TextInputType.number,
          ),
          const Divider(height: 24),
          _buildTextField(
            _mediumTermGoals,
            "Medium Term Goals (one per line)",
            maxLines: 3,
          ),
          _buildTextField(_mediumTermTargetRole, "Medium Term Target Role"),
          _buildTextField(
            _mediumTermTargetIndustry,
            "Medium Term Target Industry",
          ),
          _buildTextField(
            _mediumTermTargetSalary,
            "Medium Term Target Salary (₹ LPA)",
            keyboardType: TextInputType.number,
          ),
          const Divider(height: 24),
          _buildTextField(
            _longTermGoals,
            "Long Term Goals (one per line)",
            maxLines: 3,
          ),
          _buildTextField(_longTermTargetRole, "Long Term Target Role"),
          _buildTextField(_longTermTargetIndustry, "Long Term Target Industry"),
          _buildTextField(
            _longTermTargetSalary,
            "Long Term Target Salary (₹ LPA)",
            keyboardType: TextInputType.number,
          ),
          const Divider(height: 24),
          _buildTextField(_dreamRole, "Dream Role"),
          _buildTextField(_dreamCompany, "Dream Company"),
          _buildTextField(_dreamIndustry, "Dream Industry"),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text("Willing to Change Career"),
            value: _willingToChangeCareer,
            onChanged: (v) => setState(() => _willingToChangeCareer = v),
            contentPadding: EdgeInsets.zero,
          ),
          _buildChipField(
            "Interested Different Domains",
            _interestedDifferentDomains,
            [
              "IT",
              "Finance",
              "Marketing",
              "Healthcare",
              "Education",
              "Manufacturing",
              "Retail",
              "Construction",
              "Agriculture",
              "Media",
            ],
            (value) {
              setState(() {
                if (_interestedDifferentDomains.contains(value)) {
                  _interestedDifferentDomains.remove(value);
                } else {
                  _interestedDifferentDomains.add(value);
                }
              });
            },
          ),
          _buildDropdownField(
            "Preferred Work-Life Balance",
            _preferredWorkLifeBalance,
            _workLifeBalanceOptions
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.replaceAll('_', ' ').toUpperCase()),
                  ),
                )
                .toList(),
            (v) => setState(() => _preferredWorkLifeBalance = v ?? 'balanced'),
          ),
          _buildDropdownField(
            "Career Ambition",
            _careerAmbition,
            _careerAmbitionOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _careerAmbition = v ?? 'grow'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPersonalityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Personality Traits",
            Icons.psychology,
            subtitle: "How you work and interact",
          ),
          _buildSliderRow(
            "Openness to Experience",
            _openness ?? 5,
            1,
            10,
            (v) => setState(() => _openness = v),
          ),
          _buildSliderRow(
            "Conscientiousness",
            _conscientiousness ?? 5,
            1,
            10,
            (v) => setState(() => _conscientiousness = v),
          ),
          _buildSliderRow(
            "Extraversion",
            _extraversion ?? 5,
            1,
            10,
            (v) => setState(() => _extraversion = v),
          ),
          _buildSliderRow(
            "Agreeableness",
            _agreeableness ?? 5,
            1,
            10,
            (v) => setState(() => _agreeableness = v),
          ),
          _buildSliderRow(
            "Neuroticism",
            _neuroticism ?? 5,
            1,
            10,
            (v) => setState(() => _neuroticism = v),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Independent Work"),
                  value: _prefersIndependentWork,
                  onChanged: (v) =>
                      setState(() => _prefersIndependentWork = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Team Work"),
                  value: _prefersTeamWork,
                  onChanged: (v) =>
                      setState(() => _prefersTeamWork = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Leadership Role"),
                  value: _prefersLeadershipRole,
                  onChanged: (v) =>
                      setState(() => _prefersLeadershipRole = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Creative Work"),
                  value: _prefersCreativeWork,
                  onChanged: (v) =>
                      setState(() => _prefersCreativeWork = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          CheckboxListTile(
            title: const Text("Analytical Work"),
            value: _prefersAnalyticalWork,
            onChanged: (v) =>
                setState(() => _prefersAnalyticalWork = v ?? false),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 24),
          _buildDropdownField(
            "Stress Tolerance",
            _stressTolerance,
            _stressToleranceOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _stressTolerance = v ?? 'medium'),
          ),
          _buildDropdownField(
            "Deadline Preference",
            _deadlinePreference,
            _deadlineOptions
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.replaceAll('_', ' ').toUpperCase()),
                  ),
                )
                .toList(),
            (v) => setState(() => _deadlinePreference = v ?? 'flexible'),
          ),
          _buildDropdownField(
            "Communication Style",
            _communicationStyle,
            _communicationStyleOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _communicationStyle = v ?? 'balanced'),
          ),
          _buildDropdownField(
            "Learning Style",
            _learningStyle,
            _learningStyleOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _learningStyle = v ?? 'visual'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildWorkPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Work Environment",
            Icons.work_outline,
            subtitle: "Your ideal workplace settings",
          ),
          _buildDropdownField(
            "Preferred Company Size",
            _preferredCompanySize,
            _companySizeOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _preferredCompanySize = v ?? 'any'),
          ),
          _buildChipField(
            "Preferred Company Type",
            _preferredCompanyType,
            _companyTypeOptions,
            (value) {
              setState(() {
                if (_preferredCompanyType.contains(value)) {
                  _preferredCompanyType.remove(value);
                } else {
                  _preferredCompanyType.add(value);
                }
              });
            },
          ),
          _buildChipField(
            "Preferred Culture",
            _preferredCulture,
            [
              "Collaborative",
              "Competitive",
              "Innovative",
              "Structured",
              "Casual",
              "Formal",
              "Fast-paced",
            ],
            (value) {
              setState(() {
                if (_preferredCulture.contains(value)) {
                  _preferredCulture.remove(value);
                } else {
                  _preferredCulture.add(value);
                }
              });
            },
          ),
          _buildDropdownField(
            "Desk Type",
            _deskType,
            ["any", "private", "open", "cubicle", "hot_desk"]
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(o.replaceAll('_', ' ').toUpperCase()),
                  ),
                )
                .toList(),
            (v) => setState(() => _deskType = v ?? 'any'),
          ),
          _buildDropdownField(
            "Noise Level",
            _noiseLevel,
            ["quiet", "moderate", "loud", "any"]
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _noiseLevel = v ?? 'moderate'),
          ),
          _buildDropdownField(
            "Team Size Preference",
            _teamSizePreference,
            ["small", "medium", "large", "any"]
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _teamSizePreference = v ?? 'medium'),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Flexible Hours"),
                  value: _flexibleHoursRequired,
                  onChanged: (v) =>
                      setState(() => _flexibleHoursRequired = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Core Hours"),
                  value: _coreHoursRequired,
                  onChanged: (v) =>
                      setState(() => _coreHoursRequired = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Weekend Work OK"),
                  value: _weekendWorkWilling,
                  onChanged: (v) =>
                      setState(() => _weekendWorkWilling = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text("Overtime OK"),
                  value: _overtimeWilling,
                  onChanged: (v) =>
                      setState(() => _overtimeWilling = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            "Benefit Importance (1-10)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          _buildRatingRow(
            "Health Insurance",
            _healthInsuranceImportance,
            (v) => setState(() => _healthInsuranceImportance = v),
          ),
          _buildRatingRow(
            "Retirement Benefits",
            _retirementBenefitsImportance,
            (v) => setState(() => _retirementBenefitsImportance = v),
          ),
          _buildRatingRow(
            "Learning Budget",
            _learningBudgetImportance,
            (v) => setState(() => _learningBudgetImportance = v),
          ),
          _buildRatingRow(
            "Work From Home",
            _workFromHomeImportance,
            (v) => setState(() => _workFromHomeImportance = v),
          ),
          _buildRatingRow(
            "Gym Membership",
            _gymMembershipImportance,
            (v) => setState(() => _gymMembershipImportance = v),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCompensationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Compensation",
            Icons.currency_rupee,
            subtitle: "Salary expectations and benefits",
          ),
          _buildTextField(
            _expectedSalaryMinCtrl,
            "Expected Salary Min (₹ LPA)",
            keyboardType: TextInputType.number,
          ),
          _buildTextField(
            _expectedSalaryMaxCtrl,
            "Expected Salary Max (₹ LPA)",
            keyboardType: TextInputType.number,
          ),
          _buildDropdownField(
            "Currency",
            _expectedSalaryCurrency,
            [
              "INR",
              "USD",
              "EUR",
            ].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            (v) => setState(() => _expectedSalaryCurrency = v ?? 'INR'),
          ),
          SwitchListTile(
            title: const Text("Salary Negotiable"),
            value: _isSalaryNegotiable,
            onChanged: (v) => setState(() => _isSalaryNegotiable = v),
            contentPadding: EdgeInsets.zero,
          ),
          _buildSliderRow(
            "Fixed Salary %",
            _expectedFixedSalaryPercentage,
            0,
            100,
            (v) => setState(() => _expectedFixedSalaryPercentage = v),
          ),
          _buildSliderRow(
            "Variable Salary %",
            _expectedVariableSalaryPercentage,
            0,
            100,
            (v) => setState(() => _expectedVariableSalaryPercentage = v),
          ),
          CheckboxListTile(
            title: const Text("ESOPs Expected"),
            value: _expectedESOPs,
            onChanged: (v) => setState(() => _expectedESOPs = v ?? false),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 24),
          _buildChipField(
            "Must Have Benefits",
            _mustHaveBenefits,
            [
              "Health Insurance",
              "Provident Fund",
              "Gratuity",
              "Bonus",
              "Stock Options",
              "Vehicle",
              "Accommodation",
              "Meals",
            ],
            (value) {
              setState(() {
                if (_mustHaveBenefits.contains(value)) {
                  _mustHaveBenefits.remove(value);
                } else {
                  _mustHaveBenefits.add(value);
                }
              });
            },
          ),
          _buildChipField(
            "Nice to Have Benefits",
            _niceToHaveBenefits,
            [
              "Flexible Hours",
              "Remote Work",
              "Learning Budget",
              "Gym",
              "Child Care",
              "Transport",
              "Phone",
              "Laptop",
            ],
            (value) {
              setState(() {
                if (_niceToHaveBenefits.contains(value)) {
                  _niceToHaveBenefits.remove(value);
                } else {
                  _niceToHaveBenefits.add(value);
                }
              });
            },
          ),
          _buildChipField(
            "Desired Perks",
            _desiredPerks,
            [
              "Free Snacks",
              "Team Outings",
              "Annual Trip",
              "Birthday Leave",
              "Work Anniversary",
              "Courses",
            ],
            (value) {
              setState(() {
                if (_desiredPerks.contains(value)) {
                  _desiredPerks.remove(value);
                } else {
                  _desiredPerks.add(value);
                }
              });
            },
          ),
          _buildSliderRow(
            "Expected Annual Increment %",
            _expectedAnnualIncrementPercentage,
            0,
            30,
            (v) => setState(() => _expectedAnnualIncrementPercentage = v),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildJobSearchTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Job Search",
            Icons.search,
            subtitle: "How you want to find jobs",
          ),
          _buildDropdownField(
            "Job Alert Frequency",
            _jobAlertFrequency,
            _jobAlertFrequencyOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _jobAlertFrequency = v ?? 'daily'),
          ),
          _buildChipField(
            "Alert Channels",
            _jobAlertChannels,
            ["email", "whatsapp", "sms", "push"],
            (value) {
              setState(() {
                if (_jobAlertChannels.contains(value)) {
                  _jobAlertChannels.remove(value);
                } else {
                  _jobAlertChannels.add(value);
                }
              });
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            title: const Text("Auto-apply for matching jobs"),
            value: _autoApplyForMatchingJobs,
            onChanged: (v) => setState(() => _autoApplyForMatchingJobs = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_autoApplyForMatchingJobs)
            _buildSliderRow(
              "Auto-apply threshold %",
              _autoApplyThresholdPercentage,
              50,
              95,
              (v) => setState(() => _autoApplyThresholdPercentage = v),
            ),
          SwitchListTile(
            title: const Text("Manual review before apply"),
            value: _requireManualReviewBeforeApply,
            onChanged: (v) =>
                setState(() => _requireManualReviewBeforeApply = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 24),
          SwitchListTile(
            title: const Text("Receive similar job alerts"),
            value: _receiveSimilarJobAlerts,
            onChanged: (v) => setState(() => _receiveSimilarJobAlerts = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text("Receive career tips"),
            value: _receiveCareerTips,
            onChanged: (v) => setState(() => _receiveCareerTips = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text("Receive market updates"),
            value: _receiveMarketUpdates,
            onChanged: (v) => setState(() => _receiveMarketUpdates = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 24),
          _buildChipField(
            "Exclude Companies",
            _excludeCompanies,
            [],
            (value) => setState(() => _excludeCompanies.add(value)),
          ),
          _buildChipField(
            "Preferred Companies",
            _preferredCompanies,
            [],
            (value) => setState(() => _preferredCompanies.add(value)),
          ),
          _buildTextField(
            _noticePeriodDays,
            "Notice Period (days)",
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            title: const Text("Can join immediately"),
            value: _canJoinImmediately,
            onChanged: (v) => setState(() => _canJoinImmediately = v),
            contentPadding: EdgeInsets.zero,
          ),
          _buildTextField(_availabilityDate, "Availability Date (YYYY-MM-DD)"),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildEducationCertTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Education Goals",
            Icons.school,
            subtitle: "Higher education plans",
          ),
          SwitchListTile(
            title: const Text("Wants Higher Education"),
            value: _wantsHigherEducation,
            onChanged: (v) => setState(() => _wantsHigherEducation = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (_wantsHigherEducation) ...[
            _buildChipField(
              "Interested Degrees",
              _interestedDegrees,
              ["MBA", "M.Tech", "M.Sc", "PhD", "PG Diploma", "Certificate"],
              (value) {
                setState(() {
                  if (_interestedDegrees.contains(value)) {
                    _interestedDegrees.remove(value);
                  } else {
                    _interestedDegrees.add(value);
                  }
                });
              },
            ),
            _buildChipField(
              "Interested Institutes",
              _interestedInstitutes,
              ["IIT", "IIM", "NIT", "IISc", "BITS", "DTU", "JNU", "DU"],
              (value) {
                setState(() {
                  if (_interestedInstitutes.contains(value)) {
                    _interestedInstitutes.remove(value);
                  } else {
                    _interestedInstitutes.add(value);
                  }
                });
              },
            ),
            SwitchListTile(
              title: const Text("Willing to study abroad"),
              value: _willingToStudyAbroad,
              onChanged: (v) => setState(() => _willingToStudyAbroad = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_willingToStudyAbroad)
              _buildChipField(
                "Preferred Countries",
                _preferredStudyCountries,
                [
                  "USA",
                  "UK",
                  "Canada",
                  "Australia",
                  "Germany",
                  "Singapore",
                  "UAE",
                ],
                (value) {
                  setState(() {
                    if (_preferredStudyCountries.contains(value)) {
                      _preferredStudyCountries.remove(value);
                    } else {
                      _preferredStudyCountries.add(value);
                    }
                  });
                },
              ),
            _buildTextField(
              _educationBudgetCtrl,
              "Education Budget (₹)",
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              title: const Text("Need Scholarship"),
              value: _needScholarship,
              onChanged: (v) => setState(() => _needScholarship = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text("Part-time study preferred"),
              value: _partTimeStudyPreferred,
              onChanged: (v) => setState(() => _partTimeStudyPreferred = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text("Online course preferred"),
              value: _onlineCoursePreferred,
              onChanged: (v) => setState(() => _onlineCoursePreferred = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const Divider(height: 24),
          _buildSectionHeader(
            "Certification Goals",
            Icons.verified,
            subtitle: "Professional certifications",
          ),
          _buildChipField(
            "Interested Certifications",
            _interestedCertifications,
            [
              "AWS",
              "Azure",
              "PMP",
              "Six Sigma",
              "Scrum Master",
              "CEH",
              "CISSP",
              "CPA",
              "CFA",
              "FRM",
            ],
            (value) {
              setState(() {
                if (_interestedCertifications.contains(value)) {
                  _interestedCertifications.remove(value);
                } else {
                  _interestedCertifications.add(value);
                }
              });
            },
          ),
          _buildTextField(
            _certificationBudgetCtrl,
            "Certification Budget (₹)",
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            title: const Text("Willing to get certified"),
            value: _willingToGetCertified,
            onChanged: (v) => setState(() => _willingToGetCertified = v),
            contentPadding: EdgeInsets.zero,
          ),
          _buildDropdownField(
            "Preferred Mode",
            _preferredCertificationMode,
            _certificationModeOptions
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _preferredCertificationMode = v ?? 'online'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            "Portfolio Links",
            Icons.link,
            subtitle: "Showcase your work online",
          ),
          _buildTextField(_portfolioGithubUrl, "GitHub URL"),
          _buildTextField(_portfolioLinkedinUrl, "LinkedIn URL"),
          _buildTextField(_portfolioWebsite, "Portfolio Website"),
          _buildTextField(_behanceUrl, "Behance URL"),
          _buildTextField(_dribbbleUrl, "Dribbble URL"),
          _buildTextField(_mediumBlog, "Medium Blog"),
          _buildTextField(_stackoverflowUrl, "StackOverflow URL"),
          _buildTextField(_leetcodeUrl, "LeetCode URL"),
          _buildTextField(_hackerrankUrl, "HackerRank URL"),
          _buildTextField(_codeforcesUrl, "Codeforces URL"),
          _buildTextField(_youtubeChannel, "YouTube Channel"),
          _buildTextField(_personalBlog, "Personal Blog"),
          const Divider(height: 24),
          _buildSectionHeader(
            "Learning Preferences",
            Icons.school,
            subtitle: "How you like to learn",
          ),
          _buildDropdownField(
            "Preferred Learning Method",
            _preferredLearningMethod,
            ["online", "offline", "hybrid"]
                .map(
                  (o) =>
                      DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
                )
                .toList(),
            (v) => setState(() => _preferredLearningMethod = v ?? 'online'),
          ),
          _buildSliderRow(
            "Available Learning Hours/Week",
            _availableLearningHoursPerWeek,
            0,
            40,
            (v) => setState(() => _availableLearningHoursPerWeek = v),
          ),
          _buildTextField(
            _learningBudgetPerMonthCtrl,
            "Learning Budget/Month (₹)",
            keyboardType: TextInputType.number,
          ),
          _buildChipField(
            "Preferred Learning Platforms",
            _preferredLearningPlatforms,
            [
              "Coursera",
              "Udemy",
              "edX",
              "LinkedIn Learning",
              "Pluralsight",
              "Skillshare",
              "YouTube",
            ],
            (value) {
              setState(() {
                if (_preferredLearningPlatforms.contains(value)) {
                  _preferredLearningPlatforms.remove(value);
                } else {
                  _preferredLearningPlatforms.add(value);
                }
              });
            },
          ),
          SwitchListTile(
            title: const Text("Mentorship Required"),
            value: _mentorshipRequired,
            onChanged: (v) => setState(() => _mentorshipRequired = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text("Study Group Interest"),
            value: _studyGroupInterest,
            onChanged: (v) => setState(() => _studyGroupInterest = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    Function(T?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        // ✅ FIXED: Changed from 'value' to 'initialValue' to avoid deprecation warning
        initialValue: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
