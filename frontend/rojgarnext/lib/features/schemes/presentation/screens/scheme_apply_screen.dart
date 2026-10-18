// lib/features/schemes/presentation/screens/scheme_apply_screen.dart
// ============================================================
// SCHEME APPLY SCREEN
// Multi-step form to apply for a government scheme
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rojgarnext/core/network/dio_client.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/utils/app_snackbar.dart';
import 'package:rojgarnext/features/schemes/data/scheme_service.dart';

class SchemeApplyScreen extends StatefulWidget {
  final Map<String, dynamic> scheme;

  const SchemeApplyScreen({super.key, required this.scheme});

  @override
  State<SchemeApplyScreen> createState() => _SchemeApplyScreenState();
}

class _SchemeApplyScreenState extends State<SchemeApplyScreen> {
  // ==================== STATE ====================
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Controllers — Personal
  final _fullNameCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();

  // Controllers — Address
  final _address1Ctrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // Controllers — Bank
  final _accountHolderCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  // Controllers — Additional
  final _remarksCtrl = TextEditingController();

  // Dropdown values
  String _gender = 'male';
  String _category = 'General';
  String _maritalStatus = 'Unmarried';
  String _accountType = 'savings';

  // Toggles
  bool _bplStatus = false;
  bool _disabilityStatus = false;
  double _disabilityPercentage = 0;

  final _formKeyPersonal = GlobalKey<FormState>();
  final _formKeyAddress = GlobalKey<FormState>();
  final _formKeyBank = GlobalKey<FormState>();

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _fatherNameCtrl.dispose();
    _motherNameCtrl.dispose();
    _dobCtrl.dispose();
    _aadhaarCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _incomeCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _accountHolderCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _branchCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ==================== PREFILL ====================
  Future<void> _prefillFromProfile() async {
    try {
      final email = await SecureStorage.getEmail();
      final mobile = await SecureStorage.getMobile();
      final name = await SecureStorage.getName();

      if (!mounted) return;

      _emailCtrl.text = email ?? '';
      _mobileCtrl.text = mobile ?? '';
      _fullNameCtrl.text = name ?? '';
      _accountHolderCtrl.text = name ?? '';
    } catch (e) {
      debugPrint("Prefill error: $e");
    }
  }

  // ==================== STEP NAVIGATION ====================
  void _goNext() {
    if (_currentStep == 0) {
      if (!(_formKeyPersonal.currentState?.validate() ?? false)) return;
    } else if (_currentStep == 1) {
      if (!(_formKeyAddress.currentState?.validate() ?? false)) return;
    }
    setState(() => _currentStep++);
  }

  void _goBack() {
    if (_currentStep > 0) setState(() => _currentStep--);
    else Navigator.pop(context);
  }

