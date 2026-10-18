// lib/features/services/presentation/screens/apply_service_screen.dart
// ✅ FULLY UPDATED VERSION — ONLY BASIC DETAILS + ADDRESS
// ✅ REMOVED: Aadhaar number field
// ✅ REMOVED: All bank details fields (bank name, account no, IFSC, etc.)
// ✅ REMOVED: "Some profile fields are missing" orange warning banner
// ✅ REMOVED: ALL sub-type extra fields (requiredFields) — user uploads docs
//           instead of typing any details
// ✅ KEPT: Applicant basic details (name, father, mother, DOB, gender,
//           category, marital status, mobile, email, income, BPL, disability)
// ✅ KEPT: Full address section (line1, line2, village/city, district,
//           state, pincode, country)
// ✅ User only needs to upload documents and click Pay & Submit

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/services/data/service_repository.dart';
import 'package:rojgarnest/features/services/models/service_types.dart';
import 'package:rojgarnest/features/payment/presentation/screens/payment_screen.dart';
import 'package:rojgarnest/features/payment/presentation/payment.dart'
    show PaymentType;
import 'package:rojgarnest/features/payment/presentation/widgets/application_success_dialog.dart';

class ApplyServiceScreen extends StatefulWidget {
  const ApplyServiceScreen({super.key});

  @override
  State<ApplyServiceScreen> createState() => _ApplyServiceScreenState();
}

class _ApplyServiceScreenState extends State<ApplyServiceScreen> {
  // ==================== STATE ====================
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentStep = 0; // 0 = Service, 1 = SubType, 2 = Form

  // User Details
  String _userEmail = '';
  String _userName = '';
  String _userMobile = '';
  bool _userDetailsLoaded = false;

  // Selections
  ServiceType? _selectedService;
  ServiceSubType? _selectedSubType;

  // ✅ CRITICAL FIX: Initialize with a valid default
  String _tempSessionId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

  // Form controllers
  final Map<String, TextEditingController> _controllers = {};

  // ✅ Uploaded docs (stored locally until payment success)
  final Map<String, _UploadedDoc> _uploadedDocs = {};

  // ✅ Per-doc upload progress
  final Map<String, bool> _isUploadingDoc = {};

  // ============================================================
  // ✅ AUTO-FETCHED PROFILE STATE
  // ============================================================
  bool _loadingProfile = false;
  bool _profileLoaded = false;

  Map<String, dynamic> _applicantDetails = {};
  Map<String, dynamic> _applicantAddress = {};

  // ✅ Auto-filled field keys — ONLY basic details + address.
  // Aadhaar + bank + sub-type extras are NOT shown.
  static const List<String> _autoFilledFieldKeys = [
    // Applicant basic details
    'full_name',
    'father_name',
    'mother_name',
    'date_of_birth',
    'gender',
    'category',
    'marital_status',
    'mobile',
    'email',
    'annual_income',
    'bpl_status',
    'disability_status',
    'disability_percentage',
    // Address
    'address_line1',
    'address_line2',
    'village_city',
    'district',
    'state',
    'pincode',
    'country',
  ];

  // Payment
  String? _paymentId;
  bool _paymentCompleted = false;
  String? _razorpayOrderId;

  // ============================================================
  // ✅ FEE CONSTANTS
  // ============================================================
  static const double GST_PERCENT = 18.0;
  static const int SERVICE_CHARGE = 50;
  static const int BASE_SERVICE_FEE = 100;

  final List<ServiceType> _allServices = ServiceRepository.getAllServices();

