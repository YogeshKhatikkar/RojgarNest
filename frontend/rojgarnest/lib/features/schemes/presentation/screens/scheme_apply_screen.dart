// lib/features/schemes/presentation/screens/scheme_apply_screen.dart
// ✅ COMPLETE FIXED VERSION — PAYMENT FIRST, THEN APPLICATION
// ✅ FIXED: Added http import
// ✅ REMOVED: Bank Details Tab (auto-filled from profile)
// ✅ REMOVED: Aadhaar Card number field (auto-filled from profile)
// ✅ REMOVED: Back button from AppBar (automaticallyImplyLeading: false)
// ✅ Tabs shown for: Personal Details, Address, Documents
// ✅ CRITICAL FIX: Payment is now REQUIRED before application creation
// ✅ CRITICAL FIX: Always shows APPLICATION NUMBER (not application_id)
// ✅ NEW: PaymentScreen now returns Map<String, dynamic>? (not bool?)
// ✅ NEW: Success dialog shows Application Number prominently
// ✅ ✅ ✅ CRITICAL LOGOUT FIX (2026-10-15):
//      - Removed `Navigator.pop(context)` after success dialog.
//      - Added `onApplicationSubmitted` callback for the parent to handle navigation.
//      - Added `_resetAfterSuccess()` helper that resets local state ONLY.
//      - Works correctly in BOTH fullscreen and inline/embedded modes.
//      - This mirrors the Jobs/Services pattern which never popped the parent route.
// ✅ ✅ ✅ NEW FIX (2026-10-16): APPLICATION NUMBER NOW SHOWS CORRECTLY
//      - Scheme backend uses `application_id` field as the human-readable
//        Application Number (e.g. "20261000020"), NOT a Mongo ObjectId.
//      - `_resolveApplicationNumber()` now prioritizes:
//          1. top-level `application_number`
//          2. top-level `application_id` (if non-Mongo)
//          3. nested `data.application_number`
//          4. nested `data.application_id` (if non-Mongo)
//          5. detail endpoint: `application.application_number`
//          6. detail endpoint: `application.application_id` (if non-Mongo)
//          7. detail endpoint: `data.application_number`
//          8. detail endpoint: `data.application.application_number`
//      - Mongo ObjectId (24-char hex) is NEVER used for display.
//      - If nothing resolves, dialog shows "Generating…" instead of a wrong ID.
// ✅ ✅ ✅ NEW FIX (2026-10-17): SUCCESS DIALOG NOW SHOWS "PAYMENT SUCCESSFULLY"
//      - Previously the dialog showed `status: "pending"` (the scheme
//        review status from the backend `/schemes/apply` response).
//      - Jobs and Services show "payment_verified" because they pull
//        the status from the PAYMENT VERIFICATION response, not the
//        application response.
//      - Now scheme flow does the same: the success dialog receives
//          • status: 'payment_verified' (or the paymentResult['status'])
//          • paymentId: the Razorpay payment ID (razorpay_payment_id)
//        so the "Status" row shows PAYMENT VERIFIED / PAYMENT SUCCESSFUL
//        exactly like Job and Service flows.
// ✅ ✅ ✅ NEW FIX (2026-10-17): REMOVED "Address Line 2" FIELD
//      - The `addressLine2Ctrl` controller has been removed.
//      - The "Address Line 2" read-only field is no longer rendered.
//      - The auto-fill line for `address_line2` is gone.
//      - The `address_line2` key is no longer sent in the applicant
//        address payload to `/payment/razorpay/create-order` or
//        `/schemes/apply`.
//      - All other address fields (Address Line 1, Village/City,
//        District, State, Pincode, Country) remain untouched.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/core/config/api_config.dart';
import 'package:rojgarnest/core/master_date/schemes_data.dart';
import 'package:rojgarnest/features/payment/presentation/screens/payment_screen.dart';
import 'package:rojgarnest/features/payment/presentation/payment.dart'
    show PaymentType;
import 'package:rojgarnest/features/payment/presentation/widgets/application_success_dialog.dart';

// ============================================================
// SCHEME APPLY SCREEN
// ============================================================

