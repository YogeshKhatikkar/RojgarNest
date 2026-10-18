// lib/features/home/home_screen.dart
// ✅ AI‑BASED MODERN DESIGN (light gradient, glass containers, brand colors)
// ✅ SEPARATE UI FOR MOBILE (centered buttons) AND WEB (full landing page)
// ✅ FAST LOADING – optimized animations and minimal dependencies
// ✅ REUSES THE SAME DESIGN LANGUAGE AS BasicDetails, Education, Auth screens
// ✅ NEW: Added Hindi tagline "नौकरियों का असली घर" below RojgarNest

import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';
import 'package:dio/dio.dart';
import 'package:rojgarnest/core/widgets/platform_aware.dart';
import 'package:rojgarnest/core/utils/platform_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isBackendHealthy = false;
  bool _checkingBackend = true;
  String? _backendError;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _slideAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBackendHealth() async {
    setState(() {
      _checkingBackend = true;
      _backendError = null;
    });

    try {
      final Dio dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:8000',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final Response response = await dio.get('/api/v1/');

      if (response.statusCode == 200) {
        _isBackendHealthy = true;
      } else {
        _isBackendHealthy = false;
        _backendError = "Backend returned status: ${response.statusCode}";
      }
    } on DioException catch (e) {
      _isBackendHealthy = false;
      if (e.type == DioExceptionType.connectionTimeout) {
        _backendError = "Connection timeout. Backend not responding.";
      } else if (e.type == DioExceptionType.connectionError) {
        _backendError =
            "Cannot connect to backend. Is it running on port 8000?";
      } else if (e.response?.statusCode == 404) {
        _backendError =
            "Backend API endpoint not found. Please check backend configuration.";
      } else {
        _backendError = "Backend error: ${e.message}";
      }
    } catch (e) {
      _isBackendHealthy = false;
      _backendError = "Unexpected error: $e";
    } finally {
      if (mounted) {
        setState(() => _checkingBackend = false);
      }
    }
  }

  void _navigateToLoginTab() {
    context.push('${AppRoutes.auth}?tab=0');
  }

  void _navigateToRegisterTab() {
    context.push('${AppRoutes.auth}?tab=1');
  }

  // ============================================================
  // BUILD – Separate UI for Mobile and Web
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bool isWeb = PlatformUtils.isWeb;

    if (isWeb) {
      return _buildWebHomePage();
    } else {
      return _buildMobileHomePage();
    }
  }

  // ============================================================
  // MOBILE HOME PAGE – AI‑BASED MODERN DESIGN
  // ============================================================
  Widget _buildMobileHomePage() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),
              // Backend Status
              if (!_isBackendHealthy && !_checkingBackend && _backendError != null)
                _buildBackendStatus(),
              if (_checkingBackend) _buildCheckingStatus(),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      _buildAIHeroSection(),
                      const SizedBox(height: 24),
                      _buildAIFeaturesBadges(),
                      const SizedBox(height: 24),
                      _buildTagline(),
                      const SizedBox(height: 32),
                      _buildLoginRegisterButtons(),
                      const SizedBox(height: 20),
                      _buildAIPoweredBadge(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WEB HOME PAGE – Full Landing Page with Modern Design
  // ============================================================
  Widget _buildWebHomePage() {
    final Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width <= 600;
    final bool isTablet = size.width > 600 && size.width <= 900;
    final bool isDesktop = size.width > 900;

    final double heroFontSize = isDesktop ? 52 : (isTablet ? 44 : 36);
    final double subtitleFontSize = isDesktop ? 18 : 16;
    final double descriptionFontSize = isDesktop ? 16 : 14;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar – Glass
              _buildWebTopBar(isDesktop, isTablet),
              // Backend Status
              if (!_isBackendHealthy && !_checkingBackend && _backendError != null)
                _buildBackendStatus(),
              if (_checkingBackend) _buildCheckingStatus(),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Hero Section
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 80 : (isTablet ? 50 : 24),
                          vertical: isDesktop ? 60 : 40,
                        ),
                        child: Column(
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 50 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                "Find Your Dream Job",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: heroFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "AI-Powered Job Portal with Smart Matching",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Thousands of jobs from top companies waiting for you",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: descriptionFontSize,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 48),
                            if (!isMobile)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildWebGradientButton(
                                    text: "Get Started",
                                    icon: Icons.arrow_forward,
                                    onTap: _navigateToRegisterTab,
                                    width: 200,
                                  ),
                                  const SizedBox(width: 20),
                                  OutlinedButton.icon(
                                    onPressed: _navigateToLoginTab,
                                    icon: const Icon(Icons.login),
                                    label: const Text("Login"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF6C63FF),
                                      side: const BorderSide(
                                        color: Color(0xFF6C63FF),
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Stats Cards
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildWebStatCard("10K+", "Active Jobs", Icons.work, Colors.blue),
                            _buildWebStatCard("5K+", "Companies", Icons.business, Colors.green),
                            _buildWebStatCard("50K+", "Users", Icons.people, Colors.purple),
                            _buildWebStatCard("1K+", "Placements", Icons.celebration, Colors.orange),
                          ],
                        ),
                      ),
                      // AI Features
                      _buildWebAIFeaturesSection(),
                      // How It Works
                      _buildWebStepsSection(),
                      // Testimonial
                      _buildWebTestimonial(),
                      // CTA
                      _buildWebCTA(),
                      // Footer
                      _buildWebFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESIGN HELPERS – Shared across Mobile and Web
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
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildGlassContainerDecoration(),
      child: child,
    );
  }

  // ============================================================
  // MOBILE COMPONENTS
  // ============================================================

  Widget _buildTopBar() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // App Icon + Name Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                      ).createShader(bounds),
                      child: const Text(
                        "RojgarNest",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "AI",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // ✅ NEW: Hindi Tagline below RojgarNest
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ).createShader(bounds),
                  child: const Text(
                    "नौकरियों का असली घर",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIHeroSection() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              children: [
                // AI Glowing Circle
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.3),
                        const Color(0xFFFF6588).withOpacity(0.2),
                        Colors.transparent,
                      ],
                      radius: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 50,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 2,
                          ),
                          gradient: SweepGradient(
                            colors: [
                              const Color(0xFF6C63FF).withOpacity(0.5),
                              const Color(0xFFFF6588).withOpacity(0.5),
                              const Color(0xFF6C63FF).withOpacity(0.5),
                            ],
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF5F7FA),
                          ),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                      ...List.generate(12, (index) {
                        final angle = index * 30 * math.pi / 180;
                        final radius = 70.0;
                        return Positioned(
                          left: 70 + radius * 0.7 * math.cos(angle) - 4,
                          top: 70 + radius * 0.7 * math.sin(angle) - 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6C63FF).withOpacity(0.6 + 0.4 * (index / 12)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C63FF).withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "AI-Powered Career",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Find Your Dream Job with",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.2),
                        const Color(0xFFFF6588).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                    ).createShader(bounds),
                    child: const Text(
                      "RojgarNest AI",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                // ✅ NEW: Hindi Tagline in Hero Section
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ).createShader(bounds),
                  child: const Text(
                    "नौकरियों का असली घर",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIFeaturesBadges() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _slideAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _slideAnimation.value)),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildAIBadge(Icons.auto_awesome, "AI Matching", const Color(0xFF6C63FF)),
                _buildAIBadge(Icons.analytics, "Smart Insights", const Color(0xFFFF6588)),
                _buildAIBadge(Icons.trending_up, "Career Growth", Colors.cyan),
                _buildAIBadge(Icons.security, "Secure", Colors.green),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade100.withOpacity(0.5),
                  Colors.white.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // ✅ NEW: Hindi Tagline in Tagline Section
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ).createShader(bounds),
                  child: const Text(
                    "नौकरियों का असली घर",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "🚀 Join 50,000+ professionals\nusing AI to find their dream jobs",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.6,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginRegisterButtons() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildGradientButton(
                    text: "Login",
                    icon: Icons.login,
                    onTap: _navigateToLoginTab,
                    isOutlined: false,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildGradientButton(
                    text: "Register",
                    icon: Icons.app_registration,
                    onTap: _navigateToRegisterTab,
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isOutlined
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
            color: isOutlined ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(30),
            border: isOutlined
                ? Border.all(color: const Color(0xFF6C63FF), width: 1.5)
                : null,
            boxShadow: isOutlined
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isOutlined ? const Color(0xFF6C63FF) : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isOutlined ? const Color(0xFF6C63FF) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIPoweredBadge() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value * 0.7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.1),
                  const Color(0xFFFF6588).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C63FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "⚡ AI-Powered • Smart Matching • Secure",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackendStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: _checkBackendHealth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "⚠️ $_backendError",
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.refresh, size: 14, color: Colors.red.shade200),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckingStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF6C63FF),
              ),
            ),
            SizedBox(width: 8),
            Text(
              "Connecting...",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WEB COMPONENTS
  // ============================================================

  Widget _buildWebTopBar(bool isDesktop, bool isTablet) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 60 : (isTablet ? 40 : 20),
              vertical: 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.work_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                          ).createShader(bounds),
                          child: const Text(
                            "RojgarNest",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (kIsWeb)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "🌐 Web",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // ✅ NEW: Hindi Tagline below RojgarNest in Web Top Bar
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 70),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                        ).createShader(bounds),
                        child: const Text(
                          "नौकरियों का असली घर",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isDesktop || isTablet)
                  Row(
                    children: [
                      _buildWebGlassButton(
                        text: "Login",
                        icon: Icons.login,
                        isOutlined: true,
                        onTap: _navigateToLoginTab,
                      ),
                      const SizedBox(width: 12),
                      _buildWebGlassButton(
                        text: "Register",
                        icon: Icons.app_registration,
                        isOutlined: false,
                        onTap: _navigateToRegisterTab,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebGlassButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isOutlined
            ? null
            : const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
        border: isOutlined
            ? Border.all(color: const Color(0xFF6C63FF), width: 1.5)
            : null,
        boxShadow: isOutlined
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: isOutlined ? const Color(0xFF6C63FF) : Colors.white,
        ),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isOutlined ? const Color(0xFF6C63FF) : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : Colors.transparent,
          foregroundColor: isOutlined ? const Color(0xFF6C63FF) : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildWebGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    double width = double.infinity,
    double fontSize = 15,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildWebStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebAIFeaturesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Text(
            "Powered by Advanced AI",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Revolutionary features to accelerate your career",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildWebAIFeatureCard(
                icon: Icons.auto_awesome,
                title: "AI Career Analysis",
                description: "Get personalized career insights",
                gradientColors: const [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              _buildWebAIFeatureCard(
                icon: Icons.search,
                title: "Smart Job Matching",
                description: "AI-powered job recommendations",
                gradientColors: const [Colors.blue, Colors.cyan],
              ),
              _buildWebAIFeatureCard(
                icon: Icons.assignment_turned_in,
                title: "Resume Scoring",
                description: "AI evaluates your resume",
                gradientColors: const [Colors.teal, Colors.green],
              ),
              _buildWebAIFeatureCard(
                icon: Icons.insights,
                title: "Career Growth",
                description: "Predict your career trajectory",
                gradientColors: const [Colors.orange, Colors.red],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebAIFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebStepsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Text(
            "How RojgarNest Works",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your journey to the perfect job in 4 simple steps",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 30,
            runSpacing: 30,
            alignment: WrapAlignment.center,
            children: [
              _buildWebStepCard("1", "Create Profile", Icons.person_add),
              _buildWebStepCard("2", "AI Analysis", Icons.auto_awesome),
              _buildWebStepCard("3", "Smart Matching", Icons.sync),
              _buildWebStepCard("4", "Apply & Grow", Icons.trending_up),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebStepCard(String step, String title, IconData icon) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 32, color: const Color(0xFF6C63FF)),
          const SizedBox(height: 12),
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
    );
  }

  Widget _buildWebTestimonial() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.grey.shade300.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.format_quote, size: 50, color: Color(0xFF6C63FF)),
          const SizedBox(height: 20),
          const Text(
            "RojgarNest helped me find my dream job in just 2 weeks!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "- Rahul Sharma",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Software Engineer at Google",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (index) => const Icon(Icons.star, color: Colors.amber, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCTA() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Ready to Start Your Career Journey?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Join thousands of successful job seekers",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _navigateToRegisterTab,
              icon: const Icon(Icons.rocket_launch, color: Color(0xFF6C63FF)),
              label: const Text(
                "Get Started Now",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6C63FF),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(30),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                ).createShader(bounds),
                child: const Text(
                  "RojgarNest",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "🌐 Web App",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
          // ✅ NEW: Hindi Tagline in Footer
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
            ).createShader(bounds),
            child: const Text(
              "नौकरियों का असली घर",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildWebFooterLink("About Us"),
              _buildWebFooterLink("Contact"),
              _buildWebFooterLink("Privacy Policy"),
              _buildWebFooterLink("Terms of Service"),
              _buildWebFooterLink("Help Center"),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "© 2025 RojgarNest. All rights reserved.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            "Find Your Dream Job with AI-Powered Career Guidance",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFooterLink(String text) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}