  // ============================================================
  // ✅ FEE BREAKDOWN
  // ============================================================
  int get _applicationFee => BASE_SERVICE_FEE;
  int get _serviceCharge => SERVICE_CHARGE;
  int get _subtotal => _applicationFee + _serviceCharge;
  int get _gstAmount => ((_subtotal * GST_PERCENT) / 100).round();
  int get _totalFee => _subtotal + _gstAmount;

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ==================== USER DETAILS ====================
  Future<void> _loadUserDetails() async {
    if (!mounted) return;
    try {
      final email = await SecureStorage.getEmail();
      final name = await SecureStorage.getName();
      final mobile = await SecureStorage.getMobile();

      if (email != null && email.isNotEmpty) {
        if (mounted) {
          setState(() {
            _userEmail = email;
            _userName = name ?? email.split('@').first;
            _userMobile = mobile ?? '';
            _userDetailsLoaded = true;
            _tempSessionId =
                'temp_${DateTime.now().millisecondsSinceEpoch}_${_userEmail.hashCode}';
          });
        }
        if (mounted) setState(() => _isLoading = false);
        debugPrint("✅ User details loaded: $_userEmail");
        debugPrint("✅ Temp session ID: $_tempSessionId");
        return;
      }

      final response = await DioClient.dio.get('/auth/me');
      if (mounted && response.data is Map) {
        final data = response.data;
        final userData = data['data'] as Map? ?? data;

        _userEmail = userData['email']?.toString() ?? '';
        _userName =
            userData['name']?.toString() ?? _userEmail.split('@').first;
        _userMobile = userData['mobile']?.toString() ?? '';
        _userDetailsLoaded = true;

        if (_userEmail.isNotEmpty) await SecureStorage.setEmail(_userEmail);
        if (_userName.isNotEmpty) await SecureStorage.setName(_userName);
        if (_userMobile.isNotEmpty) await SecureStorage.setMobile(_userMobile);

        if (mounted) {
          setState(() {
            _tempSessionId =
                'temp_${DateTime.now().millisecondsSinceEpoch}_${_userEmail.hashCode}';
          });
        }
        debugPrint("✅ Temp session ID (from /auth/me): $_tempSessionId");
      }
    } catch (e) {
      debugPrint("❌ Error loading user details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // ✅ FETCH PROFILE DATA FROM BACKEND
  // Called automatically when user opens the Form tab.
  // Populates ONLY applicant basic details + address.
  // (Aadhaar & bank & sub-type extras are ignored.)
  // ============================================================
  Future<void> _fetchProfileData() async {
    if (_loadingProfile || _profileLoaded) return;

    setState(() => _loadingProfile = true);

    try {
      debugPrint("=" * 70);
      debugPrint("📡 FETCHING PROFILE DATA FOR SERVICE");
      debugPrint("   GET /services/profile-data");
      debugPrint("=" * 70);

      final res = await DioClient.dio.get('/services/profile-data');

      final Map<String, dynamic> body =
          res.data is Map<String, dynamic>
              ? res.data as Map<String, dynamic>
              : (res.data is Map
                  ? Map<String, dynamic>.from(res.data as Map)
                  : <String, dynamic>{});

      final details =
          (body['applicant_details'] as Map?) ?? <String, dynamic>{};
      final address =
          (body['applicant_address'] as Map?) ?? <String, dynamic>{};

      _applicantDetails = Map<String, dynamic>.from(details);
      _applicantAddress = Map<String, dynamic>.from(address);

      debugPrint("✅ Profile data received:");
      debugPrint("   details keys: ${_applicantDetails.keys.toList()}");
      debugPrint("   address keys: ${_applicantAddress.keys.toList()}");

      _applyProfileToControllers();

      if (mounted) {
        setState(() {
          _profileLoaded = true;
          _loadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch profile data: $e");
      if (mounted) {
        setState(() => _loadingProfile = false);
        showMessage(
          context,
          "Could not load profile data. Please complete your profile first.",
          isError: true,
        );
      }
    }
  }

  // ============================================================
  // ✅ APPLY FETCHED PROFILE DATA TO ALL CONTROLLERS
  // NOTE: Aadhaar and Bank fields are intentionally SKIPPED.
  // ============================================================
  void _applyProfileToControllers() {
    void _setController(String key, String value) {
      _controllers.putIfAbsent(
          key, () => TextEditingController()).text = value;
    }

    // ---------- Applicant basic details ----------
    _setController('full_name',
        _applicantDetails['full_name']?.toString() ?? '');
    _setController('father_name',
        _applicantDetails['father_name']?.toString() ?? '');
    _setController('mother_name',
        _applicantDetails['mother_name']?.toString() ?? '');
    _setController('date_of_birth',
        _applicantDetails['date_of_birth']?.toString() ?? '');
    _setController('gender',
        _applicantDetails['gender']?.toString() ?? 'male');
    _setController('category',
        _applicantDetails['category']?.toString() ?? 'General');
    _setController('marital_status',
        _applicantDetails['marital_status']?.toString() ?? 'Unmarried');
    _setController('mobile',
        _applicantDetails['mobile']?.toString() ?? _userMobile);
    _setController('email',
        _applicantDetails['email']?.toString() ?? _userEmail);
    _setController('annual_income',
        _applicantDetails['annual_income']?.toString() ?? '0');
    _setController(
        'bpl_status',
        (_applicantDetails['bpl_status'] == true) ? 'Yes' : 'No');
    _setController(
        'disability_status',
        (_applicantDetails['disability_status'] == true)
            ? 'Yes'
            : 'No');
    _setController('disability_percentage',
        _applicantDetails['disability_percentage']?.toString() ?? '0');

    // ---------- Address ----------
    _setController('address_line1',
        _applicantAddress['address_line1']?.toString() ?? '');
    _setController('address_line2',
        _applicantAddress['address_line2']?.toString() ?? '');
    _setController('village_city',
        _applicantAddress['village_city']?.toString() ?? '');
    _setController('district',
        _applicantAddress['district']?.toString() ?? '');
    _setController('state',
        _applicantAddress['state']?.toString() ?? '');
    _setController('pincode',
        _applicantAddress['pincode']?.toString() ?? '');
    _setController('country',
        _applicantAddress['country']?.toString() ?? 'India');

    // ❌ Aadhaar and Bank fields are intentionally NOT set.
    // ❌ Sub-type extra fields are also NOT set.
  }

  // ==================== FORM INIT ====================
  // ✅ Only initializes controllers for the auto-filled fields.
  // Sub-type's requiredFields are NOT initialised (removed).
  void _initializeForm() {
    _controllers.clear();
    _uploadedDocs.clear();
    _isUploadingDoc.clear();

    if (_selectedSubType != null) {
      // Only ensure all auto-filled keys have controllers
      for (final key in _autoFilledFieldKeys) {
        _controllers.putIfAbsent(
            key, () => TextEditingController());
      }

      // Init upload state for required documents
      for (final doc in _selectedSubType!.requiredDocuments) {
        _isUploadingDoc[doc] = false;
      }
    }

    if (_profileLoaded) {
      _applyProfileToControllers();
    }
  }

  bool _isAutoFilledField(String key) {
    return _autoFilledFieldKeys.contains(key);
  }

  // ==================== SELECTION ====================
  void _selectService(ServiceType service) {
    setState(() {
      _selectedService = service;
      _selectedSubType = null;
      _currentStep = 1;
      _resetSelections();
    });
  }

  void _selectSubType(ServiceSubType subType) {
    setState(() {
      _selectedSubType = subType;
      _currentStep = 2;
      _resetSelections();
    });
    _initializeForm();
    _tempSessionId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${_userEmail.hashCode}';
    debugPrint("🔄 New temp session ID: $_tempSessionId");

    _fetchProfileData();
  }

  void _goBack() {
    setState(() {
      if (_currentStep == 2) {
        _currentStep = 1;
        _selectedSubType = null;
        _resetSelections();
      } else if (_currentStep == 1) {
        _currentStep = 0;
        _selectedService = null;
      }
    });
  }

  void _resetSelections() {
    _controllers.clear();
    _uploadedDocs.clear();
    _isUploadingDoc.clear();
    _paymentCompleted = false;
    _paymentId = null;
    _razorpayOrderId = null;
    _profileLoaded = false;
    _loadingProfile = false;
    _applicantDetails = {};
    _applicantAddress = {};
  }

  // ==================== STRICT URL VALIDATOR ====================
  bool _isValidDocUrl(dynamic value) {
    if (value == null) return false;
    final str = value.toString().trim();
    if (str.isEmpty) return false;

    final lower = str.toLowerCase();
    if (lower == 'null' ||
        lower == 'undefined' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == '-' ||
        lower == 'none' ||
        lower == 'false' ||
        lower == '0') {
      return false;
    }

    if (!str.startsWith('http://') &&
        !str.startsWith('https://') &&
        !str.startsWith('file:') &&
        !str.startsWith('blob:')) {
      return false;
    }

    if (str.length < 12) return false;
    return true;
  }

  // ==================== DOC PICK / UPLOAD / REMOVE ====================
  Future<void> _pickDocument(String docName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          showMessage(context, "File data unavailable", isError: true);
        }
        return;
      }

      const maxBytes = 10 * 1024 * 1024;
      if (file.bytes!.length > maxBytes) {
        if (mounted) {
          showMessage(context, "File too large (max 10 MB)", isError: true);
        }
        return;
      }

      await _uploadDocumentToTempStorage(docName, file.bytes!, file.name);
    } catch (e) {
      debugPrint("❌ _pickDocument error: $e");
      if (mounted) {
        showMessage(
          context,
          "Error picking file: ${_cleanErr(e)}",
          isError: true,
        );
      }
    }
  }

  Future<void> _uploadDocumentToTempStorage(
    String docName,
    Uint8List fileBytes,
    String fileName,
  ) async {
    if (mounted) {
      setState(() => _isUploadingDoc[docName] = true);
    }

    try {
      final token = await SecureStorage.getToken();
      if (token == null) throw Exception("No authentication token found");

      if (_tempSessionId.isEmpty) {
        _tempSessionId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      }

      final docTypeSafe = docName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
        'document_type': docTypeSafe,
        'document_label': docName,
        'temp_session_id': _tempSessionId,
      });

      final response = await DioClient.dio.post(
        '/services/upload-temp-document',
        data: formData,
        options: Options(
          headers: {
            "Content-Type": "multipart/form-data",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (!mounted) return;

      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw Exception(data?['message'] ?? 'Upload failed');
      }

      final docData = data['document'] as Map<String, dynamic>? ?? {};
      final uploadedUrl = docData['url']?.toString() ?? '';

      if (!_isValidDocUrl(uploadedUrl)) {
        throw Exception("Server returned an invalid document URL");
      }

      final doc = _UploadedDoc(
        key: docTypeSafe,
        label: docName,
        url: uploadedUrl,
        publicId: docData['public_id']?.toString(),
        fileName: fileName,
        fileSizeKb: (fileBytes.length / 1024).round(),
        resourceType: docData['resource_type']?.toString() ?? 'raw',
        uploadedAt: DateTime.now(),
      );

      setState(() {
        _uploadedDocs[docName] = doc;
        _isUploadingDoc[docName] = false;
      });

      if (mounted) {
        showMessage(context, "✅ Document uploaded!", isError: false);
      }
    } catch (e) {
      debugPrint("❌ Upload failed for $docName: $e");
      if (mounted) {
        setState(() => _isUploadingDoc[docName] = false);
        showMessage(
          context,
          "Failed to upload document: ${_cleanErr(e)}",
          isError: true,
        );
      }
    }
  }

  Future<void> _removeDocument(String docName) async {
    final uploaded = _uploadedDocs[docName];
    if (uploaded == null) return;

    setState(() {
      _uploadedDocs.remove(docName);
      _isUploadingDoc[docName] = false;
    });

    if (_tempSessionId.isNotEmpty) {
      try {
        await DioClient.dio.delete(
          '/services/delete-temp-document/$_tempSessionId/${uploaded.key}',
        );
      } catch (e) {
        debugPrint("⚠️ Backend removal failed (non-fatal): $e");
      }
    }

    if (mounted) showMessage(context, "Document removed");
  }

  String _cleanErr(dynamic e) {
    return e.toString().replaceAll('Exception:', '').trim();
  }

  // ==================== VALIDATION ====================
  // ✅ Now ONLY validates documents (no sub-type text fields).
  String? _getFieldValue(String key) {
    return _controllers[key]?.text.trim();
  }

  bool _isFormValid() {
    if (_selectedSubType == null) return false;

    // ✅ Only check that required documents are uploaded.
    // (No sub-type text field validation — all fields are auto-filled.)
    for (final doc in _selectedSubType!.requiredDocuments) {
      final uploaded = _uploadedDocs[doc];
      if (uploaded == null) return false;
      if (!_isValidDocUrl(uploaded.url)) return false;
    }

    return true;
  }

  // ============================================================
  // ✅ SUBMIT — Fee dialog → Razorpay order → PaymentScreen
  // ============================================================
  Future<void> _submitApplicationWithPayment() async {
    if (!_isFormValid()) {
      showMessage(
        context,
        "Please upload all required documents",
        isError: true,
      );
      return;
    }

    if (_tempSessionId.trim().isEmpty) {
      _tempSessionId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint("⚠️ Temp session ID was empty, regenerated: $_tempSessionId");
    }

    final bool? confirmPayment = await showDialog<bool>(
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

    if (confirmPayment != true) {
      debugPrint("❌ User cancelled fee confirmation");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ============================================================
      // ✅ STEP 1: Build form data (basic + address only)
      // ============================================================
      final Map<String, dynamic> formFields = {};

      for (final key in _autoFilledFieldKeys) {
        final v = _getFieldValue(key);
        if (v != null && v.isNotEmpty) {
          formFields[key] = v;
        }
      }

      final Map<String, String> documentUrls = {};
      for (final entry in _uploadedDocs.entries) {
        final url = entry.value.url.trim();
        if (url.isNotEmpty) {
          documentUrls[entry.value.key] = url;
        }
      }

      debugPrint("=" * 70);
      debugPrint("📤 SUBMITTING SERVICE APPLICATION");
      debugPrint("   Service: ${_selectedService?.name}");
      debugPrint("   Sub-Type: ${_selectedSubType?.name}");
      debugPrint("   Temp Session: $_tempSessionId");
      debugPrint("   Documents: ${documentUrls.length}");
      debugPrint("   Form Fields (basic + address): ${formFields.length}");
      debugPrint("   Application Fee: ₹$_applicationFee");
      debugPrint("   Service Charge: ₹$_serviceCharge");
      debugPrint("   Subtotal: ₹$_subtotal");
      debugPrint("   GST (18% on ₹$_subtotal): ₹$_gstAmount");
      debugPrint("   TOTAL: ₹$_totalFee");
      debugPrint("=" * 70);

      // ============================================================
      // ✅ STEP 2: Create Razorpay order
      // ============================================================
      final response = await DioClient.dio.post(
        '/payment/razorpay/create-order',
        data: {
          "amount": _totalFee,
          "application_fee": _applicationFee,
          "service_charge": _serviceCharge,
          "subtotal": _subtotal,
          "gst_amount": _gstAmount,
          "total_amount": _totalFee,
          "use_provided_amount": true,

          "payment_type": "service",
          "service_id": _selectedService!.id,
          "service_type": _selectedService!.name,
          "sub_type_id": _selectedSubType!.id,
          "sub_service_name": _selectedSubType!.name,
          "form_data": {
            'fields': formFields,
            'document_urls': documentUrls,
            'temp_session_id': _tempSessionId,
          },
          "user_email": _userEmail,
          "user_name": _userName,
          "user_mobile": _userMobile,
        },
      );

      if (!mounted) return;

      if (response.data['success'] != true) {
        throw Exception(
          response.data['message'] ?? "Payment initialization failed",
        );
      }

      final String paymentId = (response.data['payment_id'] ??
              response.data['application_id'] ??
              _tempSessionId)
          .toString();

      final String orderId =
          (response.data['order_id'] ?? '').toString();

      _paymentId = paymentId;
      _razorpayOrderId = orderId;

      debugPrint("✅ Order created: $orderId");
      debugPrint("   Payment ID: $paymentId");
      debugPrint("   Total amount sent: ₹$_totalFee");

      // ============================================================
      // ✅ STEP 3: Open PaymentScreen
      // ============================================================
      final paymentResult = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PaymentScreen(
          serviceId: _selectedService!.id,
          serviceType: _selectedService!.name,
          serviceSubType: _selectedSubType!.id,
          subServiceName: _selectedSubType!.name,
          formData: {
            'fields': formFields,
            'document_urls': documentUrls,
            'temp_session_id': _tempSessionId,
          },
          userEmail: _userEmail,
          userName: _userName,
          userMobile: _userMobile,
          amount: _totalFee,
          categoryUsed: "service",
          paymentId: paymentId,
          expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          onPaymentSuccess: () {
            _paymentCompleted = true;
            debugPrint("✅ Payment success callback triggered");
          },
          paymentType: PaymentType.service,
        ),
      );

      if (!mounted) return;

      if (paymentResult != null && paymentResult['success'] == true) {
        final appNumber =
            (paymentResult['application_number'] ?? '').toString();
        await ApplicationSuccessDialog.show(
          context,
          applicationNumber: appNumber.isEmpty ? 'N/A' : appNumber,
          title: _selectedSubType!.name,
          subtitle: _selectedService!.name,
          paymentType: 'Service',
          amountPaid: _totalFee,
          paymentId: paymentResult['payment_id']?.toString(),
          status: paymentResult['status']?.toString(),
        );
        _resetForm();
      } else {
        debugPrint("❌ Payment cancelled — NO application created");
      }
    } catch (e) {
      debugPrint("❌ Submit failed: $e");
      if (mounted) {
        showMessage(
          context,
          "Failed to submit: ${_cleanErr(e)}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  void _resetForm() {
    setState(() {
      _selectedService = null;
      _selectedSubType = null;
      _currentStep = 0;
      _resetSelections();
      _tempSessionId =
          'temp_${DateTime.now().millisecondsSinceEpoch}_${_userEmail.hashCode}';
    });
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_userDetailsLoaded) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStep(),
                ),
              ),
              if (_currentStep == 2) _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildServiceSelection();
      case 1:
        return _buildSubTypeSelection();
      case 2:
        return _buildForm();
      default:
        return _buildServiceSelection();
    }
  }

  // ==================== LOADING ====================
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
                            color:
                                const Color(0xFF6C63FF).withOpacity(0.3),
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
                  "AI is loading services...",
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

  // ==================== DESIGN HELPERS ====================
  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
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

  Widget _sectionHeader(
    String title,
    IconData icon, {
    String? subtitle,
    Color? color,
  }) {
    final headerColor = color ?? const Color(0xFF6C63FF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerColor, headerColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [headerColor, headerColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
              Icons.workspace_premium,
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
                  "Apply for Service",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getHeaderSubtitle(),
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

  String _getHeaderSubtitle() {
    switch (_currentStep) {
      case 0:
        return "Choose a service to apply for";
      case 1:
        return _selectedService?.name ?? "Select sub-service";
      case 2:
        return _selectedSubType?.name ?? "Fill application form";
      default:
        return "Choose a service to apply";
    }
  }

  // ==================== STEP INDICATOR ====================
  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepItem(0, "Service", Icons.category),
          _buildStepItem(1, "Sub-Type", Icons.list_alt),
          _buildStepItem(2, "Form", Icons.edit_note),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Expanded(
      child: GestureDetector(
        onTap: step < _currentStep ? _goBack : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isCurrent
                ? const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  )
                : null,
            color: isCurrent ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isCurrent
                    ? Colors.white
                    : (isActive ? const Color(0xFF6C63FF) : Colors.grey),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? Colors.white
                      : (isActive ? const Color(0xFF6C63FF) : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== STEP 1 ====================
  Widget _buildServiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserDetailsCard(),
        const SizedBox(height: 16),
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "Select Service",
                Icons.apps,
                subtitle:
                    "Choose from ${_allServices.length} available services",
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _allServices.length,
                itemBuilder: (context, index) =>
                    _buildServiceCard(_allServices[index]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceType service) {
    final color = _getServiceColor(service.id);
    return GestureDetector(
      onTap: () => _selectService(service),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  service.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                service.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${service.subTypes.length} types",
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== USER DETAILS CARD ====================
  Widget _buildUserDetailsCard() {
    return _buildGlassContainer(
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
                child:
                    const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                "Your Details",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 10, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      "Auto-Fetched",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReadOnlyRow(Icons.person_outline, "Name", _userName),
          const SizedBox(height: 8),
          _buildReadOnlyRow(Icons.email_outlined, "Email", _userEmail),
          const SizedBox(height: 8),
          _buildReadOnlyRow(
            Icons.phone_outlined,
            "Mobile",
            _userMobile.isNotEmpty ? "+91$_userMobile" : "Not available",
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? "Not available" : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== STEP 2 ====================
  Widget _buildSubTypeSelection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            "${_selectedService!.icon}  ${_selectedService!.name}",
            Icons.list_alt,
            subtitle: _selectedService!.description,
          ),
          const SizedBox(height: 12),
          ..._selectedService!.subTypes.map(
            (subType) => _buildSubTypeCard(subType),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTypeCard(ServiceSubType subType) {
    final color = _getServiceColor(_selectedService!.id);
    return GestureDetector(
      onTap: () => _selectSubType(subType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _selectedService!.icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subType.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subType.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${subType.requiredDocuments.length} docs",
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ STEP 3 — FORM (AUTO-FILLED + DOCUMENTS ONLY)
  // NOTE: No Aadhaar, no bank, no sub-type extra fields.
  // ============================================================
  Widget _buildForm() {
    final documents = _selectedSubType!.requiredDocuments;

    return Column(
      children: [
        _buildAutoFilledProfileSection(),

        const SizedBox(height: 16),

        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "Required Documents",
                Icons.upload_file,
                subtitle: "Upload the following documents to complete your application",
              ),
              const SizedBox(height: 8),
              if (documents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      "No documents required for this service",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ...documents.map((doc) => _buildDocumentUpload(doc)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildFeeCard(),
      ],
    );
  }

  // ============================================================
  // ✅ AUTO-FILLED PROFILE SECTION
  // Only Applicant Details + Address. No Aadhaar, no Bank.
  // ============================================================
  Widget _buildAutoFilledProfileSection() {
    if (_loadingProfile && !_profileLoaded) {
      return _buildGlassContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 16),
              Text(
                "Fetching your profile details…",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "This will be auto-filled from your saved profile",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // ✅ Green success banner (only when profile loaded)
        if (_profileLoaded) _buildSuccessBanner(),

        if (_profileLoaded) const SizedBox(height: 12),

        // ------------------------------------------------------------
        // ✅ APPLICANT BASIC DETAILS
        // ------------------------------------------------------------
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "👤 Applicant Details",
                Icons.person,
                subtitle: "Auto-filled from your profile",
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 8),
              _buildProfileField('full_name', 'Full Name'),
              _buildProfileField('father_name', "Father's Name"),
              _buildProfileField('mother_name', "Mother's Name"),
              _buildProfileField('date_of_birth',
                  'Date of Birth (YYYY-MM-DD)'),
              _buildProfileDropdownField('gender', 'Gender',
                  const ['Male', 'Female', 'Other']),
              _buildProfileDropdownField('category', 'Category', const [
                'General/UR',
                'OBC',
                'SC',
                'ST',
                'EWS',
              ]),
              _buildProfileDropdownField('marital_status', 'Marital Status',
                  const ['Unmarried', 'Married', 'Divorced', 'Widowed']),
              _buildProfileField('mobile', 'Mobile',
                  keyboardType: TextInputType.phone),
              _buildProfileField('email', 'Email',
                  keyboardType: TextInputType.emailAddress),
              _buildProfileField('annual_income', 'Annual Income (₹)',
                  keyboardType: TextInputType.number),
              _buildProfileDropdownField(
                  'bpl_status', 'BPL Status', const ['Yes', 'No']),
              _buildProfileDropdownField(
                  'disability_status', 'Disability Status', const [
                'Yes',
                'No',
              ]),
              _buildProfileField('disability_percentage', 'Disability %',
                  keyboardType: TextInputType.number),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ------------------------------------------------------------
        // ✅ ADDRESS
        // ------------------------------------------------------------
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                "🏠 Address",
                Icons.home,
                subtitle: "Auto-filled from your profile",
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 8),
              _buildProfileField('address_line1', 'Address Line 1'),
              _buildProfileField('address_line2', 'Address Line 2'),
              _buildProfileField('village_city', 'Village / City'),
              _buildProfileField('district', 'District'),
              _buildProfileField('state', 'State'),
              _buildProfileField('pincode', 'Pincode',
                  keyboardType: TextInputType.number),
              _buildProfileField('country', 'Country'),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ SUCCESS BANNER — shown only when profile loads OK
  // ============================================================
  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Profile Loaded Successfully",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "All details were auto-filled from your database. "
                  "Just upload the required documents below.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ PROFILE FIELD (text) — auto-filled + editable
  // ============================================================
  Widget _buildProfileField(
    String key,
    String label, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final ctrl = _controllers.putIfAbsent(
        key, () => TextEditingController());
    final isFilled = ctrl.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFilled
                ? Colors.green.shade200
                : Colors.grey.shade200,
            width: isFilled ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.black87),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: isFilled
                ? const Icon(Icons.check_circle,
                    color: Colors.green, size: 18)
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ PROFILE FIELD (dropdown) — auto-filled + editable
  // ============================================================
  Widget _buildProfileDropdownField(
    String key,
    String label,
    List<String> options,
  ) {
    final ctrl = _controllers.putIfAbsent(
        key, () => TextEditingController());
    final currentValue =
        ctrl.text.trim().isEmpty ? null : ctrl.text.trim();

    final safeOptions = <String>[...options];
    if (currentValue != null && !safeOptions.contains(currentValue)) {
      safeOptions.insert(0, currentValue);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: currentValue != null
                ? Colors.green.shade200
                : Colors.grey.shade200,
            width: currentValue != null ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          value: currentValue,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            prefixIcon: currentValue != null
                ? const Icon(Icons.check_circle,
                    color: Colors.green, size: 18)
                : null,
            suffixIcon: Icon(
              Icons.arrow_drop_down,
              color: Colors.grey.shade600,
            ),
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          items: safeOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: const TextStyle(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              ctrl.text = value ?? '';
            });
          },
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildDocumentUpload(String docName) {
    final uploadedDoc = _uploadedDocs[docName];
    final isUploaded = uploadedDoc != null;
    final isUploading = _isUploadingDoc[docName] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUploaded
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.grey.shade50, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? Colors.green.shade300 : Colors.grey.shade300,
          width: isUploaded ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUploaded
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  docName,
                  style: TextStyle(
                    fontWeight:
                        isUploaded ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: isUploaded
                        ? Colors.green.shade900
                        : Colors.black87,
                  ),
                ),
                if (uploadedDoc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "${uploadedDoc.fileName} • ${uploadedDoc.fileSizeKb} KB",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (isUploading) ...[
                  const SizedBox(height: 2),
                  const Text(
                    "Uploading...",
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
          if (isUploaded)
            InkWell(
              onTap: () => _removeDocument(docName),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.red.shade700,
                  size: 16,
                ),
              ),
            )
          else if (isUploading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton(
              onPressed: () => _pickDocument(docName),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Upload",
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ FEE CARD — Full breakdown before payment
  // ============================================================
  Widget _buildFeeCard() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Fee Breakdown", Icons.receipt_long,
              color: const Color(0xFF6C63FF)),
          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  "Application Fee",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              Text(
                "₹$_applicationFee",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Expanded(
                child: Text(
                  "Service Charge",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              Text(
                "₹$_serviceCharge",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Expanded(
                child: Text(
                  "Subtotal",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                "₹$_subtotal",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  "GST (${GST_PERCENT.toInt()}% on ₹$_subtotal)",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
              Text(
                "₹$_gstAmount",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.green.shade300,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payment,
                      color: Colors.green, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    "Total Payable",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
                Text(
                  "₹$_totalFee",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM BAR ====================
  Widget _buildBottomBar() {
    final isComplete = _isFormValid();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 14,
                      color: isComplete ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isComplete
                            ? "Ready to submit"
                            : "Upload all required documents",
                        style: TextStyle(
                          fontSize: 12,
                          color: isComplete ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Total: ₹$_totalFee",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isComplete
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isComplete
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed:
                  (isComplete && !_isSubmitting)
                      ? _submitApplicationWithPayment
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      children: [
                        Icon(Icons.payment, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Pay & Submit",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.auto_awesome, size: 12),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UTILITIES ====================
  Color _getServiceColor(String serviceId) {
    switch (serviceId) {
      case 'pan':
        return Colors.orange;
      case 'aadhar':
        return Colors.blue;
      case 'epf':
        return Colors.green;
      case 'passport':
        return Colors.deepPurple;
      case 'driving_license':
        return Colors.cyan;
      case 'voter_id':
        return Colors.red;
      case 'ration_card':
        return Colors.indigo;
      case 'income_certificate':
        return Colors.teal;
      case 'caste_certificate':
        return Colors.deepOrange;
      case 'domicile':
        return Colors.brown;
      case 'disability':
        return Colors.pink;
      case 'bonafide':
        return Colors.purple;
      case 'gap_certificate':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }
}

// ============================================================
// LOCAL MODEL
// ============================================================
class _UploadedDoc {
  final String key;
  final String label;
  final String url;
  final String? publicId;
  final String fileName;
  final int fileSizeKb;
  final String resourceType;
  final DateTime uploadedAt;

  _UploadedDoc({
    required this.key,
    required this.label,
    required this.url,
    this.publicId,
    required this.fileName,
    required this.fileSizeKb,
    required this.resourceType,
    required this.uploadedAt,
  });
}