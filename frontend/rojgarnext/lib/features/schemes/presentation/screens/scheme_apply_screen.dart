// lib/features/schemes/presentation/screens/scheme_apply_screen.dart
// ✅ COMPLETE FIXED VERSION
// ✅ FIXED: Added http import
// ✅ REMOVED: Bank Details Tab (auto-filled from profile)
// ✅ REMOVED: Aadhaar Card number field (auto-filled from profile)
// ✅ REMOVED: Bank-related fields from "Profile Incomplete" warning
// ✅ REMOVED: Back button from AppBar (automaticallyImplyLeading: false)
// ✅ All other details auto-filled from profile
// ✅ Tabs shown for: Personal Details, Address, Documents

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/core/config/api_config.dart';
import 'package:rojgarnext/core/master_date/schemes_data.dart';

// ============================================================
// SCHEME APPLY SCREEN
// ============================================================

class SchemeApplyScreen extends StatefulWidget {
  final GovernmentScheme scheme;

  const SchemeApplyScreen({
    super.key,
    required this.scheme,
  });

  @override
  State<SchemeApplyScreen> createState() => _SchemeApplyScreenState();
}

class _SchemeApplyScreenState extends State<SchemeApplyScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // TAB CONTROLLER
  // ============================================================
  late TabController _tabController;
  int _currentTabIndex = 0;

  // ✅ ONLY 3 TABS NOW (Bank Details tab REMOVED)
  final List<String> _tabLabels = const [
    'Personal Details',
    'Address Details',
    'Documents',
  ];

  final List<IconData> _tabIcons = const [
    Icons.person,
    Icons.location_on,
    Icons.upload_file,
  ];

  // ============================================================
  // ✅ BANK-RELATED FIELDS TO EXCLUDE FROM WARNING
  // ============================================================
  static const Set<String> _bankRelatedFields = {
    'bank_name',
    'bank_account',
    'account_number',
    'ifsc_code',
    'branch_name',
    'account_holder_name',
    'account_type',
    'bank_details',
    'aadhaar_number',
    'aadhar_number',
    'aadhaar_card',
    'aadhar_card',
  };

  // ============================================================
  // LOADING STATES
  // ============================================================
  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  bool _profileComplete = false;
  List<String> _missingFields = [];

  // ============================================================
  // PROFILE DATA (Auto-filled)
  // ============================================================
  Map<String, dynamic> _profileData = {};

  // ============================================================
  // PERSONAL DETAILS (Read-only, auto-filled from profile)
  // ✅ AADHAAR NUMBER FIELD REMOVED
  // ============================================================
  final TextEditingController fullNameCtrl = TextEditingController();
  final TextEditingController fatherNameCtrl = TextEditingController();
  final TextEditingController motherNameCtrl = TextEditingController();
  final TextEditingController dobCtrl = TextEditingController();
  final TextEditingController genderCtrl = TextEditingController();
  final TextEditingController categoryCtrl = TextEditingController();
  final TextEditingController maritalStatusCtrl = TextEditingController();
  final TextEditingController mobileCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController annualIncomeCtrl = TextEditingController();
  final TextEditingController disabilityStatusCtrl = TextEditingController();

  // ============================================================
  // ADDRESS DETAILS (Read-only, auto-filled from profile)
  // ============================================================
  final TextEditingController addressLine1Ctrl = TextEditingController();
  final TextEditingController addressLine2Ctrl = TextEditingController();
  final TextEditingController villageCityCtrl = TextEditingController();
  final TextEditingController districtCtrl = TextEditingController();
  final TextEditingController stateCtrl = TextEditingController();
  final TextEditingController pincodeCtrl = TextEditingController();
  final TextEditingController countryCtrl = TextEditingController();

  // ============================================================
  // DOCUMENTS (User uploads)
  // ============================================================
  final Map<String, Map<String, dynamic>> _uploadedDocuments = {};
  bool _isUploadingDoc = false;
  String? _uploadingDocType;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (mounted && _currentTabIndex != _tabController.index) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    fullNameCtrl.dispose();
    fatherNameCtrl.dispose();
    motherNameCtrl.dispose();
    dobCtrl.dispose();
    genderCtrl.dispose();
    categoryCtrl.dispose();
    maritalStatusCtrl.dispose();
    mobileCtrl.dispose();
    emailCtrl.dispose();
    annualIncomeCtrl.dispose();
    disabilityStatusCtrl.dispose();
    addressLine1Ctrl.dispose();
    addressLine2Ctrl.dispose();
    villageCityCtrl.dispose();
    districtCtrl.dispose();
    stateCtrl.dispose();
    pincodeCtrl.dispose();
    countryCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE DATA FROM BACKEND
  // ✅ FIXED: Removes bank-related fields from missing fields warning
  // ============================================================
  Future<void> _loadProfileData() async {
    setState(() => _isLoadingProfile = true);

    try {
      debugPrint("=" * 70);
      debugPrint("📥 LOADING PROFILE DATA FOR SCHEME APPLICATION");
      debugPrint("   Scheme: ${widget.scheme.schemeName}");
      debugPrint("=" * 70);

      // ✅ Use the new profile-data endpoint
      final response = await DioClient.dio.get('/schemes/profile-data');

      if (response.data['success'] == true) {
        _profileData = response.data;

        // ✅ Get raw missing fields from backend
        final rawMissingFields = List<String>.from(
          response.data['missing_fields'] ?? [],
        );

        // ✅ Filter out bank-related and aadhaar fields
        _missingFields = rawMissingFields
            .where((field) =>
                !_bankRelatedFields.contains(field.toLowerCase()))
            .toList();

        // ✅ Recalculate profile_complete based on filtered fields
        _profileComplete = _missingFields.isEmpty;

        debugPrint("✅ Profile data loaded");
        debugPrint("   Raw Missing Fields: $rawMissingFields");
        debugPrint("   Filtered Missing Fields: $_missingFields");
        debugPrint("   Profile Complete: $_profileComplete");

        // ✅ Auto-fill all controllers
        _autoFillPersonalDetails(response.data['applicant_details'] ?? {});
        _autoFillAddressDetails(response.data['applicant_address'] ?? {});

        // ✅ Bank details are NOT displayed but still loaded for backend
        // They will be sent automatically when submitting
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      debugPrint("❌ Failed to load profile: $e");
      if (mounted) {
        showMessage(
          context,
          "Failed to load profile: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // ============================================================
  // AUTO-FILL PERSONAL DETAILS
  // ✅ AADHAAR NUMBER REMOVED
  // ============================================================
  void _autoFillPersonalDetails(Map<String, dynamic> details) {
    fullNameCtrl.text = details['full_name']?.toString() ?? '';
    fatherNameCtrl.text = details['father_name']?.toString() ?? '';
    motherNameCtrl.text = details['mother_name']?.toString() ?? '';
    dobCtrl.text = details['date_of_birth']?.toString() ?? '';
    genderCtrl.text = _capitalizeFirst(details['gender']?.toString() ?? '');
    categoryCtrl.text = details['category']?.toString() ?? 'General';
    maritalStatusCtrl.text = details['marital_status']?.toString() ?? 'Unmarried';
    mobileCtrl.text = details['mobile']?.toString() ?? '';
    emailCtrl.text = details['email']?.toString() ?? '';
    annualIncomeCtrl.text = details['annual_income']?.toString() ?? '0';

    // Disability status
    final disabilityStatus = details['disability_status'] == true;
    final disabilityPercentage = details['disability_percentage'];
    if (disabilityStatus) {
      disabilityStatusCtrl.text = disabilityPercentage != null &&
              disabilityPercentage > 0
          ? 'Yes (${disabilityPercentage.toStringAsFixed(0)}%)'
          : 'Yes';
    } else {
      disabilityStatusCtrl.text = 'No';
    }

    // ❌ AADHAAR NUMBER IS NOT AUTO-FILLED (field removed entirely)

    debugPrint("✅ Personal details auto-filled");
  }

  // ============================================================
  // AUTO-FILL ADDRESS DETAILS
  // ============================================================
  void _autoFillAddressDetails(Map<String, dynamic> address) {
    addressLine1Ctrl.text = address['address_line1']?.toString() ?? '';
    addressLine2Ctrl.text = address['address_line2']?.toString() ?? '';
    villageCityCtrl.text = address['village_city']?.toString() ?? '';
    districtCtrl.text = address['district']?.toString() ?? '';
    stateCtrl.text = address['state']?.toString() ?? '';
    pincodeCtrl.text = address['pincode']?.toString() ?? '';
    countryCtrl.text = address['country']?.toString() ?? 'India';

    debugPrint("✅ Address details auto-filled");
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // ============================================================
  // DOCUMENT UPLOAD
  // ============================================================
  Future<void> _pickAndUploadDocument(String docType, String docName) async {
    if (_isUploadingDoc) return;

    try {
      // Determine allowed file types based on document
      List<String> allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // ✅ Validate file size (max 10MB)
      if (file.size > 10 * 1024 * 1024) {
        if (mounted) {
          showMessage(
            context,
            "File too large. Maximum 10MB allowed.",
            isError: true,
          );
        }
        return;
      }

      setState(() {
        _isUploadingDoc = true;
        _uploadingDocType = docType;
      });

      // ✅ Upload to backend
      final token = await SecureStorage.getToken();
      if (token == null) {
        throw Exception("No authentication token found");
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/schemes/upload-temp-document',
      );

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: _getMimeType(file.name),
      );
      request.files.add(multipartFile);

      request.fields['document_type'] = docType;
      request.fields['document_name'] = docName;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final docData = data['document'] ?? {};

          setState(() {
            _uploadedDocuments[docType] = {
              'document_type': docType,
              'document_name': docName,
              'document_url': docData['document_url'] ?? docData['url'],
              'public_id': docData['public_id'],
              'filename': file.name,
              'size_bytes': file.size,
            };
          });

          if (mounted) {
            showMessage(context, "✅ $docName uploaded successfully!");
          }
        } else {
          throw Exception(data['message'] ?? 'Upload failed');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
      debugPrint("❌ Document upload failed: $e");
      if (mounted) {
        showMessage(
          context,
          "Upload failed: ${e.toString().replaceAll('Exception:', '')}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingDoc = false;
          _uploadingDocType = null;
        });
      }
    }
  }

  MediaType _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  void _removeDocument(String docType) {
    setState(() {
      _uploadedDocuments.remove(docType);
    });
    if (mounted) {
      showMessage(context, "Document removed");
    }
  }

  // ============================================================
  // SUBMIT APPLICATION
  // ✅ Bank details are sent automatically from profile (not displayed)
  // ✅ Aadhaar number is sent automatically from profile (not displayed)
  // ============================================================
  Future<void> _submitApplication() async {
    // Validate required documents
    final requiredDocs = widget.scheme.requiredDocuments;

    for (var doc in requiredDocs) {
      if (doc.required && !_uploadedDocuments.containsKey(doc.name)) {
        if (mounted) {
          showMessage(
            context,
            "Please upload: ${doc.name}",
            isError: true,
          );
        }
        // Switch to documents tab
        _tabController.animateTo(2);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      debugPrint("=" * 70);
      debugPrint("📤 SUBMITTING SCHEME APPLICATION");
      debugPrint("   Scheme ID: ${widget.scheme.schemeId}");
      debugPrint("   Scheme Name: ${widget.scheme.schemeName}");
      debugPrint("=" * 70);

      // ✅ Build applicant details from auto-filled controllers
      // NOTE: Aadhaar is sent from profile data automatically
      final applicantDetails = {
        'full_name': fullNameCtrl.text.trim(),
        'father_name': fatherNameCtrl.text.trim(),
        'mother_name': motherNameCtrl.text.trim(),
        'date_of_birth': dobCtrl.text.trim(),
        'gender': genderCtrl.text.toLowerCase(),
        'category': categoryCtrl.text,
        'marital_status': maritalStatusCtrl.text,
        'mobile': mobileCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'annual_income': int.tryParse(annualIncomeCtrl.text) ?? 0,
        'bpl_status': false,
        'disability_status':
            disabilityStatusCtrl.text.toLowerCase().startsWith('yes'),
        'disability_percentage': 0.0,
        'scheme_name': widget.scheme.schemeName,
        'scheme_id': widget.scheme.schemeId,
        'application_type': 'schemes',
        // ✅ Aadhaar number is automatically pulled from profile on backend
        // We don't need to send it explicitly here
      };

      // ✅ Build address details
      final applicantAddress = {
        'address_line1': addressLine1Ctrl.text.trim(),
        'address_line2': addressLine2Ctrl.text.trim(),
        'village_city': villageCityCtrl.text.trim(),
        'district': districtCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'pincode': pincodeCtrl.text.trim(),
        'country': countryCtrl.text.trim(),
      };

      // ✅ Build documents list
      final documents = _uploadedDocuments.values.map((doc) {
        return {
          'document_type': doc['document_type'],
          'document_name': doc['document_name'],
          'document_url': doc['document_url'],
          'public_id': doc['public_id'],
        };
      }).toList();

      // ✅ Build final payload
      // NOTE: Bank details are automatically fetched from profile on backend
      // We don't need to send them explicitly
      final payload = {
        'scheme_id': widget.scheme.schemeId,
        'scheme_name': widget.scheme.schemeName,
        'applicant_details': applicantDetails,
        'applicant_address': applicantAddress,
        // ✅ Bank details are NOT sent here - backend fetches from profile
        'documents': documents,
      };

      debugPrint("📦 Payload prepared:");
      debugPrint("   Documents: ${documents.length}");
      debugPrint("   Personal details: Auto-filled");
      debugPrint("   Address: Auto-filled");
      debugPrint("   Bank details: Auto-fetched from profile on backend");

      // ✅ Submit to backend
      final response = await DioClient.dio.post(
        '/schemes/apply',
        data: payload,
      );

      debugPrint("📥 Response: ${response.data}");

      if (response.data['success'] == true) {
        final applicationId = response.data['application_id'];

        if (mounted) {
          // Show success dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Text("Application Submitted!"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your application has been submitted successfully.",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Application ID:",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          applicationId ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Scheme: ${widget.scheme.schemeName}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context); // Go back to scheme detail
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(
          response.data['message'] ?? 'Application submission failed',
        );
      }
    } catch (e) {
      debugPrint("❌ Submit failed: $e");
      if (mounted) {
        showMessage(
          context,
          "Failed to submit: ${e.toString().replaceAll('Exception:', '')}",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ============================================================
  // BUILD
  // ✅ REMOVED: Back button from AppBar
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        // ✅ REMOVED: Back button (automaticallyImplyLeading = false)
        automaticallyImplyLeading: false,
        title: Text(
          widget.scheme.schemeName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.normal,
          ),
          isScrollable: true,
          tabs: List.generate(_tabLabels.length, (index) {
            return Tab(
              icon: Icon(_tabIcons[index], size: 18),
              text: _tabLabels[index],
              height: 60,
            );
          }),
        ),
      ),
      body: Column(
        children: [
          // ✅ Profile incomplete warning (bank fields filtered out)
          if (!_profileComplete && _missingFields.isNotEmpty)
            _buildProfileWarning(),

          // ✅ Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalDetailsTab(),
                _buildAddressDetailsTab(),
                _buildDocumentsTab(),
              ],
            ),
          ),

          // ✅ Bottom bar with submit button
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING SCREEN
  // ============================================================
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Loading your profile...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE WARNING BANNER
  // ✅ Bank fields already filtered — only shows non-bank fields
  // ============================================================
  Widget _buildProfileWarning() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Profile Incomplete",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Please complete these fields in your profile:\n${_missingFields.take(5).map((f) => '• ${_formatFieldName(f)}').join('\n')}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
        .join(' ');
  }

  // ============================================================
  // TAB 1: PERSONAL DETAILS
  // ✅ AADHAAR NUMBER FIELD REMOVED
  // ✅ All fields are READ-ONLY (auto-filled from profile)
  // ============================================================
  Widget _buildPersonalDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoBanner(
            "Your personal details are automatically filled from your profile. "
            "To make changes, please update your profile.",
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Personal Information",
            icon: Icons.person,
            children: [
              _buildReadOnlyField(
                label: "Full Name",
                value: fullNameCtrl.text,
                icon: Icons.person,
              ),
              _buildReadOnlyField(
                label: "Father's Name",
                value: fatherNameCtrl.text,
                icon: Icons.family_restroom,
              ),
              _buildReadOnlyField(
                label: "Mother's Name",
                value: motherNameCtrl.text,
                icon: Icons.family_restroom,
              ),
              _buildReadOnlyField(
                label: "Date of Birth",
                value: dobCtrl.text,
                icon: Icons.calendar_today,
              ),
              _buildReadOnlyField(
                label: "Gender",
                value: genderCtrl.text,
                icon: Icons.wc,
              ),
              _buildReadOnlyField(
                label: "Category",
                value: categoryCtrl.text,
                icon: Icons.category,
              ),
              _buildReadOnlyField(
                label: "Marital Status",
                value: maritalStatusCtrl.text,
                icon: Icons.favorite,
              ),
              // ❌ AADHAAR NUMBER FIELD REMOVED
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Contact Information",
            icon: Icons.contact_phone,
            children: [
              _buildReadOnlyField(
                label: "Mobile Number",
                value: mobileCtrl.text,
                icon: Icons.phone,
              ),
              _buildReadOnlyField(
                label: "Email Address",
                value: emailCtrl.text,
                icon: Icons.email,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Additional Information",
            icon: Icons.info_outline,
            children: [
              _buildReadOnlyField(
                label: "Annual Income",
                value: annualIncomeCtrl.text == '0' ||
                        annualIncomeCtrl.text.isEmpty
                    ? 'Not specified'
                    : '₹${annualIncomeCtrl.text}',
                icon: Icons.currency_rupee,
              ),
              _buildReadOnlyField(
                label: "Disability Status",
                value: disabilityStatusCtrl.text,
                icon: Icons.accessibility,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2: ADDRESS DETAILS
  // ✅ All fields are READ-ONLY (auto-filled from profile)
  // ============================================================
  Widget _buildAddressDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoBanner(
            "Your address details are automatically filled from your profile. "
            "To make changes, please update your profile.",
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Current Address",
            icon: Icons.location_on,
            children: [
              _buildReadOnlyField(
                label: "Address Line 1",
                value: addressLine1Ctrl.text,
                icon: Icons.home,
              ),
              _buildReadOnlyField(
                label: "Address Line 2",
                value: addressLine2Ctrl.text,
                icon: Icons.home_outlined,
              ),
              _buildReadOnlyField(
                label: "Village / City",
                value: villageCityCtrl.text,
                icon: Icons.location_city,
              ),
              _buildReadOnlyField(
                label: "District",
                value: districtCtrl.text,
                icon: Icons.map,
              ),
              _buildReadOnlyField(
                label: "State",
                value: stateCtrl.text,
                icon: Icons.public,
              ),
              _buildReadOnlyField(
                label: "Pincode",
                value: pincodeCtrl.text,
                icon: Icons.pin_drop,
              ),
              _buildReadOnlyField(
                label: "Country",
                value: countryCtrl.text,
                icon: Icons.flag,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Bank details section REMOVED
          // Bank details are automatically fetched from profile on backend
          _buildInfoBanner(
            "Bank details are automatically fetched from your profile. "
            "If you need to update them, please go to your profile settings.",
            icon: Icons.account_balance,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: DOCUMENTS
  // ✅ User uploads required documents here
  // ============================================================
  Widget _buildDocumentsTab() {
    final requiredDocs = widget.scheme.requiredDocuments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoBanner(
            "Please upload all required documents. Documents marked with * are mandatory.",
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: "Required Documents",
            icon: Icons.upload_file,
            children: [
              if (requiredDocs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 48,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No documents required for this scheme",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...requiredDocs.map((doc) => _buildDocumentUploadTile(
                      docType: doc.name,
                      docLabel: doc.name,
                      docLabelHindi: doc.nameHindi,
                      isRequired: doc.required,
                    )),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Optional documents section
          if (requiredDocs.any((d) => !d.required))
            _buildSectionCard(
              title: "Optional Documents",
              icon: Icons.attach_file,
              children: requiredDocs
                  .where((d) => !d.required)
                  .map((doc) => _buildDocumentUploadTile(
                        docType: doc.name,
                        docLabel: doc.name,
                        docLabelHindi: doc.nameHindi,
                        isRequired: false,
                      ))
                  .toList(),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENT UPLOAD TILE
  // ============================================================
  Widget _buildDocumentUploadTile({
    required String docType,
    required String docLabel,
    required String docLabelHindi,
    required bool isRequired,
  }) {
    final isUploaded = _uploadedDocuments.containsKey(docType);
    final isUploading = _isUploadingDoc && _uploadingDocType == docType;
    final docData = _uploadedDocuments[docType];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUploaded ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded
              ? Colors.green.shade300
              : (isRequired ? Colors.red.shade200 : Colors.grey.shade300),
          width: isUploaded ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUploaded
                    ? Icons.check_circle
                    : (isRequired ? Icons.error_outline : Icons.upload_file),
                color: isUploaded
                    ? Colors.green
                    : (isRequired ? Colors.red : Colors.grey),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            docLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isUploaded
                                  ? Colors.green.shade800
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Required",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (docLabelHindi.isNotEmpty)
                      Text(
                        docLabelHindi,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isUploaded && docData != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          docData['filename'] ?? 'Document uploaded',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${((docData['size_bytes'] ?? 0) / 1024).toStringAsFixed(1)} KB",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeDocument(docType),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    tooltip: "Remove",
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isUploading
                    ? null
                    : () => _pickAndUploadDocument(docType, docLabel),
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload, size: 18),
                label: Text(
                  isUploading ? "Uploading..." : "Upload Document",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // REUSABLE COMPONENTS
  // ============================================================
  Widget _buildInfoBanner(String message, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.info_outline,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final displayValue = value.isEmpty ? 'Not specified' : value;
    final isMissing = value.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMissing ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMissing ? Colors.orange.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isMissing ? Colors.orange : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isMissing ? Colors.orange.shade800 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (isMissing)
            Icon(
              Icons.warning_amber,
              size: 18,
              color: Colors.orange.shade400,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back button (shown on tabs 2 and 3)
            if (_currentTabIndex > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(_currentTabIndex - 1);
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text("Back"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C63FF),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (_currentTabIndex > 0) const SizedBox(width: 12),

            // Next / Submit button
            Expanded(
              flex: _currentTabIndex > 0 ? 1 : 1,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : (_currentTabIndex < _tabLabels.length - 1
                        ? () {
                            _tabController.animateTo(_currentTabIndex + 1);
                          }
                        : _submitApplication),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _currentTabIndex < _tabLabels.length - 1
                            ? Icons.arrow_forward
                            : Icons.check_circle,
                        size: 18,
                      ),
                label: Text(
                  _isSubmitting
                      ? "Submitting..."
                      : (_currentTabIndex < _tabLabels.length - 1
                          ? "Next"
                          : "Submit Application"),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentTabIndex < _tabLabels.length - 1
                      ? const Color(0xFF6C63FF)
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}