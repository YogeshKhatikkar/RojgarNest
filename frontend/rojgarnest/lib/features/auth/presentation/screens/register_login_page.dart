// lib/features/auth/presentation/screens/register_login_page.dart
// ✅ COMPLETE PRODUCTION-READY VERSION
// ✅ LOCK SCREEN with LIVE COUNTDOWN TIMER
// ✅ AUTO-UNLOCK when countdown reaches 0
// ✅ All original functionality preserved

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:rojgarnest/features/auth/presentation/controllers/auth_controller.dart';
import 'package:rojgarnest/features/auth/presentation/screens/change_password_screen.dart';
import 'package:rojgarnest/features/auth/presentation/screens/fingerprint_setup_page.dart';
import 'package:rojgarnest/features/common/widgets/internet_checker.dart';

class RegisterLoginPage extends StatefulWidget {
  final String? initialTab;

  const RegisterLoginPage({super.key, this.initialTab});

  @override
  State<RegisterLoginPage> createState() => _RegisterLoginPageState();
}

class _RegisterLoginPageState extends State<RegisterLoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _loginMethodIndex = 0;

  // Controllers
  final loginEmailCtrl = TextEditingController();
  final loginPasswordCtrl = TextEditingController();
  final mpinEmailCtrl = TextEditingController();
  final pinCtrl = TextEditingController();

  final registerNameCtrl = TextEditingController();
  final registerEmailCtrl = TextEditingController();
  final registerMobileCtrl = TextEditingController();
  final registerPasswordCtrl = TextEditingController();

  // ✅ State variables (at class level - NOT inside StatefulBuilder)
  bool showPassword = false;
  bool showRegisterPassword = false;

  // Password Strength
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSymbol = false;
  bool isLongEnough = false;

  late AuthController _authController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    registerPasswordCtrl.addListener(_checkPasswordStrength);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialTab != null) {
        final tabIndex = int.tryParse(widget.initialTab!);
        if (tabIndex == 1) {
          _tabController.animateTo(1);
        } else if (tabIndex == 0) {
          _tabController.animateTo(0);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController.initialize(
        onShowMessage: (message, {isError = false}) {
          if (mounted) {
            showMessage(context, message, isError: isError);
          }
        },
      );
    });
  }

  void _checkPasswordStrength() {
    if (!mounted) return;
    final p = registerPasswordCtrl.text;
    setState(() {
      hasUpper = p.contains(RegExp(r'[A-Z]'));
      hasLower = p.contains(RegExp(r'[a-z]'));
      hasNumber = p.contains(RegExp(r'[0-9]'));
      hasSymbol = p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      isLongEnough = p.length >= 8;
    });
  }

  bool _isPasswordValid() =>
      hasUpper && hasLower && hasNumber && hasSymbol && isLongEnough;

  void _safeShowMessage(String message, {bool isError = false}) {
    if (mounted) {
      showMessage(context, message, isError: isError);
    }
  }

  @override
  void dispose() {
    loginEmailCtrl.dispose();
    loginPasswordCtrl.dispose();
    mpinEmailCtrl.dispose();
    pinCtrl.dispose();
    registerNameCtrl.dispose();
    registerEmailCtrl.dispose();
    registerMobileCtrl.dispose();
    registerPasswordCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    // ✅ If account is locked, show LOCK SCREEN instead of login form
    if (auth.isAccountLocked) {
      return _buildAccountLockedScreen(auth);
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: _buildGradientBackground(),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32,
                    vertical: 20,
                  ),
                  child: Container(
                    width: isMobile ? double.infinity : 440,
                    constraints: BoxConstraints(
                      maxHeight: size.height - (isMobile ? 80 : 120),
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: _buildGlassContainerDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildTabBar(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildLoginTab(auth),
                              _buildRegisterTab(auth),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: InternetChecker(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ ACCOUNT LOCKED SCREEN WITH LIVE COUNTDOWN
  // ============================================================
  Widget _buildAccountLockedScreen(AuthController auth) {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(32),
                decoration: _buildGlassContainerDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔒 Lock Icon with Animation
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_clock,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    const Text(
                      "Account Temporarily Locked",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      "Too many failed login attempts detected.\n"
                      "Your account is locked for security reasons.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ⏱️ LIVE COUNTDOWN TIMER
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6C63FF).withOpacity(0.15),
                            const Color(0xFFFF6588).withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "🔓 Auto-unlock in",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // ✅ Big countdown display
                          Text(
                            auth.lockCountdownDisplay,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C63FF),
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.lockCountdownHumanReadable,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: auth.lockUntil != null
                            ? 1 - (auth.lockSecondsRemaining /
                                (auth.lockUntil!
                                        .difference(DateTime.now())
                                        .inSeconds +
                                    auth.lockSecondsRemaining))
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Your account will unlock automatically. "
                              "The login form will reappear once the timer reaches zero.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB45309),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Manual refresh button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Check if lock actually expired
                            if (auth.lockSecondsRemaining <= 0) {
                              auth.stopLockCountdown();
                              _safeShowMessage("Account unlocked! Please login.");
                            } else {
                              _safeShowMessage(
                                "Still locked. Please wait ${auth.lockCountdownHumanReadable}.",
                                isError: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            "Check Unlock Status",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Support contact
                    TextButton.icon(
                      onPressed: () {
                        _safeShowMessage(
                          "Please contact support@rojgarnest.com for help.",
                        );
                      },
                      icon: const Icon(
                        Icons.support_agent,
                        size: 18,
                        color: Color(0xFF6C63FF),
                      ),
                      label: const Text(
                        "Contact Support",
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESIGN HELPERS
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

  BoxDecoration _buildGlassContainerDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(
        color: Colors.white.withOpacity(0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.work_outline,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          ).createShader(bounds),
          child: const Text(
            "RojgarNest",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Find Your Dream Job",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: "Login"),
          Tab(text: "Register"),
        ],
      ),
    );
  }

  // ============================================================
  // LOGIN TAB
  // ============================================================
  Widget _buildLoginTab(AuthController auth) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            children: [
              _buildLoginMethodChip(
                index: 0,
                label: "Email",
                icon: Icons.email_outlined,
                selectedIndex: _loginMethodIndex,
                onTap: () => setState(() => _loginMethodIndex = 0),
              ),
              _buildLoginMethodChip(
                index: 1,
                label: "MPIN",
                icon: Icons.pin,
                selectedIndex: _loginMethodIndex,
                onTap: () => setState(() => _loginMethodIndex = 1),
              ),
              _buildLoginMethodChip(
                index: 2,
                label: "Fingerprint",
                icon: Icons.fingerprint,
                selectedIndex: _loginMethodIndex,
                onTap: () => setState(() => _loginMethodIndex = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loginMethodIndex == 1
              ? _buildMpinLogin(auth)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _getLoginContent(auth),
                ),
        ),
      ],
    );
  }

  Widget _buildLoginMethodChip({
    required int index,
    required String label,
    required IconData icon,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getLoginContent(AuthController auth) {
    if (_loginMethodIndex == 0) return _buildEmailPasswordLogin(auth);
    if (_loginMethodIndex == 1) return _buildMpinLogin(auth);
    return _buildBiometricLogin(auth);
  }

  // ============================================================
  // EMAIL / PASSWORD LOGIN
  // ============================================================
  Widget _buildEmailPasswordLogin(AuthController auth) {
    return Column(
      children: [
        _buildTextField(loginEmailCtrl, "Email Address", Icons.email_outlined),
        const SizedBox(height: 12),
        _buildPasswordField(
          loginPasswordCtrl,
          "Password",
          Icons.lock_outline,
          isLoginField: true, // ✅ Login field
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final email = loginEmailCtrl.text.trim();
              if (email.isEmpty) {
                _safeShowMessage("Please enter your email first", isError: true);
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(
                    isForgotFlow: true,
                    isEmbedded: false,
                  ),
                  settings: RouteSettings(arguments: email),
                ),
              );
            },
            child: Text(
              "Forgot Password?",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _ModernButton(
          text: "Login",
          isLoading: auth.isLoading,
          onTap: () {
            final email = loginEmailCtrl.text.trim();
            final password = loginPasswordCtrl.text.trim();

            if (email.isEmpty) {
              _safeShowMessage("Please enter your email address", isError: true);
              return;
            }
            if (password.isEmpty) {
              _safeShowMessage("Please enter your password", isError: true);
              return;
            }
            if (!email.contains('@') || !email.contains('.')) {
              _safeShowMessage("Please enter a valid email address", isError: true);
              return;
            }
            if (password.length < 6) {
              _safeShowMessage("Password must be at least 6 characters", isError: true);
              return;
            }

            auth.login(email, password, context);
          },
        ),
      ],
    );
  }

  // ============================================================
  // MPIN LOGIN
  // ============================================================
  Widget _buildMpinLogin(AuthController auth) {
    final TextEditingController localPinCtrl = TextEditingController();
    bool obscurePin = true;

    return StatefulBuilder(
      builder: (context, setMpinState) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isShort = constraints.maxHeight < 560;
            final double numberBtnHeight = isShort ? 40 : 50;
            final double numberBtnWidth = isShort ? 52 : 60;
            final double padSpacing = isShort ? 8 : 12;
            final double topSpacing = isShort ? 12 : 20;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _buildTextField(
                        mpinEmailCtrl, "Email Address", Icons.email_outlined),
                      SizedBox(height: topSpacing),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isShort ? 12 : 16),
                        decoration: _buildGlassContainerDecoration(),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C63FF),
                                        Color(0xFFFF6588),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.pin,
                                      color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Enter 6-Digit MPIN",
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isShort ? 12 : 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(6, (index) {
                                final String text = localPinCtrl.text;
                                final bool isFilled = index < text.length;
                                final String displayChar = obscurePin
                                    ? '•'
                                    : (isFilled ? text[index] : '');

                                return Container(
                                  width: isShort ? 34 : 40,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: Column(
                                    children: [
                                      Text(
                                        isFilled ? displayChar : '',
                                        style: TextStyle(
                                          fontSize: isShort ? 18 : 22,
                                          fontWeight: FontWeight.bold,
                                          color: isFilled
                                              ? Colors.grey.shade800
                                              : Colors.transparent,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF6C63FF),
                                              Color(0xFFFF6588),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(1),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            SizedBox(height: isShort ? 10 : 14),
                            _buildNumberPad(
                              numberBtnWidth: numberBtnWidth,
                              numberBtnHeight: numberBtnHeight,
                              padSpacing: padSpacing,
                              onNumberPressed: (number) {
                                String current = localPinCtrl.text;
                                if (current.length < 6) {
                                  String newValue = current + number;
                                  setMpinState(() {
                                    localPinCtrl.text = newValue;
                                    pinCtrl.text = newValue;
                                  });
                                }
                              },
                              onDeletePressed: () {
                                String current = localPinCtrl.text;
                                if (current.isNotEmpty) {
                                  String newValue = current.substring(
                                      0, current.length - 1);
                                  setMpinState(() {
                                    localPinCtrl.text = newValue;
                                    pinCtrl.text = newValue;
                                  });
                                }
                              },
                              onClearPressed: () {
                                setMpinState(() {
                                  localPinCtrl.clear();
                                  pinCtrl.clear();
                                });
                              },
                              obscurePin: obscurePin,
                              onToggleObscure: () {
                                setMpinState(() {
                                  obscurePin = !obscurePin;
                                });
                              },
                            ),
                            SizedBox(height: isShort ? 8 : 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF6C63FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.security,
                                    size: 13,
                                    color: Color(0xFF6C63FF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Secure MPIN Login",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFF6C63FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(height: isShort ? 12 : 20),
                      _ModernButton(
                        text: "Login with MPIN",
                        isLoading: auth.isLoading,
                        onTap: () {
                          final email = mpinEmailCtrl.text.trim();
                          final pin = localPinCtrl.text.trim();
                          if (email.isEmpty || pin.length != 6) {
                            _safeShowMessage(
                                "Please enter email and 6-digit MPIN",
                                isError: true);
                            return;
                          }
                          pinCtrl.text = pin;
                          auth.loginWithMpin(email, pin, context);
                        },
                      ),
                      SizedBox(height: isShort ? 4 : 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // NUMBER PAD
  // ============================================================
  Widget _buildNumberPad({
    required Function(String) onNumberPressed,
    required VoidCallback onDeletePressed,
    required VoidCallback onClearPressed,
    required bool obscurePin,
    required VoidCallback onToggleObscure,
    required double numberBtnWidth,
    required double numberBtnHeight,
    required double padSpacing,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('1', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildNumberButton('2', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildNumberButton('3', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
          ],
        ),
        SizedBox(height: padSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('4', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildNumberButton('5', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildNumberButton('6', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
          ],
        ),
        SizedBox(height: padSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('7', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildNumberButton('8', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildNumberButton('9', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
          ],
        ),
        SizedBox(height: padSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildIconButton(
              icon: obscurePin ? Icons.visibility_off : Icons.visibility,
              onPressed: onToggleObscure,
              label: obscurePin ? "Show" : "Hide",
              width: numberBtnWidth,
              height: numberBtnHeight,
            ),
            _buildNumberButton('0', onNumberPressed,
                width: numberBtnWidth, height: numberBtnHeight),
            _buildIconButton(
              icon: Icons.backspace,
              onPressed: onDeletePressed,
              label: "Del",
              width: numberBtnWidth,
              height: numberBtnHeight,
            ),
          ],
        ),
        SizedBox(height: padSpacing * 0.5),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onClearPressed,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
            child: const Text("CLEAR ALL", style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberButton(
    String number,
    Function(String) onPressed, {
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onPressed(number),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: height < 45 ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? label,
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.grey.shade700, size: height < 45 ? 20 : 24),
              if (label != null)
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BIOMETRIC LOGIN
  // ============================================================
  Widget _buildBiometricLogin(AuthController auth) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.fingerprint,
            size: 80,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Use Fingerprint",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Touch sensor to login instantly",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildBiometricStatusInfo(),
        const SizedBox(height: 20),
        _ModernButton(
          text: "Login with Fingerprint",
          isLoading: auth.isLoading,
          onTap: () {
            auth.checkAndHandleBiometricLogin(context);
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: SecureStorage.isBiometricEnabled(),
          builder: (context, snapshot) {
            final isEnabled = snapshot.data ?? false;
            return FutureBuilder<String?>(
              future: SecureStorage.getEmail(),
              builder: (context, emailSnapshot) {
                final hasEmail = emailSnapshot.data != null &&
                    emailSnapshot.data!.isNotEmpty;

                if (isEnabled && hasEmail) {
                  return const SizedBox.shrink();
                }

                String buttonText = "🔐 Enable Fingerprint Login";
                if (!hasEmail) {
                  buttonText = "📧 Login with Email & Password first";
                }

                return TextButton(
                  onPressed: () async {
                    if (!hasEmail) {
                      _safeShowMessage(
                        "Please login with email & password first to enable biometric.",
                        isError: true,
                      );
                      return;
                    }

                    final email = await SecureStorage.getEmail();
                    if (email != null && email.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FingerprintSetupPage(email: email),
                        ),
                      );
                    } else {
                      _safeShowMessage(
                        "Please login with email & password first to enable biometric.",
                        isError: true,
                      );
                    }
                  },
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      color: !hasEmail
                          ? Colors.grey.shade600
                          : const Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBiometricStatusInfo() {
    return FutureBuilder<bool>(
      future: SecureStorage.isBiometricEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;

        return FutureBuilder<String?>(
          future: SecureStorage.getEmail(),
          builder: (context, emailSnapshot) {
            final hasEmail = emailSnapshot.data != null &&
                emailSnapshot.data!.isNotEmpty;

            String statusText;
            Color statusColor;
            IconData statusIcon;

            if (!hasEmail) {
              statusText = "ℹ️ Please login with Email & Password first";
              statusColor = Colors.orange;
              statusIcon = Icons.info_outline;
            } else if (isEnabled) {
              statusText = "✅ Fingerprint login is ready";
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
            } else {
              statusText =
                  "ℹ️ Enable fingerprint in Settings → Biometric Login first";
              statusColor = Colors.orange;
              statusIcon = Icons.fingerprint;
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // REGISTER TAB
  // ============================================================
  Widget _buildRegisterTab(AuthController auth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildTextField(registerNameCtrl, "Full Name", Icons.person_outline,
              isRequired: true),
          const SizedBox(height: 12),
          _buildTextField(
              registerEmailCtrl, "Email Address", Icons.email_outlined,
              isRequired: true),
          const SizedBox(height: 12),
          _buildTextField(
              registerMobileCtrl, "Mobile Number", Icons.phone_android_outlined,
              isRequired: true),
          const SizedBox(height: 16),
          // ✅ Register password field (isLoginField: false)
          _buildPasswordField(
            registerPasswordCtrl,
            "Password",
            Icons.lock_outline,
            isRequired: true,
            isLoginField: false,
          ),
          const SizedBox(height: 12),
          _PasswordStrengthRow(
            hasUpper: hasUpper,
            hasLower: hasLower,
            hasNumber: hasNumber,
            hasSymbol: hasSymbol,
            isLongEnough: isLongEnough,
          ),
          const SizedBox(height: 24),
          _ModernButton(
            text: "Create Account",
            isLoading: auth.isLoading,
            onTap: () {
              final name = registerNameCtrl.text.trim();
              final email = registerEmailCtrl.text.trim();
              final mobile = registerMobileCtrl.text.trim();
              final password = registerPasswordCtrl.text.trim();

              if (name.isEmpty) {
                _safeShowMessage("Please enter your full name", isError: true);
                return;
              }
              if (email.isEmpty) {
                _safeShowMessage("Please enter your email address", isError: true);
                return;
              }
              if (mobile.isEmpty) {
                _safeShowMessage("Please enter your mobile number", isError: true);
                return;
              }
              if (password.isEmpty) {
                _safeShowMessage("Please enter a password", isError: true);
                return;
              }
              if (mobile.length != 10 ||
                  !RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
                _safeShowMessage("Mobile number must be 10 digits", isError: true);
                return;
              }
              if (!_isPasswordValid()) {
                _safeShowMessage(
                  "Password must contain:\n• Min 8 chars\n• 1 Uppercase\n• 1 Lowercase\n• 1 Number\n• 1 Special Character",
                  isError: true,
                );
                return;
              }

              auth.register({
                "name": name,
                "email": email,
                "mobile": mobile,
                "password": password,
              }, context);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON WIDGETS
  // ============================================================
  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isRequired = false,
  }) {
    return TextField(
      controller: ctrl,
      enabled: true, // ✅ Explicitly enabled
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // ============================================================
  // ✅ FIXED: PASSWORD FIELD
  // ✅ Removed StatefulBuilder (was causing state sync issues)
  // ✅ Uses OUTER setState via callback
  // ============================================================
  Widget _buildPasswordField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isRequired = false,
    required bool isLoginField,
  }) {
    // ✅ Choose which state variable based on context
    final bool isObscured = isLoginField ? !showPassword : !showRegisterPassword;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: ctrl,
        obscureText: isObscured,
        enabled: true,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              isObscured ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey.shade600,
              size: 18,
            ),
            // ✅ CRITICAL FIX: Call OUTER setState
            onPressed: () {
              setState(() {
                if (isLoginField) {
                  showPassword = !showPassword;
                } else {
                  showRegisterPassword = !showRegisterPassword;
                }
              });
            },
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ============================================================
// PASSWORD STRENGTH WIDGET
// ============================================================
class _PasswordStrengthRow extends StatelessWidget {
  final bool hasUpper, hasLower, hasNumber, hasSymbol, isLongEnough;
  const _PasswordStrengthRow({
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.hasSymbol,
    required this.isLongEnough,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StrengthItem("At least 8 characters", isLongEnough),
          const SizedBox(height: 3),
          _StrengthItem("One uppercase letter", hasUpper),
          const SizedBox(height: 3),
          _StrengthItem("One lowercase letter", hasLower),
          const SizedBox(height: 3),
          _StrengthItem("One number", hasNumber),
          const SizedBox(height: 3),
          _StrengthItem("One special character", hasSymbol),
        ],
      ),
    );
  }
}

class _StrengthItem extends StatelessWidget {
  final String text;
  final bool valid;
  const _StrengthItem(this.text, this.valid);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          valid ? Icons.check_circle : Icons.cancel,
          color: valid ? Colors.green : Colors.red,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: valid ? Colors.green : Colors.grey.shade600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MODERN BUTTON
// ============================================================
class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const _ModernButton({
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}