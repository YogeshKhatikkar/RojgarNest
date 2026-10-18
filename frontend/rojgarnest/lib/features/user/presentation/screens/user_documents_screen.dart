// lib/features/user/presentation/screens/user_documents_screen.dart
// ✅ COMPLETE AI-BASED MODERN DESIGN
// ✅ FIXED: Dropdown list with white background and black text
// ✅ FIXED: Loading animation on page load
// ✅ FIXED: Works on Mobile and Web
// ✅ FIXED: Profile photo upload/delete now syncs to BOTH providers
//         → ProfileStateService (global source of truth)
//         → UserProfileProvider (ResumeScreen)
// ✅ Complete file — no lines skipped

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/widgets/file_viewer_screen.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';
import 'package:rojgarnest/features/user/providers/user_profile_provider.dart';

class UserDocumentsScreen extends StatefulWidget {
  const UserDocumentsScreen({super.key});

  @override
  State<UserDocumentsScreen> createState() => _UserDocumentsScreenState();
}

class _UserDocumentsScreenState extends State<UserDocumentsScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  String? _userEmail;

  // ==================== COMPLETE DOCUMENT TYPES LIST ====================
  final List<Map<String, dynamic>> _documentTypes = const [
    // ==================== EDUCATIONAL DOCUMENTS ====================
    {'name': '10th Marksheet', 'key': 'tenth_marksheet', 'icon': Icons.school, 'category': 'Education'},
    {'name': '10th Certificate', 'key': 'tenth_certificate', 'icon': Icons.school, 'category': 'Education'},
    {'name': '12th Marksheet', 'key': 'twelfth_marksheet', 'icon': Icons.school, 'category': 'Education'},
    {'name': '12th Certificate', 'key': 'twelfth_certificate', 'icon': Icons.school, 'category': 'Education'},
    {'name': 'Diploma Certificate', 'key': 'diploma_certificate', 'icon': Icons.school, 'category': 'Education'},
    {'name': 'Diploma Marksheet', 'key': 'diploma_marksheet', 'icon': Icons.school, 'category': 'Education'},
    {'name': 'Graduation Degree', 'key': 'graduation_degree', 'icon': Icons.school, 'category': 'Education'},
    {'name': 'Graduation Marksheet', 'key': 'graduation_marksheet', 'icon': Icons.school, 'category': 'Education'},
    {'name': 'Post Graduation Degree', 'key': 'post_graduation_degree', 'icon': Icons.school_rounded, 'category': 'Education'},
    {'name': 'Post Graduation Marksheet', 'key': 'post_graduation_marksheet', 'icon': Icons.school, 'category': 'Education'},
    {'name': 'PhD Certificate', 'key': 'phd_certificate', 'icon': Icons.psychology, 'category': 'Education'},
    {'name': 'PhD Thesis', 'key': 'phd_thesis', 'icon': Icons.description, 'category': 'Education'},
    {'name': 'ITI Certificate', 'key': 'iti_certificate', 'icon': Icons.hardware, 'category': 'Education'},
    {'name': 'Vocational Training Certificate', 'key': 'vocational_certificate', 'icon': Icons.build, 'category': 'Education'},
    {'name': 'Skill Development Certificate', 'key': 'skill_development_certificate', 'icon': Icons.workspace_premium, 'category': 'Education'},

    // ==================== PROFESSIONAL DOCUMENTS ====================
    {'name': 'Resume / CV', 'key': 'resume_url', 'icon': Icons.description, 'category': 'Professional'},
    {'name': 'Experience Certificate', 'key': 'experience_certificate', 'icon': Icons.work, 'category': 'Professional'},
    {'name': 'Experience Letter', 'key': 'experience_letter_url', 'icon': Icons.work_history, 'category': 'Professional'},
    {'name': 'Previous Employment Proof', 'key': 'previous_employment_proof', 'icon': Icons.business, 'category': 'Professional'},
    {'name': 'Service Certificate', 'key': 'service_certificate', 'icon': Icons.assignment, 'category': 'Professional'},
    {'name': 'Offer Letter', 'key': 'offer_letter_url', 'icon': Icons.description, 'category': 'Professional'},
    {'name': 'Appointment Letter', 'key': 'appointment_letter', 'icon': Icons.assignment, 'category': 'Professional'},
    {'name': 'Salary Slip', 'key': 'salary_slip_url', 'icon': Icons.receipt, 'category': 'Professional'},
    {'name': 'Salary Certificate', 'key': 'salary_certificate', 'icon': Icons.currency_rupee, 'category': 'Income'},
    {'name': 'Relieving Letter', 'key': 'relieving_letter', 'icon': Icons.exit_to_app, 'category': 'Professional'},
    {'name': 'Promotion Letter', 'key': 'promotion_letter', 'icon': Icons.trending_up, 'category': 'Professional'},
    {'name': 'Increment Letter', 'key': 'increment_letter', 'icon': Icons.trending_up, 'category': 'Professional'},
    {'name': 'Training Certificate', 'key': 'training_certificate', 'icon': Icons.assignment_turned_in, 'category': 'Professional'},
    {'name': 'Internship Certificate', 'key': 'internship_certificate', 'icon': Icons.school, 'category': 'Professional'},
    {'name': 'Apprenticeship Certificate', 'key': 'apprenticeship_certificate', 'icon': Icons.handshake, 'category': 'Professional'},

    // ==================== IDENTITY DOCUMENTS ====================
    {'name': 'Profile Photo', 'key': 'profile_photo_url', 'icon': Icons.person, 'category': 'Identity'},
    {'name': 'Aadhaar Card (Front)', 'key': 'aadhaar_front', 'icon': Icons.credit_card, 'category': 'Identity'},
    {'name': 'Aadhaar Card (Back)', 'key': 'aadhaar_back', 'icon': Icons.credit_card, 'category': 'Identity'},
    {'name': 'PAN Card', 'key': 'pan_url', 'icon': Icons.credit_card, 'category': 'Identity'},
    {'name': 'Passport', 'key': 'passport_url', 'icon': Icons.airplane_ticket, 'category': 'Identity'},
    {'name': 'Voter ID', 'key': 'voter_id_url', 'icon': Icons.how_to_vote, 'category': 'Identity'},
    {'name': 'Driving License', 'key': 'driving_license_url', 'icon': Icons.drive_eta, 'category': 'Identity'},
    {'name': 'Ration Card', 'key': 'ration_card', 'icon': Icons.card_giftcard, 'category': 'Identity'},
    {'name': 'NPR Card', 'key': 'npr_card', 'icon': Icons.badge, 'category': 'Identity'},

    // ==================== CASTE & RESERVATION DOCUMENTS ====================
    {'name': 'Caste Certificate (General/UR)', 'key': 'caste_certificate_general', 'icon': Icons.assignment_ind, 'category': 'Caste'},
    {'name': 'Caste Certificate (OBC)', 'key': 'caste_certificate_obc', 'icon': Icons.assignment_ind, 'category': 'Caste'},
    {'name': 'Caste Certificate (SC)', 'key': 'caste_certificate_sc', 'icon': Icons.assignment_ind, 'category': 'Caste'},
    {'name': 'Caste Certificate (ST)', 'key': 'caste_certificate_st', 'icon': Icons.assignment_ind, 'category': 'Caste'},
    {'name': 'EWS Certificate', 'key': 'ews_certificate', 'icon': Icons.attach_money, 'category': 'Caste'},
    {'name': 'Non-Creamy Layer Certificate', 'key': 'non_creamy_layer', 'icon': Icons.assignment, 'category': 'Caste'},
    {'name': 'Caste Validity Certificate', 'key': 'caste_validity', 'icon': Icons.verified, 'category': 'Caste'},

    // ==================== DISABILITY DOCUMENTS ====================
    {'name': 'Disability Certificate', 'key': 'disability_certificate_url', 'icon': Icons.accessible, 'category': 'Disability'},
    {'name': 'Medical Certificate (Physical)', 'key': 'medical_certificate_physical', 'icon': Icons.medical_services, 'category': 'Disability'},
    {'name': 'Hearing Disability Certificate', 'key': 'hearing_disability', 'icon': Icons.hearing, 'category': 'Disability'},
    {'name': 'Visual Disability Certificate', 'key': 'visual_disability', 'icon': Icons.visibility_off, 'category': 'Disability'},
    {'name': 'Learning Disability Certificate', 'key': 'learning_disability', 'icon': Icons.psychology, 'category': 'Disability'},
    {'name': 'Mental Disability Certificate', 'key': 'mental_disability', 'icon': Icons.health_and_safety, 'category': 'Disability'},
    {'name': 'Multiple Disability Certificate', 'key': 'multiple_disability', 'icon': Icons.accessibility_new, 'category': 'Disability'},
    {'name': 'Disability ID Card', 'key': 'disability_id_card', 'icon': Icons.badge, 'category': 'Disability'},

    // ==================== INCOME & FINANCIAL DOCUMENTS ====================
    {'name': 'Income Certificate', 'key': 'income_certificate_url', 'icon': Icons.attach_money, 'category': 'Income'},
    {'name': 'Income Tax Return (ITR)', 'key': 'income_tax_return', 'icon': Icons.request_quote, 'category': 'Income'},
    {'name': 'Form 16', 'key': 'form_16', 'icon': Icons.description, 'category': 'Income'},
    {'name': 'Bank Passbook/Statement', 'key': 'bank_statement', 'icon': Icons.account_balance, 'category': 'Income'},
    {'name': 'Pension Certificate', 'key': 'pension_certificate', 'icon': Icons.elderly, 'category': 'Income'},
    {'name': 'Fixed Deposit Certificate', 'key': 'fd_certificate', 'icon': Icons.savings, 'category': 'Income'},

    // ==================== RESIDENCE DOCUMENTS ====================
    {'name': 'Domicile Certificate', 'key': 'domicile_certificate', 'icon': Icons.home, 'category': 'Residence'},
    {'name': 'Residence Certificate', 'key': 'residence_certificate', 'icon': Icons.home, 'category': 'Residence'},
    {'name': 'Electricity Bill', 'key': 'electricity_bill', 'icon': Icons.electric_bolt, 'category': 'Residence'},
    {'name': 'Water Bill', 'key': 'water_bill', 'icon': Icons.water_drop, 'category': 'Residence'},
    {'name': 'Gas Bill', 'key': 'gas_bill', 'icon': Icons.fireplace, 'category': 'Residence'},
    {'name': 'Rent Agreement', 'key': 'rent_agreement', 'icon': Icons.receipt, 'category': 'Residence'},
    {'name': 'Property Document', 'key': 'property_document', 'icon': Icons.real_estate_agent, 'category': 'Residence'},

    // ==================== FAMILY DOCUMENTS ====================
    {'name': 'Birth Certificate', 'key': 'birth_certificate', 'icon': Icons.celebration, 'category': 'Family'},
    {'name': 'Marriage Certificate', 'key': 'marriage_certificate', 'icon': Icons.favorite, 'category': 'Family'},
    {'name': 'Family Member ID', 'key': 'family_member_id', 'icon': Icons.family_restroom, 'category': 'Family'},
    {'name': 'Dependent Certificate', 'key': 'dependent_certificate', 'icon': Icons.people, 'category': 'Family'},
    {'name': 'Family Pension Certificate', 'key': 'family_pension', 'icon': Icons.elderly, 'category': 'Family'},
    {'name': 'Survivor Certificate', 'key': 'survivor_certificate', 'icon': Icons.family_restroom, 'category': 'Family'},

    // ==================== GOVERNMENT SCHEME DOCUMENTS ====================
    {'name': 'Job Seeker Registration', 'key': 'job_seeker_registration', 'icon': Icons.assignment, 'category': 'Government'},
    {'name': 'Employment Exchange Card', 'key': 'employment_exchange_card', 'icon': Icons.badge, 'category': 'Government'},
    {'name': 'National Career Service ID', 'key': 'ncs_id', 'icon': Icons.work, 'category': 'Government'},
    {'name': 'NREGA Job Card', 'key': 'nrega_card', 'icon': Icons.work, 'category': 'Government'},
    {'name': 'PMAY Certificate', 'key': 'pmay_certificate', 'icon': Icons.home, 'category': 'Government'},
    {'name': 'PMJJBY Certificate', 'key': 'pmjjby_certificate', 'icon': Icons.health_and_safety, 'category': 'Government'},
    {'name': 'PMSBY Certificate', 'key': 'pmsby_certificate', 'icon': Icons.health_and_safety, 'category': 'Government'},
    {'name': 'APY Enrollment', 'key': 'apy_enrollment', 'icon': Icons.elderly, 'category': 'Government'},

    // ==================== PROFESSIONAL CERTIFICATIONS ====================
    {'name': 'Professional Certification', 'key': 'professional_certification', 'icon': Icons.verified, 'category': 'Certification'},
    {'name': 'Skill Development Certificate', 'key': 'skill_certificate', 'icon': Icons.build, 'category': 'Certification'},
    {'name': 'Computer Course Certificate', 'key': 'computer_certificate', 'icon': Icons.computer, 'category': 'Certification'},
    {'name': 'Language Proficiency Certificate', 'key': 'language_certificate', 'icon': Icons.language, 'category': 'Certification'},
    {'name': 'Soft Skills Certificate', 'key': 'soft_skills_certificate', 'icon': Icons.people, 'category': 'Certification'},
    {'name': 'Leadership Certificate', 'key': 'leadership_certificate', 'icon': Icons.leaderboard, 'category': 'Certification'},
    {'name': 'Project Management Certificate', 'key': 'project_management_certificate', 'icon': Icons.task, 'category': 'Certification'},
    {'name': 'Digital Marketing Certificate', 'key': 'digital_marketing_certificate', 'icon': Icons.campaign, 'category': 'Certification'},
    {'name': 'Data Science Certificate', 'key': 'data_science_certificate', 'icon': Icons.analytics, 'category': 'Certification'},
    {'name': 'Cloud Computing Certificate', 'key': 'cloud_computing_certificate', 'icon': Icons.cloud, 'category': 'Certification'},
    {'name': 'Cybersecurity Certificate', 'key': 'cybersecurity_certificate', 'icon': Icons.security, 'category': 'Certification'},

    // ==================== MISCELLANEOUS & SPECIAL DOCUMENTS ====================
    {'name': 'Gap Certificate', 'key': 'gap_certificate', 'icon': Icons.timeline, 'category': 'Miscellaneous'},
    {'name': 'Skip Certificate', 'key': 'skip_certificate', 'icon': Icons.skip_next, 'category': 'Miscellaneous'},
    {'name': 'Skip Year Certificate', 'key': 'skip_year_certificate', 'icon': Icons.calendar_today, 'category': 'Miscellaneous'},
    {'name': 'Education Gap Certificate', 'key': 'education_gap_certificate', 'icon': Icons.school, 'category': 'Miscellaneous'},
    {'name': 'Character Certificate', 'key': 'character_certificate', 'icon': Icons.verified, 'category': 'Miscellaneous'},
    {'name': 'Migration Certificate', 'key': 'migration_certificate', 'icon': Icons.transfer_within_a_station, 'category': 'Miscellaneous'},
    {'name': 'Transfer Certificate', 'key': 'transfer_certificate', 'icon': Icons.swap_horiz, 'category': 'Miscellaneous'},
    {'name': 'Bonafide Certificate', 'key': 'bonafide_certificate', 'icon': Icons.school, 'category': 'Miscellaneous'},
    {'name': 'Conduct Certificate', 'key': 'conduct_certificate', 'icon': Icons.verified_user, 'category': 'Miscellaneous'},
    {'name': 'Medical Fitness Certificate', 'key': 'medical_fitness_certificate', 'icon': Icons.health_and_safety, 'category': 'Miscellaneous'},
    {'name': 'Antecedent Certificate', 'key': 'antecedent_certificate', 'icon': Icons.history, 'category': 'Miscellaneous'},
    {'name': 'No Objection Certificate (NOC)', 'key': 'noc_certificate', 'icon': Icons.check_circle, 'category': 'Miscellaneous'},
    {'name': 'Other Document', 'key': 'other_document_url', 'icon': Icons.cloud_upload, 'category': 'Miscellaneous'},
  ];

  // Group documents by category for better organization
  Map<String, List<Map<String, dynamic>>> get _groupedDocuments {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final doc in _documentTypes) {
      final String category = doc['category'] as String;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(doc);
    }
    return grouped;
  }

  String? _selectedDocumentType;
  String? _selectedDocumentKey;
  final Map<String, String> _documents = {};

  // Store selected file info
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _loadDocuments();
  }

  // ============================================================
  // ✅ LOAD USER EMAIL
  // ============================================================
  Future<void> _loadUserEmail() async {
    final email = await SecureStorage.getEmail();
    if (mounted) {
      setState(() {
        _userEmail = email;
      });
    }
    debugPrint("📧 User Email: $_userEmail");
  }

  // ============================================================
  // ✅ LOAD DOCUMENTS FROM SERVER
  // ============================================================
  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await DioClient.dio.get('/user/full-profile');
      Map<String, dynamic> profile = {};

      if (response.data is Map) {
        if (response.data.containsKey('data')) {
          profile = response.data['data'] as Map<String, dynamic>;
        } else {
          profile = response.data as Map<String, dynamic>;
        }
      }

      final Map<String, String> docs = {};
      final additional = profile['additional_details'] as Map? ?? {};

      for (final docType in _documentTypes) {
        final key = docType['key'] as String;
        final String? url = additional[key] ?? profile[key];
        if (url != null && url.isNotEmpty) {
          docs[key] = url;
        }
      }

      if (mounted) {
        setState(() {
          _documents.clear();
          _documents.addAll(docs);
          _isLoading = false;
        });
        debugPrint("📋 Loaded ${docs.length} documents");
      }
    } catch (e) {
      debugPrint("❌ Error loading documents: $e");
      if (mounted) {
        showMessage(context, "Failed to load documents: $e", isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // ✅ PICK DOCUMENT - WORKS ON MOBILE AND WEB
  // ✅ FIXED: Profile photo only accepts IMAGES (no PDF)
  // ============================================================
  Future<void> _pickDocument() async {
    try {
      // ✅ Detect if we're picking for profile photo
      final isProfilePhoto = _selectedDocumentKey == 'profile_photo_url';

      // Profile photo → images only. Other docs → images + PDF.
      final allowedExtensions = isProfilePhoto
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && mounted) {
        final file = result.files.first;

        final extension = file.name.toLowerCase().split('.').last;
        if (!allowedExtensions.contains(extension)) {
          showMessage(
            context,
            "❌ Only ${allowedExtensions.join(', ').toUpperCase()} files are supported here.",
            isError: true,
          );
          return;
        }

        if (file.size > 10 * 1024 * 1024) {
          showMessage(context, "File too large. Maximum size is 10MB.",
              isError: true);
          return;
        }

        if (file.bytes == null) {
          showMessage(context, "File data is not available. Please try again.",
              isError: true);
          return;
        }

        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = file.bytes!;
        });

        debugPrint(
            "✅ File selected: ${file.name}, Size: ${file.size} bytes, Platform: ${kIsWeb ? 'Web' : 'Mobile'}");
      }
    } catch (e) {
      debugPrint("❌ Error picking file: $e");
      if (mounted) {
        showMessage(context, "Error selecting file: $e", isError: true);
      }
    }
  }

  // ============================================================
  // ✅ UPLOAD DOCUMENT — with immediate sync to BOTH providers
  // ✅ FIXED: ProfileStateService updated FIRST (global source of truth)
  // ✅ FIXED: UserProfileProvider also updated (ResumeScreen)
  // ✅ FIXED: Uses normalized URL for both providers
  // ============================================================
  Future<void> _uploadDocument() async {
    if (_selectedDocumentType == null || _selectedDocumentKey == null) {
      showMessage(context, "Please select a document type first",
          isError: true);
      return;
    }

    if (_selectedFileName == null || _selectedFileBytes == null) {
      showMessage(context, "Please select a file to upload", isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          _selectedFileBytes!,
          filename: _selectedFileName!,
        ),
        'document_type': _selectedDocumentKey,
      });

      debugPrint(
          "📤 Uploading document: $_selectedFileName to document_type: $_selectedDocumentKey");

      final res = await DioClient.dio.post(
        '/user/upload-document',
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (!mounted) return;

      if (res.data['success'] == true) {
        final fileUrl = (res.data['url'] ?? '').toString().trim();
        final publicId = res.data['public_id'] as String?;

        if (fileUrl.isEmpty) {
          throw Exception("Server returned no file URL");
        }

        debugPrint("✅ Upload OK → $fileUrl");

        // ========================================================
        // ✅ STEP 1: Update ProfileStateService FIRST
        //    → this is the GLOBAL source of truth
        //    → Sidebar, Dashboard, BuildResume all listen to this
        // ========================================================
        if (_selectedDocumentKey == 'profile_photo_url') {
          ProfileStateService().setPhoto(
            url: fileUrl,
            publicId: publicId,
          );
          debugPrint("✅ ProfileStateService updated → $fileUrl");
        }

        // ========================================================
        // ✅ STEP 2: Update UserProfileProvider
        //    → ResumeScreen listens to this
        //    → Also auto-syncs to ProfileStateService (via listener)
        // ========================================================
        if (_selectedDocumentKey == 'profile_photo_url' && mounted) {
          Provider.of<UserProfileProvider>(context, listen: false)
              .setProfilePhoto(url: fileUrl, publicId: publicId);
          debugPrint("✅ UserProfileProvider updated → $fileUrl");
        }

        // ========================================================
        // ✅ STEP 3: Persist to profile DB
        // ========================================================
        await _updateProfileDocument(_selectedDocumentKey!, fileUrl);

        // ========================================================
        // ✅ STEP 4: Update local state
        // ========================================================
        if (mounted) {
          setState(() {
            _documents[_selectedDocumentKey!] = fileUrl;
            _selectedDocumentType = null;
            _selectedDocumentKey = null;
            _selectedFileName = null;
            _selectedFileBytes = null;
          });
          showMessage(context,
              "$_selectedDocumentType uploaded successfully!");
        }
      } else {
        throw Exception(res.data['message'] ?? "Upload failed");
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains("Invalid file type")) {
          errorMsg =
              "File type not supported. Please upload JPG, JPEG, PNG images only.";
        }
        showMessage(context, "Upload failed: $errorMsg", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ============================================================
  // ✅ UPDATE PROFILE DOCUMENT (DB persist)
  // ============================================================
  Future<void> _updateProfileDocument(String key, String url) async {
    try {
      final updateData = {'additional_details.$key': url};
      await DioClient.dio.put('/user/update-profile', data: updateData);
      debugPrint("✅ Updated profile document: $key");
    } catch (e) {
      debugPrint("⚠️ Could not update profile via PUT: $e");
      try {
        await DioClient.dio.post('/user/update-document', data: {
          'document_key': key,
          'document_url': url,
        });
        debugPrint("✅ Updated profile document via POST: $key");
      } catch (e2) {
        debugPrint("⚠️ Alternative update also failed: $e2");
      }
    }
  }

  // ============================================================
  // ✅ DELETE DOCUMENT — with sync to BOTH providers
  // ============================================================
  Future<void> _deleteDocument(String key, String docName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Document"),
        content: Text("Are you sure you want to delete \"$docName\"?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      final res = await DioClient.dio
          .delete('/user/delete-document', data: {'document_key': key});
      if (!mounted) return;

      if (res.data['success'] == true) {
        if (mounted) {
          setState(() => _documents.remove(key));
        }

        // ✅ CRITICAL: If profile photo deleted → clear from BOTH providers
        if (key == 'profile_photo_url') {
          // Clear from ProfileStateService (global source)
          ProfileStateService().clearPhoto();
          debugPrint(
              "🗑️ Profile photo cleared from ProfileStateService");

          // Clear from UserProfileProvider (ResumeScreen)
          if (mounted) {
            Provider.of<UserProfileProvider>(context, listen: false)
                .clearProfilePhoto();
            debugPrint(
                "🗑️ Profile photo cleared from UserProfileProvider");
          }
        }

        if (mounted) {
          showMessage(context, "$docName deleted successfully");
        }
      } else {
        throw Exception(res.data['message'] ?? "Delete failed");
      }
    } catch (e) {
      if (mounted) showMessage(context, "Delete failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ============================================================
  // ✅ VIEW DOCUMENT AS POPUP DIALOG
  // ============================================================
  void _viewDocument(String url, String docName) {
    if (url.isEmpty) {
      showMessage(context, "No document available", isError: true);
      return;
    }

    final String fileType = _getFileType(url);

    debugPrint("📄 Opening document as POPUP: $docName");
    debugPrint("🔗 URL: $url");
    debugPrint("📁 File Type: $fileType");

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.9,
          height: MediaQuery.of(dialogContext).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FileViewerScreen(
              url: url,
              title: docName,
              downloadUrl: url,
              fileType: fileType,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ HELPER METHODS
  // ============================================================
  String _getFileType(String url) {
    final urlLower = url.toLowerCase();

    if (urlLower.endsWith('.jpg') ||
        urlLower.endsWith('.jpeg') ||
        urlLower.endsWith('.png') ||
        urlLower.endsWith('.webp') ||
        urlLower.endsWith('.gif')) {
      return 'image';
    }
    if (urlLower.contains('cloudinary.com')) {
      return 'cloudinary';
    }
    return 'unknown';
  }

  String _getDocumentName(String key) {
    final docType = _documentTypes.firstWhere((d) => d['key'] == key,
        orElse: () => {'name': key.replaceAll('_', ' ').toUpperCase()});
    return docType['name'] as String;
  }

  IconData _getDocumentIcon(String key) {
    final docType = _documentTypes.firstWhere((d) => d['key'] == key,
        orElse: () => {'icon': Icons.insert_drive_file});
    return docType['icon'] as IconData;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Education':
        return Colors.blue;
      case 'Professional':
        return Colors.green;
      case 'Identity':
        return Colors.purple;
      case 'Caste':
        return Colors.orange;
      case 'Disability':
        return Colors.teal;
      case 'Income':
        return Colors.green;
      case 'Residence':
        return Colors.indigo;
      case 'Family':
        return Colors.pink;
      case 'Government':
        return Colors.blueGrey;
      case 'Certification':
        return Colors.deepPurple;
      case 'Miscellaneous':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String? _getCategoryForDocument(String docName) {
    for (final doc in _documentTypes) {
      if (doc['name'] == docName) {
        return doc['category'] as String;
      }
    }
    return null;
  }

  // ============================================================
  // ✅ SHOW DOCUMENT TYPE DIALOG
  // ============================================================
  void _showDocumentTypeDialog(List<Map<String, dynamic>> documents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(
                      width: 40,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Select Document Type",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose the document type you want to upload",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final doc = documents[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(doc['icon'] as IconData,
                                  color: Colors.blue.shade700, size: 22),
                            ),
                            title: Text(
                              doc['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right,
                                color: Colors.grey.shade400),
                            onTap: () {
                              setState(() {
                                _selectedDocumentType = doc['name'] as String;
                                _selectedDocumentKey = doc['key'] as String;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ✅ AI-BASED DESIGN COMPONENTS
  // ============================================================

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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
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
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "AI is loading your documents...",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            child: const Icon(
              Icons.folder_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Documents",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Upload and manage your important documents",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
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
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1,
        ),
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
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            width: 30,
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    final groupedDocs = _groupedDocuments;
    final categoryNames = groupedDocs.keys.toList();

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),

                // ============================================================
                // ✅ UPLOAD SECTION
                // ============================================================
                _buildGlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader("Upload New Document", Icons.cloud_upload),

                      // Category Selection
                      const Text(
                        "Select Document Category",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
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
                        child: DropdownButtonFormField<String?>(
                          value: _selectedDocumentType != null
                              ? _getCategoryForDocument(_selectedDocumentType!)
                              : null,
                          hint: Text(
                            "Select Category",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            prefixIcon: Icon(Icons.folder_open,
                                color: Colors.grey.shade600),
                            suffixIcon: Icon(Icons.arrow_drop_down,
                                color: Colors.grey.shade600),
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          iconEnabledColor: Colors.grey.shade600,
                          items: categoryNames
                              .map((category) => DropdownMenuItem<String?>(
                                  value: category,
                                  child: Row(children: [
                                    Icon(Icons.folder,
                                        size: 18,
                                        color: _getCategoryColor(category)),
                                    const SizedBox(width: 8),
                                    Text(
                                      "$category (${groupedDocs[category]!.length})",
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                    )
                                  ])))
                              .toList(),
                          onChanged: (category) {
                            if (category != null &&
                                groupedDocs.containsKey(category)) {
                              _showDocumentTypeDialog(groupedDocs[category]!);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Document Type Display
                      if (_selectedDocumentType != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100
                            ]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(
                                    _getDocumentIcon(_selectedDocumentKey!),
                                    color: Colors.white,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Selected Document",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      _selectedDocumentType!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    size: 20, color: Colors.blue),
                                onPressed: () => setState(() {
                                  _selectedDocumentType = null;
                                  _selectedDocumentKey = null;
                                }),
                                tooltip: "Change Document Type",
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // File Selection Button
                      GestureDetector(
                        onTap: _pickDocument,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _selectedFileName != null
                                ? Colors.green.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _selectedFileName != null
                                    ? Colors.green
                                    : Colors.blue,
                                width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                  _selectedFileName != null
                                      ? Icons.check_circle
                                      : Icons.cloud_upload,
                                  size: 48,
                                  color: _selectedFileName != null
                                      ? Colors.green
                                      : Colors.blue),
                              const SizedBox(height: 12),
                              Text(
                                  _selectedFileName != null
                                      ? _selectedFileName!
                                      : "Tap to select image (JPG, JPEG, PNG)",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _selectedFileName != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _selectedFileName != null
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700),
                                  textAlign: TextAlign.center),
                              if (_selectedFileName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                    "${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                  kIsWeb ? "🌐 Web" : "📱 Mobile",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Upload Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : _uploadDocument,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.upload_file, size: 20),
                                      const SizedBox(width: 10),
                                      const Text(
                                        "Upload Document",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          "AI",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // ✅ DOCUMENTS LIST SECTION
                // ============================================================
                _buildGlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.folder,
                                  color: Colors.teal.shade700, size: 22)),
                          const SizedBox(width: 12),
                          Text(
                            "My Documents",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                "${_documents.length} Documents",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade900,
                                ),
                              )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      if (_documents.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16)),
                          child: Column(children: [
                            Icon(Icons.cloud_upload_outlined,
                                size: 60, color: Colors.grey.shade400),
                            SizedBox(height: 12),
                            Text(
                              "No documents uploaded yet",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Select a category and document type to upload",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ]),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final entry = _documents.entries.elementAt(index);
                            final docKey = entry.key;
                            final docUrl = entry.value;
                            final docName = _getDocumentName(docKey);
                            final docIcon = _getDocumentIcon(docKey);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [
                                        Colors.grey.shade50,
                                        Colors.white
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.grey.shade300)),
                              child: ListTile(
                                leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(docIcon,
                                        color: Colors.blue.shade700,
                                        size: 24)),
                                title: Text(
                                  docName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Row(children: [
                                  const Icon(Icons.check_circle,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Uploaded",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.access_time,
                                      size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Available",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ]),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: IconButton(
                                            icon: const Icon(Icons.visibility,
                                                color: Colors.blue, size: 20),
                                            onPressed: () =>
                                                _viewDocument(docUrl, docName),
                                            tooltip: "View Document")),
                                    const SizedBox(width: 4),
                                    Container(
                                        decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red, size: 20),
                                            onPressed: () => _deleteDocument(
                                                docKey, docName),
                                            tooltip: "Delete Document")),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        size: 20, color: Colors.blue.shade700),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "🖼️ Supported Formats: JPG, JPEG, PNG images\n\n"
                        "📄 PDF support is also available\n\n"
                        "📁 Documents are organized by category. Select a category first, then choose document type.\n\n"
                        "🔒 All documents are stored securely in Cloudinary with signed URLs.\n\n"
                        "🗑️ You can delete any document anytime.\n\n"
                        "📜 Special Documents include: Skip Certificate, Gap Certificate, Bonafide, NOC, etc.\n\n"
                        "📱 Works on both Mobile and Web platforms!",
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}