class SchemeApplyScreen extends StatefulWidget {
  final GovernmentScheme scheme;

  /// ✅ NEW: Callback invoked when the application is submitted successfully
  /// (i.e. user tapped "Done" on the success dialog).
  ///
  /// The SchemeApplyScreen NEVER calls `Navigator.pop(context)` on success.
  /// Instead it delegates navigation to the parent via this callback.
  ///
  /// - In inline/embedded mode (UserDashboard panel), the parent closes
  ///   the inline apply view without touching the dashboard route.
  /// - In fullscreen mode, the parent can simply `Navigator.pop(context)`.
  final VoidCallback? onApplicationSubmitted;

  const SchemeApplyScreen({
    super.key,
    required this.scheme,
    this.onApplicationSubmitted,
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
  // ✅ FEE CONSTANTS — SAME AS JOB & SERVICE
  // ============================================================
  static const double GST_PERCENT = 18.0;
  static const int SERVICE_CHARGE = 50;
  static const int BASE_SCHEME_FEE = 0; // Schemes are typically free

  // ============================================================
  // LOADING STATES
  // ============================================================
  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  bool _profileComplete = false;
  List<String> _missingFields = [];

  // ✅ Payment state
  bool _isPaymentProcessing = false;
  bool _paymentCompleted = false;
  String? _razorpayOrderId;
  String? _paymentId;

  // ✅ NEW: Track the actual Razorpay payment ID for the success dialog
  String? _razorpayPaymentId;

  // ============================================================
  // PROFILE DATA (Auto-filled)
  // ============================================================
  Map<String, dynamic> _profileData = {};

  // ============================================================
  // PERSONAL DETAILS (Read-only, auto-filled from profile)
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
  // ✅ REMOVED: addressLine2Ctrl (Address Line 2 removed per request)
  // ============================================================
  final TextEditingController addressLine1Ctrl = TextEditingController();
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
  // FEE CALCULATION
  // ============================================================
  int get _applicationFee => BASE_SCHEME_FEE;
  int get _serviceCharge => SERVICE_CHARGE;
  int get _subtotal => _applicationFee + _serviceCharge;
  int get _gstAmount => ((_subtotal * GST_PERCENT) / 100).round();
  int get _totalFee => _subtotal + _gstAmount;

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
    // ✅ REMOVED: addressLine2Ctrl.dispose();
    villageCityCtrl.dispose();
    districtCtrl.dispose();
    stateCtrl.dispose();
    pincodeCtrl.dispose();
    countryCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE DATA FROM BACKEND
  // ============================================================
  Future<void> _loadProfileData() async {
    setState(() => _isLoadingProfile = true);

    try {
      debugPrint("=" * 70);
      debugPrint("📥 LOADING PROFILE DATA FOR SCHEME APPLICATION");
      debugPrint("   Scheme: ${widget.scheme.schemeName}");
      debugPrint("=" * 70);

      final response = await DioClient.dio.get('/schemes/profile-data');

      if (response.data['success'] == true) {
        _profileData = response.data;

        final rawMissingFields = List<String>.from(
          response.data['missing_fields'] ?? [],
        );

        _missingFields = rawMissingFields
            .where((field) =>
                !_bankRelatedFields.contains(field.toLowerCase()))
            .toList();

        _profileComplete = _missingFields.isEmpty;

        debugPrint("✅ Profile data loaded");
        debugPrint("   Raw Missing Fields: $rawMissingFields");
        debugPrint("   Filtered Missing Fields: $_missingFields");
        debugPrint("   Profile Complete: $_profileComplete");

        _autoFillPersonalDetails(response.data['applicant_details'] ?? {});
        _autoFillAddressDetails(response.data['applicant_address'] ?? {});
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

    debugPrint("✅ Personal details auto-filled");
  }

  void _autoFillAddressDetails(Map<String, dynamic> address) {
    addressLine1Ctrl.text = address['address_line1']?.toString() ?? '';
    // ✅ REMOVED: addressLine2Ctrl.text = address['address_line2']?.toString() ?? '';
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
      List<String> allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

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
  // ✅ FEE BREAKDOWN DIALOG
  // ============================================================
  Future<bool?> _showFeeBreakdownDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.currency_rupee,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Fee Breakdown",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFeeRow("Application Fee", _applicationFee),
            const SizedBox(height: 8),
            _buildFeeRow("Service Charge", _serviceCharge),
            const SizedBox(height: 8),
            _buildFeeRow("Subtotal", _subtotal, isBold: true),
            const SizedBox(height: 8),
            _buildFeeRow(
              "GST (${GST_PERCENT.toInt()}% on ₹$_subtotal)",
              _gstAmount,
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Total Payable",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
                Text(
                  "₹$_totalFee",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Proceed to Pay"),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, int amount, {bool isBold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          "₹$amount",
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ SUBMIT APPLICATION WITH PAYMENT
  // ============================================================
  Future<void> _submitApplicationWithPayment() async {
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
        _tabController.animateTo(2);
        return;
      }
    }

    final bool? confirmPayment = await _showFeeBreakdownDialog();
    if (confirmPayment != true) {
      debugPrint("❌ User cancelled fee confirmation");
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _isPaymentProcessing = true;
    });

    try {
      // ============================================================
      // ✅ STEP 2: Build payload
      // ============================================================
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
      };

      // ✅ REMOVED: 'address_line2': addressLine2Ctrl.text.trim(),
      final applicantAddress = {
        'address_line1': addressLine1Ctrl.text.trim(),
        'village_city': villageCityCtrl.text.trim(),
        'district': districtCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'pincode': pincodeCtrl.text.trim(),
        'country': countryCtrl.text.trim(),
      };

      final documents = _uploadedDocuments.values.map((doc) {
        return {
          'document_type': doc['document_type'],
          'document_name': doc['document_name'],
          'document_url': doc['document_url'],
          'public_id': doc['public_id'],
        };
      }).toList();

      debugPrint("=" * 70);
      debugPrint("📤 SUBMITTING SCHEME APPLICATION WITH PAYMENT");
      debugPrint("   Scheme ID: ${widget.scheme.schemeId}");
      debugPrint("   Scheme Name: ${widget.scheme.schemeName}");
      debugPrint("   Application Fee: ₹$_applicationFee");
      debugPrint("   Service Charge: ₹$_serviceCharge");
      debugPrint("   Subtotal: ₹$_subtotal");
      debugPrint("   GST (18% on ₹$_subtotal): ₹$_gstAmount");
      debugPrint("   TOTAL: ₹$_totalFee");
      debugPrint("=" * 70);

      // ============================================================
      // ✅ STEP 3: Create Razorpay order
      // ============================================================
      final orderResponse = await DioClient.dio.post(
        '/payment/razorpay/create-order',
        data: {
          "amount": _totalFee,
          "application_fee": _applicationFee,
          "service_charge": _serviceCharge,
          "subtotal": _subtotal,
          "gst_amount": _gstAmount,
          "total_amount": _totalFee,
          "use_provided_amount": true,

          "payment_type": "scheme",
          "application_type": "schemes",

          "scheme_id": widget.scheme.schemeId,
          "scheme_name": widget.scheme.schemeName,
          "scheme_name_hindi": widget.scheme.schemeNameHindi,
          "scheme_level": widget.scheme.level,
          "scheme_state": widget.scheme.state,
          "scheme_category": widget.scheme.category,

          "applicant_details": applicantDetails,
          "applicant_address": applicantAddress,
          "documents": documents,

          "user_email": emailCtrl.text.trim(),
          "user_name": fullNameCtrl.text.trim(),
          "user_mobile": mobileCtrl.text.trim(),

          "category_used": "scheme",
        },
      );

      if (!mounted) return;

      if (orderResponse.data['success'] != true) {
        throw Exception(
          orderResponse.data['message'] ?? "Payment initialization failed",
        );
      }

      final String orderId =
          (orderResponse.data['order_id'] ?? '').toString();
      final String paymentId = (orderResponse.data['payment_id'] ??
              orderResponse.data['application_id'] ??
              'temp_${DateTime.now().millisecondsSinceEpoch}')
          .toString();

      _razorpayOrderId = orderId;
      _paymentId = paymentId;

      debugPrint("✅ Order created: $orderId");
      debugPrint("   Payment ID: $paymentId");
      debugPrint("   Total amount sent: ₹$_totalFee");
      debugPrint("   payment_type: scheme");
      debugPrint("   application_type: schemes");

      if (orderId.isEmpty) {
        throw Exception("Order ID is missing from response");
      }

      setState(() => _isSubmitting = false);

      // ============================================================
      // ✅ STEP 4: Open PaymentScreen
      // ============================================================
      final paymentResult = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PaymentScreen(
          schemeId: widget.scheme.schemeId,
          schemeName: widget.scheme.schemeName,
          schemeNameHindi: widget.scheme.schemeNameHindi,
          schemeLevel: widget.scheme.level,
          schemeState: widget.scheme.state,
          schemeCategory: widget.scheme.category,
          schemeData: {
            'scheme_id': widget.scheme.schemeId,
            'scheme_name': widget.scheme.schemeName,
            'scheme_name_hindi': widget.scheme.schemeNameHindi,
            'level': widget.scheme.level,
            'state': widget.scheme.state,
            'category': widget.scheme.category,
            'icon': widget.scheme.icon,
            'color': widget.scheme.color,
          },

          serviceId: widget.scheme.schemeId,
          serviceType: 'scheme',
          serviceSubType: widget.scheme.schemeId,
          subServiceName: widget.scheme.schemeName,

          formData: {
            'applicant_details': applicantDetails,
            'applicant_address': applicantAddress,
            'documents': documents,
          },
          userEmail: emailCtrl.text.trim(),
          userName: fullNameCtrl.text.trim(),
          userMobile: mobileCtrl.text.trim(),

          amount: _totalFee,
          categoryUsed: "scheme",
          paymentId: paymentId,
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          onPaymentSuccess: () {
            _paymentCompleted = true;
            debugPrint("✅ Payment success callback triggered");
          },
          paymentType: PaymentType.scheme,
        ),
      );

      if (!mounted) return;

      // ============================================================
      // ✅ STEP 5: ONLY after payment success → create application
      // ============================================================
      if (paymentResult != null && paymentResult['success'] == true) {
        debugPrint("=" * 70);
        debugPrint("✅ PAYMENT SUCCESSFUL — NOW CREATING APPLICATION");
        debugPrint("   Razorpay payment id: ${paymentResult['payment_id']}");
        debugPrint("   Payment status returned: ${paymentResult['status']}");
        debugPrint("=" * 70);

        // ✅ Capture the real Razorpay payment ID for the success dialog
        _razorpayPaymentId =
            paymentResult['payment_id']?.toString().isNotEmpty == true
                ? paymentResult['payment_id'].toString()
                : null;

        await _createApplicationAfterPayment(
          applicantDetails: applicantDetails,
          applicantAddress: applicantAddress,
          documents: documents,
          paymentId: paymentId,
          orderId: orderId,
          paymentResult: paymentResult,
        );
      } else {
        debugPrint("❌ Payment cancelled — NO application created");
        if (mounted) {
          showMessage(
            context,
            "Payment cancelled. No application was created.",
            isError: true,
          );
        }
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
        setState(() {
          _isSubmitting = false;
          _isPaymentProcessing = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ Helper: Detect a MongoDB ObjectId (24-char hex string)
  //    We never want to display these in the success dialog.
  // ============================================================
  bool _isMongoObjectId(String? value) {
    if (value == null) return false;
    final s = value.trim();
    if (s.length != 24) return false;
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(s);
  }

  // ============================================================
  // ✅ Helper: Pick the first non-empty, non-Mongo value
  // ============================================================
  String? _pickHumanReadable(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    if (s.toLowerCase() == 'null') return null;
    if (s.toLowerCase() == 'undefined') return null;
    if (_isMongoObjectId(s)) return null; // never display Mongo ID
    return s;
  }

  // ============================================================
  // ✅ Resolve the actual Application Number
  // ------------------------------------------------------------
  // Priority order (most-reliable first):
  //   1. top-level `application_number`
  //   2. top-level `application_id` (if non-Mongo)
  //   3. nested `data.application_number`
  //   4. nested `data.application_id` (if non-Mongo)
  //   5. nested `data.application.application_number`
  //   6. nested `data.application.application_id` (if non-Mongo)
  //   7. detail endpoint: `application_number` (top-level)
  //   8. detail endpoint: `application_id` (top-level, non-Mongo)
  //   9. detail endpoint: `application.application_number`
  //  10. detail endpoint: `application.application_id` (non-Mongo)
  //  11. detail endpoint: `data.application_number`
  //  12. detail endpoint: `data.application_id` (non-Mongo)
  //  13. detail endpoint: `data.application.application_number`
  //  14. detail endpoint: `data.application.application_id` (non-Mongo)
  //
  // Returns null if nothing valid found.
  // ============================================================
  Future<String?> _resolveApplicationNumber({
    required Map<String, dynamic> applyResponse,
    required String fallbackApplicationId,
  }) async {
    debugPrint("=" * 70);
    debugPrint("🔎 RESOLVING APPLICATION NUMBER");
    debugPrint("   applyResponse keys: ${applyResponse.keys.toList()}");
    debugPrint("   fallback id: $fallbackApplicationId");
    debugPrint("=" * 70);

    // ---------- Attempt 1: top-level application_number ----------
    final directNumber = _pickHumanReadable(applyResponse['application_number']);
    if (directNumber != null) {
      debugPrint("✅ [1] top-level application_number: $directNumber");
      return directNumber;
    }

    // ---------- Attempt 2: top-level application_id ----------
    final directId = _pickHumanReadable(applyResponse['application_id']);
    if (directId != null) {
      debugPrint("✅ [2] top-level application_id (human-readable): $directId");
      return directId;
    }

    // ---------- Attempt 3: nested data map ----------
    final data = applyResponse['data'];
    if (data is Map) {
      final nestedNumber =
          _pickHumanReadable(data['application_number']);
      if (nestedNumber != null) {
        debugPrint("✅ [3] data.application_number: $nestedNumber");
        return nestedNumber;
      }

      final nestedId = _pickHumanReadable(data['application_id']);
      if (nestedId != null) {
        debugPrint("✅ [4] data.application_id (human-readable): $nestedId");
        return nestedId;
      }

      // ---------- Attempt 5/6: data.application.{number,id} ----------
      final nestedApp = data['application'];
      if (nestedApp is Map) {
        final aNumber =
            _pickHumanReadable(nestedApp['application_number']);
        if (aNumber != null) {
          debugPrint("✅ [5] data.application.application_number: $aNumber");
          return aNumber;
        }
        final aId = _pickHumanReadable(nestedApp['application_id']);
        if (aId != null) {
          debugPrint(
              "✅ [6] data.application.application_id (human-readable): $aId");
          return aId;
        }
      }
    }

    // ============================================================
    // Fallback: hit the detail endpoint
    // ============================================================
    if (fallbackApplicationId.isEmpty) {
      debugPrint("⚠️ No fallback ID to fetch — cannot resolve number");
      return null;
    }

    try {
      debugPrint(
          "🔎 Fetching /schemes/application/$fallbackApplicationId for number...");

      final detailRes = await DioClient.dio.get(
        '/schemes/application/$fallbackApplicationId',
      );

      Map<String, dynamic> body = {};
      if (detailRes.data is Map) {
        body = Map<String, dynamic>.from(detailRes.data as Map);
      }

      debugPrint("   detail body keys: ${body.keys.toList()}");

      // ---------- Attempt 7: body.application_number ----------
      final bodyNumber =
          _pickHumanReadable(body['application_number']);
      if (bodyNumber != null) {
        debugPrint("✅ [7] detail application_number: $bodyNumber");
        return bodyNumber;
      }

      // ---------- Attempt 8: body.application_id (non-Mongo) ----------
      final bodyId = _pickHumanReadable(body['application_id']);
      if (bodyId != null) {
        debugPrint(
            "✅ [8] detail application_id (human-readable): $bodyId");
        return bodyId;
      }

      // ---------- Attempt 9/10: body.application.{number,id} ----------
      final app = body['application'];
      if (app is Map) {
        final aNumber =
            _pickHumanReadable(app['application_number']);
        if (aNumber != null) {
          debugPrint(
              "✅ [9] detail application.application_number: $aNumber");
          return aNumber;
        }
        final aId =
            _pickHumanReadable(app['application_id']);
        if (aId != null) {
          debugPrint(
              "✅ [10] detail application.application_id (human-readable): $aId");
          return aId;
        }
      }

      // ---------- Attempt 11/12: body.data.{number,id} ----------
      final dataMap = body['data'];
      if (dataMap is Map) {
        final dNumber =
            _pickHumanReadable(dataMap['application_number']);
        if (dNumber != null) {
          debugPrint(
              "✅ [11] detail data.application_number: $dNumber");
          return dNumber;
        }
        final dId =
            _pickHumanReadable(dataMap['application_id']);
        if (dId != null) {
          debugPrint(
              "✅ [12] detail data.application_id (human-readable): $dId");
          return dId;
        }

        // ---------- Attempt 13/14: data.application.{number,id} ----------
        final inner = dataMap['application'];
        if (inner is Map) {
          final iNumber =
              _pickHumanReadable(inner['application_number']);
          if (iNumber != null) {
            debugPrint(
                "✅ [13] detail data.application.application_number: $iNumber");
            return iNumber;
          }
          final iId =
              _pickHumanReadable(inner['application_id']);
          if (iId != null) {
            debugPrint(
                "✅ [14] detail data.application.application_id (human-readable): $iId");
            return iId;
          }
        }
      }

      debugPrint(
          "⚠️ Detail fetch succeeded but had no human-readable application number");
    } catch (e) {
      debugPrint(
          "⚠️ Could not fetch application detail to resolve number: $e");
    }

    debugPrint("❌ No human-readable application number found anywhere");
    return null;
  }

  // ============================================================
  // ✅ CREATE APPLICATION AFTER PAYMENT SUCCESS
  // ✅ ✅ ✅ CRITICAL FIX (2026-10-15):
  //      - NO MORE `Navigator.pop(context)` after success dialog.
  //      - We call `_resetAfterSuccess()` which ONLY resets local state.
  //      - The parent handles navigation via `widget.onApplicationSubmitted`.
  //      - This prevents the entire route stack (UserDashboard) from being
  //        popped when the apply screen is embedded/inline.
  // ✅ ✅ ✅ NEW FIX (2026-10-16):
  //      - Now calls `_resolveApplicationNumber()` which prefers
  //        `application_number` and falls back to a human-readable
  //        `application_id` — NEVER the Mongo ObjectId.
  // ✅ ✅ ✅ NEW FIX (2026-10-17):
  //      - Success dialog now receives `status: 'payment_verified'`
  //        (or the status returned by the payment flow) so it shows
  //        "PAYMENT VERIFIED" / "PAYMENT SUCCESSFULLY" — exactly like
  //        Job and Service flows.
  //      - `paymentId` passed to the dialog is now the real Razorpay
  //        payment ID (razorpay_payment_id), not our internal payment_id.
  // ============================================================
  Future<void> _createApplicationAfterPayment({
    required Map<String, dynamic> applicantDetails,
    required Map<String, dynamic> applicantAddress,
    required List<Map<String, dynamic>> documents,
    required String paymentId,
    required String orderId,
    required Map<String, dynamic> paymentResult,
  }) async {
    try {
      debugPrint("=" * 70);
      debugPrint("📤 CREATING SCHEME APPLICATION AFTER PAYMENT");
      debugPrint("   Payment ID: $paymentId");
      debugPrint("   Order ID: $orderId");
      debugPrint("=" * 70);

      final payload = {
        'scheme_id': widget.scheme.schemeId,
        'scheme_name': widget.scheme.schemeName,
        'scheme_name_hindi': widget.scheme.schemeNameHindi,
        'scheme_level': widget.scheme.level,
        'scheme_state': widget.scheme.state,
        'scheme_category': widget.scheme.category,
        'applicant_details': applicantDetails,
        'applicant_address': applicantAddress,
        'documents': documents,

        'application_type': 'schemes',
        'payment_type': 'scheme',
        'category_used': 'scheme',

        'payment_id': paymentId,
        'razorpay_payment_id': _razorpayPaymentId,
        'razorpay_order_id': orderId,
        'payment_amount': _totalFee,
        'application_fee': _applicationFee,
        'service_charge': _serviceCharge,
        'gst_amount': _gstAmount,
        'payment_status': 'paid',
        'payment_verified': true,
      };

      debugPrint("📦 Payload prepared:");
      debugPrint("   application_type: ${payload['application_type']}");
      debugPrint("   payment_type: ${payload['payment_type']}");
      debugPrint("   category_used: ${payload['category_used']}");
      debugPrint("   Documents: ${documents.length}");
      debugPrint("   Payment: ₹$_totalFee");

      final response = await DioClient.dio.post(
        '/schemes/apply',
        data: payload,
      );

      debugPrint("📥 Response: ${response.data}");

      if (!mounted) return;

      if (response.data is Map && response.data['success'] == true) {
        final responseMap = Map<String, dynamic>.from(response.data as Map);

        // ============================================================
        // ✅ Extract a fallback ID for the detail-endpoint lookup.
        //    This is used ONLY to fetch the real Application Number,
        //    never displayed.
        // ============================================================
        final rawFallbackId = responseMap['application_id'] ??
            responseMap['_id'] ??
            (responseMap['data'] is Map
                ? (responseMap['data'] as Map)['application_id']
                : null) ??
            (responseMap['data'] is Map
                ? (responseMap['data'] as Map)['_id']
                : null) ??
            '';
        final fallbackIdStr = rawFallbackId.toString();

        debugPrint("🔍 Fallback ID for lookup: '$fallbackIdStr'");

        // ============================================================
        // ✅ Resolve the real Application Number (may return null)
        // ============================================================
        final resolvedNumber = await _resolveApplicationNumber(
          applyResponse: responseMap,
          fallbackApplicationId: fallbackIdStr,
        );

        if (!mounted) return;

        // ============================================================
        // ✅ Decide what to show in the dialog
        //    - If resolved → show that (e.g. "20261000020")
        //    - If not resolved → show "Generating…" (never show Mongo ID)
        // ============================================================
        String displayNumber;
        if (resolvedNumber != null && resolvedNumber.isNotEmpty) {
          displayNumber = resolvedNumber;
        } else {
          displayNumber = 'Generating…';
          debugPrint(
              "⚠️ application_number could not be resolved — using placeholder");
        }

        // ============================================================
        // ✅ NEW (2026-10-17): Payment status shown in the dialog
        // ------------------------------------------------------------
        // Jobs and Services show "PAYMENT VERIFIED" because they pass
        // the status from the PAYMENT VERIFICATION response.
        //
        // We now do the same:
        //   • Prefer paymentResult['status'] (e.g. 'payment_verified')
        //   • Fallback to 'payment_verified'
        // ------------------------------------------------------------
        final paymentStatusString =
            paymentResult['status']?.toString().isNotEmpty == true
                ? paymentResult['status'].toString()
                : 'payment_verified';

        // ============================================================
        // ✅ NEW (2026-10-17): Payment ID shown in the dialog
        // ------------------------------------------------------------
        // Prefer the real Razorpay payment ID (razorpay_payment_id).
        // Fallback to the paymentResult payment id, then our internal ID.
        // ------------------------------------------------------------
        final displayPaymentId =
            _razorpayPaymentId?.isNotEmpty == true
                ? _razorpayPaymentId
                : (paymentResult['payment_id']?.toString().isNotEmpty == true
                    ? paymentResult['payment_id'].toString()
                    : paymentId);

        debugPrint("=" * 70);
        debugPrint("✅ APPLICATION CREATED SUCCESSFULLY");
        debugPrint("   Display Number: $displayNumber");
        debugPrint("   Payment Status (for dialog): $paymentStatusString");
        debugPrint("   Payment ID (for dialog): $displayPaymentId");
        debugPrint("   (fallback id: $fallbackIdStr)");
        debugPrint("=" * 70);

        // ✅ Show the success dialog with the resolved number,
        //    payment status, and payment id.
        // ✅ CRITICAL: onDone callback resets local state ONLY.
        //              We NEVER call Navigator.pop here.
        await ApplicationSuccessDialog.show(
          context,
          applicationNumber: displayNumber,
          title: widget.scheme.schemeName,
          subtitle: widget.scheme.level == 'central'
              ? 'Central Scheme'
              : 'State Scheme',
          paymentType: 'Scheme',
          amountPaid: _totalFee,

          // ✅ NEW: Real Razorpay payment ID
          paymentId: displayPaymentId,

          // ✅ NEW: Payment status → "PAYMENT VERIFIED" / "PAYMENT SUCCESSFUL"
          status: paymentStatusString,

          onDone: () {
            // ✅ FIX: Reset local state — DO NOT touch Navigator.
            _resetAfterSuccess();

            // ✅ FIX: Let the parent decide navigation.
            //         - Inline mode → parent closes inline view (dashboard intact).
            //         - Fullscreen mode → parent calls Navigator.pop.
            widget.onApplicationSubmitted?.call();
          },
        );
      } else {
        throw Exception(
          response.data['message'] ?? 'Application creation failed',
        );
      }
    } catch (e) {
      debugPrint("❌ Failed to create application after payment: $e");
      if (mounted) {
        showMessage(
          context,
          "Payment successful but application creation failed. "
          "Please contact support with Payment ID: ${_razorpayPaymentId ?? paymentId}",
          isError: true,
        );
      }
    }
  }

  // ============================================================
  // ✅ FIX: Reset local state after a successful application.
  //         This is safe in BOTH fullscreen and inline/embedded modes.
  //         It NEVER calls Navigator.pop — the parent decides navigation.
  // ============================================================
  void _resetAfterSuccess() {
    if (!mounted) return;

    debugPrint("=" * 70);
    debugPrint("🔄 SchemeApplyScreen: resetting state after success");
    debugPrint("=" * 70);

    setState(() {
      _paymentCompleted = true;
      _isSubmitting = false;
      _isPaymentProcessing = false;
      _uploadedDocuments.clear();
      _razorpayOrderId = null;
      _paymentId = null;
      _razorpayPaymentId = null;
    });

    debugPrint("✅ SchemeApplyScreen: state reset complete (no pop)");
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
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
          if (!_profileComplete && _missingFields.isNotEmpty)
            _buildProfileWarning(),

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
  // ✅ REMOVED: "Address Line 2" field
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
              // ✅ REMOVED: "Address Line 2" read-only field
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
          _buildFeeCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // FEE CARD — shows breakdown before payment
  // ============================================================
  Widget _buildFeeCard() {
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
                child: const Icon(Icons.receipt_long,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                "Fee Breakdown",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFeeRow("Application Fee", _applicationFee),
          const SizedBox(height: 8),
          _buildFeeRow("Service Charge", _serviceCharge),
          const SizedBox(height: 8),
          _buildFeeRow("Subtotal", _subtotal, isBold: true),
          const SizedBox(height: 8),
          _buildFeeRow(
            "GST (${GST_PERCENT.toInt()}% on ₹$_subtotal)",
            _gstAmount,
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Total Payable",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
              Text(
                "₹$_totalFee",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
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
  // BOTTOM BAR — PAY & SUBMIT
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

            Expanded(
              flex: _currentTabIndex > 0 ? 1 : 1,
              child: ElevatedButton.icon(
                onPressed: (_isSubmitting || _isPaymentProcessing)
                    ? null
                    : (_currentTabIndex < _tabLabels.length - 1
                        ? () {
                            _tabController.animateTo(_currentTabIndex + 1);
                          }
                        : _submitApplicationWithPayment),
                icon: (_isSubmitting || _isPaymentProcessing)
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
                            : Icons.payment,
                        size: 18,
                      ),
                label: Text(
                  (_isSubmitting || _isPaymentProcessing)
                      ? "Processing..."
                      : (_currentTabIndex < _tabLabels.length - 1
                          ? "Next"
                          : "Pay ₹$_totalFee & Submit"),
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