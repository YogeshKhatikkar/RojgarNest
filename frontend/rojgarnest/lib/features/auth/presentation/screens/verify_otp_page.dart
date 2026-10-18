// lib/features/auth/presentation/screens/verify_otp_page.dart
// ✅ AI‑BASED MODERN DESIGN (same as other screens)
// ✅ NEW: CUSTOM OTP FIELDS — Bold, large, crystal-clear digits
// ✅ FIXED: NO WHITE LINE — clean borders, high contrast text
// ✅ FIXED: Added flutter/services.dart import for input formatters
// ✅ ALL ORIGINAL LOGIC PRESERVED (timer, resend, verification)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ FIXED: Required for input formatters
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/auth/presentation/controllers/auth_controller.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final String mobile;

  const VerifyOtpPage({super.key, required this.email, required this.mobile});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _emailOtpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _mobileOtpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _emailFocusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _mobileFocusNodes =
      List.generate(6, (_) => FocusNode());

  int _timerSeconds = 60;
  Timer? _countdownTimer;
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timerSeconds = 60;
    _canResend = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String _getEmailOtp() {
    return _emailOtpControllers.map((c) => c.text).join();
  }

  String _getMobileOtp() {
    return _mobileOtpControllers.map((c) => c.text).join();
  }

  void _clearOtps() {
    for (var controller in _emailOtpControllers) {
      controller.clear();
    }
    for (var controller in _mobileOtpControllers) {
      controller.clear();
    }
  }

  Future<void> _resendOtp() async {
    if (!mounted) return;
    final authController = Provider.of<AuthController>(context, listen: false);
    try {
      await authController.resendEmailOtp(widget.email);
      await authController.resendMobileOtp(widget.mobile);
      if (mounted) {
        _startResendTimer();
        _clearOtps();
        showMessage(context, "OTP Resent Successfully! 📩", isError: false);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceAll("Exception:", "").trim(),
          isError: true,
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!mounted) return;
    final String emailOtp = _getEmailOtp();
    final String mobileOtp = _getMobileOtp();

    if (emailOtp.isEmpty || mobileOtp.isEmpty) {
      showMessage(context, "Please enter both OTPs", isError: true);
      return;
    }
    if (emailOtp.length != 6 || mobileOtp.length != 6) {
      showMessage(context, "Please enter valid 6-digit OTPs", isError: true);
      return;
    }

    setState(() => _isVerifying = true);
    final AuthController auth =
        Provider.of<AuthController>(context, listen: false);

    try {
      await auth.verifyEmailOtp(widget.email, emailOtp);
      await auth.verifyMobileOtp(widget.mobile, mobileOtp);
      if (!mounted) return;
      showMessage(
        context,
        "Account Verified Successfully! 🎉 Please login to continue.",
        isError: false,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go(AppRoutes.auth);
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll("Exception:", "").trim();
        if (errorMessage.toLowerCase().contains("expired")) {
          errorMessage = "OTP has expired. Please request a new one.";
        } else if (errorMessage.toLowerCase().contains("invalid")) {
          errorMessage = "Invalid OTP. Please check and try again.";
        } else if (errorMessage.toLowerCase().contains("attempt")) {
          errorMessage = "Too many failed attempts. Please request a new OTP.";
        }
        showMessage(context, errorMessage, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _emailOtpControllers) {
      controller.dispose();
    }
    for (var controller in _mobileOtpControllers) {
      controller.dispose();
    }
    for (var node in _emailFocusNodes) {
      node.dispose();
    }
    for (var node in _mobileFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // BUILD – AI‑BASED MODERN UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final isLoading = auth.isLoading || _isVerifying;

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildContactCard(),
                const SizedBox(height: 24),
                _buildOtpSection(
                  title: "📧 Email Verification Code",
                  controllers: _emailOtpControllers,
                  focusNodes: _emailFocusNodes,
                  isLoading: isLoading,
                  hint: "Enter 6-digit code sent to your email",
                ),
                const SizedBox(height: 28),
                _buildOtpSection(
                  title: "📱 Mobile Verification Code",
                  controllers: _mobileOtpControllers,
                  focusNodes: _mobileFocusNodes,
                  isLoading: isLoading,
                  hint: "Enter 6-digit code sent to your mobile",
                ),
                const SizedBox(height: 32),
                _buildVerifyButton(isLoading),
                const SizedBox(height: 20),
                _buildResendSection(),
                const SizedBox(height: 16),
                _buildHelpText(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AI‑BASED DESIGN COMPONENTS
  // ============================================================

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
              Icons.mark_email_read,
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
                  "Verify Your Account",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Enter the verification codes sent to your email and mobile",
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

  // ============================================================
  // CONTACT CARD
  // ============================================================
  Widget _buildContactCard() {
    return _buildGlassContainer(
      child: Row(
        children: [
          Expanded(
            child: _buildContactItem(
              icon: Icons.email_outlined,
              label: "Email",
              value: widget.email,
              color: const Color(0xFF6C63FF),
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildContactItem(
              icon: Icons.phone_android_outlined,
              label: "Mobile",
              value: "+91${widget.mobile}",
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ============================================================
  // OTP SECTION – CUSTOM FIELDS (BOLD, CRYSTAL-CLEAR DIGITS)
  // ============================================================
  Widget _buildOtpSection({
    required String title,
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool isLoading,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, Icons.pin),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return _buildOtpBox(
                controller: controllers[index],
                focusNode: focusNodes[index],
                onChanged: (value) {
                  setState(() {});
                  if (value.length == 1 && index < 5) {
                    FocusScope.of(context).requestFocus(focusNodes[index + 1]);
                  } else if (value.isEmpty && index > 0) {
                    FocusScope.of(context).requestFocus(focusNodes[index - 1]);
                  }
                },
                isLoading: isLoading,
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: Colors.grey.shade700, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ✅ Custom OTP Box — Large, Bold, Crystal-Clear digits
  Widget _buildOtpBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    required bool isLoading,
  }) {
    return SizedBox(
      width: 46,
      height: 58,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !isLoading,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: false,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
          letterSpacing: 1,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: controller.text.isNotEmpty
              ? const Color(0xFF6C63FF).withOpacity(0.08)
              : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: focusNode.hasFocus
                  ? const Color(0xFF6C63FF)
                  : Colors.grey.shade300,
              width: focusNode.hasFocus ? 2.5 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF6C63FF),
              width: 2.5,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }

  // ============================================================
  // VERIFY BUTTON
  // ============================================================
  Widget _buildVerifyButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Verify & Complete Registration",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESEND SECTION
  // ============================================================
  Widget _buildResendSection() {
    return Center(
      child: _canResend
          ? GestureDetector(
              onTap: _resendOtp,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "Resend OTP",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    "Resend in ${_timerSeconds}s",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // HELP TEXT
  // ============================================================
  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Development Mode: Use OTP 123456 for testing",
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}