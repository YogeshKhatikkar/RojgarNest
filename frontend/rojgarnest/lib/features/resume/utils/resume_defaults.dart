// lib/features/resume/utils/resume_defaults.dart
// ============================================================
// ✅ COMMON PROFESSIONAL SUMMARY & CAREER OBJECTIVE
// ✅ Used when profile data is empty
// ✅ Universal for ALL education levels, job types, and users
// ✅ Attractive, professional, and career-focused
// ============================================================

class ResumeDefaults {
  // ============================================================
  // ✅ COMMON PROFESSIONAL SUMMARY (Universal)
  // ============================================================
  static const String commonProfessionalSummary =
      "Motivated and detail-oriented professional with a strong foundation in problem-solving, "
      "communication, and teamwork. Passionate about continuous learning and eager to contribute "
      "to organizational success while growing both personally and professionally. Possesses the "
      "ability to adapt quickly to new environments, work effectively under pressure, and deliver "
      "high-quality results within deadlines. Committed to building a rewarding career through "
      "dedication, integrity, and a results-driven approach.";

  // ============================================================
  // ✅ COMMON CAREER OBJECTIVE (Universal)
  // ============================================================
  static const String commonCareerObjective =
      "Seeking a challenging and growth-oriented position in a reputable organization where I can "
      "utilize my skills, knowledge, and enthusiasm to contribute meaningfully to the company's "
      "goals. Aspiring to enhance my professional expertise, take on increasing responsibilities, "
      "and achieve both personal and organizational success. Eager to work in a dynamic environment "
      "that encourages innovation, continuous learning, and career advancement.";

  // ============================================================
  // ✅ SHORT PROFESSIONAL SUMMARY (For compact resumes)
  // ============================================================
  static const String shortProfessionalSummary =
      "Enthusiastic and dedicated professional with strong communication, teamwork, and "
      "problem-solving skills. Committed to continuous learning and delivering quality results.";

  // ============================================================
  // ✅ SHORT CAREER OBJECTIVE (For compact resumes)
  // ============================================================
  static const String shortCareerObjective =
      "Seeking a challenging role to apply my skills, contribute to organizational growth, "
      "and advance professionally.";

  // ============================================================
  // ✅ EXPERIENCED PROFESSIONAL SUMMARY (3+ years)
  // ============================================================
  static const String experiencedProfessionalSummary =
      "Results-driven professional with proven experience in delivering high-quality work, "
      "managing multiple priorities, and collaborating effectively with cross-functional teams. "
      "Demonstrated ability to analyze complex problems, implement effective solutions, and "
      "drive measurable results. Strong leadership qualities with a commitment to mentoring "
      "team members and fostering a positive work environment.";

  // ============================================================
  // ✅ EXPERIENCED CAREER OBJECTIVE (3+ years)
  // ============================================================
  static const String experiencedCareerObjective =
      "Seeking a senior-level position in a growth-focused organization where I can leverage "
      "my extensive experience, leadership skills, and industry knowledge to drive organizational "
      "success. Committed to delivering exceptional results, mentoring junior team members, and "
      "contributing to strategic initiatives that align with business objectives.";

  // ============================================================
  // ✅ FRESHER PROFESSIONAL SUMMARY (0 years)
  // ============================================================
  static const String fresherProfessionalSummary =
      "Enthusiastic and quick-learning fresher with a solid academic foundation and a strong "
      "desire to build a successful career. Possesses excellent communication skills, a positive "
      "attitude, and the ability to grasp new concepts quickly. Eager to apply theoretical "
      "knowledge in practical scenarios and contribute to organizational goals while gaining "
      "valuable industry experience.";

  // ============================================================
  // ✅ FRESHER CAREER OBJECTIVE (0 years)
  // ============================================================
  static const String fresherCareerObjective =
      "Seeking an entry-level position in a reputable organization where I can apply my academic "
      "knowledge, develop practical skills, and grow professionally. Eager to learn from "
      "experienced professionals, contribute to team success, and build a strong foundation "
      "for a rewarding career.";

  // ============================================================
  // ✅ GET PROFESSIONAL SUMMARY BASED ON PROFILE
  // ============================================================
  static String getProfessionalSummary({
    String? existingSummary,
    int experienceYears = 0,
    bool isFresher = true,
  }) {
    // If existing summary is valid, return it
    if (existingSummary != null && existingSummary.trim().isNotEmpty) {
      return existingSummary.trim();
    }

    // Return based on experience level
    if (isFresher || experienceYears == 0) {
      return fresherProfessionalSummary;
    } else if (experienceYears >= 3) {
      return experiencedProfessionalSummary;
    } else {
      return commonProfessionalSummary;
    }
  }

  // ============================================================
  // ✅ GET CAREER OBJECTIVE BASED ON PROFILE
  // ============================================================
  static String getCareerObjective({
    String? existingObjective,
    int experienceYears = 0,
    bool isFresher = true,
  }) {
    // If existing objective is valid, return it
    if (existingObjective != null && existingObjective.trim().isNotEmpty) {
      return existingObjective.trim();
    }

    // Return based on experience level
    if (isFresher || experienceYears == 0) {
      return fresherCareerObjective;
    } else if (experienceYears >= 3) {
      return experiencedCareerObjective;
    } else {
      return commonCareerObjective;
    }
  }

  // ============================================================
  // ✅ GET SHORT SUMMARY (For compact formats)
  // ============================================================
  static String getShortProfessionalSummary({String? existingSummary}) {
    if (existingSummary != null && existingSummary.trim().isNotEmpty) {
      return existingSummary.trim();
    }
    return shortProfessionalSummary;
  }

  // ============================================================
  // ✅ GET SHORT OBJECTIVE (For compact formats)
  // ============================================================
  static String getShortCareerObjective({String? existingObjective}) {
    if (existingObjective != null && existingObjective.trim().isNotEmpty) {
      return existingObjective.trim();
    }
    return shortCareerObjective;
  }
}