  // ==================== DATE PICKER ====================
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 10, now.month, now.day),
    );
    if (picked != null && mounted) {
      _dobCtrl.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  // ==================== SUBMIT ====================
  Future<void> _submitApplication() async {
    if (!(_formKeyBank.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final schemeId = widget.scheme['scheme_id']?.toString() ?? '';

      if (schemeId.isEmpty) {
        throw "Scheme ID missing";
      }

      final applicantDetails = {
        "full_name": _fullNameCtrl.text.trim(),
        "father_name": _fatherNameCtrl.text.trim(),
        "mother_name": _motherNameCtrl.text.trim(),
        "date_of_birth": _dobCtrl.text.trim(),
        "gender": _gender,
        "category": _category,
        "marital_status": _maritalStatus,
        "aadhaar_number": _aadhaarCtrl.text.trim(),
        "mobile": _mobileCtrl.text.trim(),
        "email": _emailCtrl.text.trim(),
        "annual_income":
            int.tryParse(_incomeCtrl.text.trim()) ?? 0,
        "bpl_status": _bplStatus,
        "disability_status": _disabilityStatus,
        "disability_percentage":
            _disabilityStatus ? _disabilityPercentage : 0,
      };

      final applicantAddress = {
        "address_line1": _address1Ctrl.text.trim(),
        "address_line2": _address2Ctrl.text.trim(),
        "village_city": _villageCtrl.text.trim(),
        "district": _districtCtrl.text.trim(),
        "state": _stateCtrl.text.trim(),
        "pincode": _pincodeCtrl.text.trim(),
        "country": "India",
      };

      final bankDetails = {
        "account_holder_name": _accountHolderCtrl.text.trim(),
        "bank_name": _bankNameCtrl.text.trim(),
        "account_number": _accountNumberCtrl.text.trim(),
        "ifsc_code": _ifscCtrl.text.trim().toUpperCase(),
        "branch_name": _branchCtrl.text.trim(),
        "account_type": _accountType,
      };

      final result = await SchemeService.applyForScheme(
        schemeId: schemeId,
        applicantDetails: applicantDetails,
        applicantAddress: applicantAddress,
        bankDetails: bankDetails,
        remarks: _remarksCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSuccessDialog(result['application_id']?.toString() ?? '');
      } else {
        showMessage(
          context,
          result['message'] ?? 'आवेदन सबमिट नहीं हो सका',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, 'आवेदन विफल: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==================== SUCCESS DIALOG ====================
  void _showSuccessDialog(String applicationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'आवेदन सफल!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Application Submitted Successfully!',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            if (applicationId.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'आवेदन संख्या',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      applicationId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C63FF),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ठीक है / OK',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final schemeNameHindi = widget.scheme['scheme_name_hindi']?.toString() ??
        widget.scheme['scheme_name']?.toString() ?? 'योजना';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFE8ECF1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(schemeNameHindi),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildCurrentStep(),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(String schemeName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
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
          Material(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _goBack,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_document,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'योजना आवेदन',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  schemeName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP INDICATOR
  // ============================================================
  Widget _buildStepIndicator() {
    const steps = ['व्यक्तिगत', 'पता', 'बैंक'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: isActive || isDone
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF6C63FF),
                                  Color(0xFFFF6588)
                                ],
                              )
                            : null,
                        color: isActive || isDone
                            ? null
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? const Color(0xFF6C63FF)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin:
                          const EdgeInsets.only(bottom: 18, left: 4, right: 4),
                      color: isDone
                          ? const Color(0xFF6C63FF)
                          : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ============================================================
  // CURRENT STEP
  // ============================================================
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildAddressStep();
      case 2:
        return _buildBankStep();
      default:
        return const SizedBox();
    }
  }

  // ============================================================
  // STEP 1 — PERSONAL
  // ============================================================
  Widget _buildPersonalStep() {
    return Form(
      key: _formKeyPersonal,
      child: Column(
        children: [
          _buildSectionCard(
            title: 'व्यक्तिगत जानकारी',
            subtitle: 'Personal Information',
            icon: Icons.person,
            children: [
              _buildTextField(
                _fullNameCtrl,
                'पूरा नाम *',
                'Full Name',
                icon: Icons.person_outline,
                required: true,
              ),
              _buildTextField(
                _fatherNameCtrl,
                'पिता का नाम',
                "Father's Name",
                icon: Icons.person_outline,
              ),
              _buildTextField(
                _motherNameCtrl,
                'माता का नाम',
                "Mother's Name",
                icon: Icons.person_outline,
              ),
              _buildDateField(
                _dobCtrl,
                'जन्म तिथि *',
                'Date of Birth',
              ),
              _buildDropdown(
                label: 'लिंग *',
                labelEn: 'Gender',
                value: _gender,
                items: const [
                  {'value': 'male', 'label': 'पुरुष / Male'},
                  {'value': 'female', 'label': 'महिला / Female'},
                  {'value': 'transgender', 'label': 'ट्रांसजेंडर / Transgender'},
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              _buildDropdown(
                label: 'श्रेणी *',
                labelEn: 'Category',
                value: _category,
                items: const [
                  {'value': 'General', 'label': 'सामान्य / General'},
                  {'value': 'OBC', 'label': 'अन्य पिछड़ा वर्ग / OBC'},
                  {'value': 'SC', 'label': 'अनुसूचित जाति / SC'},
                  {'value': 'ST', 'label': 'अनुसूचित जनजाति / ST'},
                  {'value': 'EWS', 'label': 'EWS'},
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              _buildDropdown(
                label: 'वैवाहिक स्थिति',
                labelEn: 'Marital Status',
                value: _maritalStatus,
                items: const [
                  {'value': 'Unmarried', 'label': 'अविवाहित / Unmarried'},
                  {'value': 'Married', 'label': 'विवाहित / Married'},
                  {'value': 'Widowed', 'label': 'विधवा/विधुर / Widowed'},
                  {'value': 'Divorced', 'label': 'तलाकशुदा / Divorced'},
                ],
                onChanged: (v) => setState(() => _maritalStatus = v!),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'संपर्क जानकारी',
            subtitle: 'Contact Information',
            icon: Icons.contact_phone,
            children: [
              _buildTextField(
                _aadhaarCtrl,
                'आधार नंबर',
                'Aadhaar Number',
                icon: Icons.badge,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
              ),
              _buildTextField(
                _mobileCtrl,
                'मोबाइल नंबर *',
                'Mobile Number',
                icon: Icons.phone,
                required: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              _buildTextField(
                _emailCtrl,
                'ईमेल *',
                'Email',
                icon: Icons.email,
                required: true,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField(
                _incomeCtrl,
                'वार्षिक आय (₹)',
                'Annual Income (₹)',
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'अतिरिक्त जानकारी',
            subtitle: 'Additional Information',
            icon: Icons.info,
            children: [
              _buildSwitchTile(
                title: 'BPL स्थिति',
                subtitle: 'Are you Below Poverty Line?',
                value: _bplStatus,
                onChanged: (v) => setState(() => _bplStatus = v),
              ),
              _buildSwitchTile(
                title: 'विकलांगता स्थिति',
                subtitle: 'Do you have any disability?',
                value: _disabilityStatus,
                onChanged: (v) => setState(() => _disabilityStatus = v),
              ),
              if (_disabilityStatus) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'विकलांगता प्रतिशत: ${_disabilityPercentage.toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      Slider(
                        value: _disabilityPercentage,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: const Color(0xFF6C63FF),
                        onChanged: (v) =>
                            setState(() => _disabilityPercentage = v),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2 — ADDRESS
  // ============================================================
  Widget _buildAddressStep() {
    return Form(
      key: _formKeyAddress,
      child: _buildSectionCard(
        title: 'पता विवरण',
        subtitle: 'Address Details',
        icon: Icons.location_on,
        children: [
          _buildTextField(
            _address1Ctrl,
            'पता पंक्ति 1 *',
            'Address Line 1',
            icon: Icons.home,
            required: true,
          ),
          _buildTextField(
            _address2Ctrl,
            'पता पंक्ति 2',
            'Address Line 2',
            icon: Icons.home_outlined,
          ),
          _buildTextField(
            _villageCtrl,
            'गाँव/शहर *',
            'Village / City',
            icon: Icons.location_city,
            required: true,
          ),
          _buildTextField(
            _districtCtrl,
            'जिला *',
            'District',
            icon: Icons.map,
            required: true,
          ),
          _buildTextField(
            _stateCtrl,
            'राज्य *',
            'State',
            icon: Icons.location_on,
            required: true,
          ),
          _buildTextField(
            _pincodeCtrl,
            'पिनकोड *',
            'Pincode',
            icon: Icons.pin_drop,
            required: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3 — BANK
  // ============================================================
  Widget _buildBankStep() {
    return Form(
      key: _formKeyBank,
      child: Column(
        children: [
          _buildSectionCard(
            title: 'बैंक विवरण',
            subtitle: 'Bank Details',
            icon: Icons.account_balance,
            children: [
              _buildTextField(
                _accountHolderCtrl,
                'खाताधारक का नाम *',
                'Account Holder Name',
                icon: Icons.person,
                required: true,
              ),
              _buildTextField(
                _bankNameCtrl,
                'बैंक का नाम *',
                'Bank Name',
                icon: Icons.account_balance,
                required: true,
              ),
              _buildTextField(
                _accountNumberCtrl,
                'खाता संख्या *',
                'Account Number',
                icon: Icons.numbers,
                required: true,
                keyboardType: TextInputType.number,
              ),
              _buildTextField(
                _ifscCtrl,
                'IFSC कोड *',
                'IFSC Code',
                icon: Icons.code,
                required: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              _buildTextField(
                _branchCtrl,
                'शाखा का नाम',
                'Branch Name',
                icon: Icons.location_on,
              ),
              _buildDropdown(
                label: 'खाता प्रकार',
                labelEn: 'Account Type',
                value: _accountType,
                items: const [
                  {'value': 'savings', 'label': 'बचत / Savings'},
                  {'value': 'current', 'label': 'चालू / Current'},
                ],
                onChanged: (v) => setState(() => _accountType = v!),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'अतिरिक्त टिप्पणी',
            subtitle: 'Additional Remarks (Optional)',
            icon: Icons.comment,
            children: [
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 3,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'कोई अतिरिक्त जानकारी...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'कृपया सुनिश्चित करें कि सभी जानकारी सही है। गलत जानकारी होने पर आवेदन अस्वीकृत हो सकता है।',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      height: 1.5,
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

  // ============================================================
  // BOTTOM BAR
  // ============================================================
  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _goBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text(
                      'पीछे',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF),
                      side: const BorderSide(
                          color: Color(0xFF6C63FF), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLastStep
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF6C63FF), const Color(0xFFFF6588)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isLastStep
                                ? Colors.green
                                : const Color(0xFF6C63FF))
                            .withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : (isLastStep ? _submitApplication : _goNext),
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
                            isLastStep ? Icons.send : Icons.arrow_forward,
                            size: 18,
                          ),
                    label: Text(
                      _isSubmitting
                          ? 'जमा हो रहा है...'
                          : (isLastStep ? 'आवेदन जमा करें' : 'आगे बढ़ें'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REUSABLE WIDGETS
  // ============================================================
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.12),
                  const Color(0xFFFF6588).withOpacity(0.04),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
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
                  child: Icon(icon, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String labelHindi,
    String labelEn, {
    IconData? icon,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF111827),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: required ? '$labelHindi' : labelHindi,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
          hintText: labelEn,
          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
          prefixIcon:
              icon != null ? Icon(icon, size: 20, color: const Color(0xFF6C63FF)) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF6C63FF),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? 'यह फ़ील्ड आवश्यक है'
                : null
            : null,
      ),
    );
  }

  Widget _buildDateField(
    TextEditingController ctrl,
    String labelHindi,
    String labelEn,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: _pickDob,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF111827),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: labelHindi,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
          hintText: labelEn,
          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
          prefixIcon: const Icon(
            Icons.calendar_today,
            size: 20,
            color: Color(0xFF6C63FF),
          ),
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF6C63FF),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'तिथि आवश्यक है' : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String labelEn,
    required String value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF111827),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
          hintText: labelEn,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        items: items
            .map((e) => DropdownMenuItem<String>(
                  value: e['value'],
                  child: Text(
                    e['label'] ?? '',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF6B7280),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF6C63FF),
        activeTrackColor: const Color(0xFF6C63FF).withOpacity(0.4),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}