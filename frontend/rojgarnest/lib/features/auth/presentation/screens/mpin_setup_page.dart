// lib/features/auth/presentation/screens/mpin_setup_page.dart
// ✅ AI‑BASED MODERN DESIGN
// ✅ BULLETPROOF FIX for Android / iOS toggle not turning ON
// ✅ Removed Transform.scale (hit-area misalignment)
// ✅ Toggle state flips SYNCHRONOUSLY in one setState
// ✅ Debug logs to trace exact behaviour
// ✅ All original logic preserved

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';
import 'package:rojgarnest/features/auth/presentation/controllers/auth_controller.dart';
import 'package:go_router/go_router.dart';

class MpinSetupPage extends StatefulWidget {
  final String email;

  const MpinSetupPage({
    super.key,
    required this.email,
  });

  @override
  State<MpinSetupPage> createState() => _MpinSetupPageState();
}

class _MpinSetupPageState extends State<MpinSetupPage> {
  // ============================================================
  // DEBUG LOG HELPER
  // ============================================================
  void _log(String msg) {
    if (kDebugMode) debugPrint('🎯 MPIN_TOGGLE | $msg');
  }

  // ============================================================
  // CONTROLLERS
  // ============================================================
  final List<TextEditingController> _mpinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _confirmMpinControllers =
      List.generate(6, (_) => TextEditingController());

  // ============================================================
  // FOCUS NODES
  // ============================================================
  final List<FocusNode> _mpinFocusNodes =
      List.generate(6, (_) => FocusNode());
  final List<FocusNode> _confirmMpinFocusNodes =
      List.generate(6, (_) => FocusNode());

  // ============================================================
  // STATE
  // ============================================================
  bool _isSaving = false;
  String _errorMessage = '';
  bool _isDisposed = false;
  bool _isClearingControllers = false;

  bool _isMpinEnabled = false;
  bool _isLoading = true;
  bool _hasExistingMpin = false;
  bool _showForm = false;

  bool _showMpin = false;
  bool _showConfirmMpin = false;

  // ============================================================
  // GETTERS
  // ============================================================
  String get _mpin => _mpinControllers.map((c) => c.text).join();
  String get _confirmMpin => _confirmMpinControllers.map((c) => c.text).join();
  bool get _isMpinComplete => _mpin.length == 6;
  bool get _isConfirmMpinComplete => _confirmMpin.length == 6;

  // ============================================================
  // LIFECYCLE
  // ============================================================
  @override
  void initState() {
    super.initState();
    _log('initState — checking MPIN status');
    _checkMpinStatus();

    for (int i = 0; i < 6; i++) {
      _mpinControllers[i].addListener(() {
        if (mounted && !_isDisposed && !_isClearingControllers) {
          setState(() {});
        }
      });
      _confirmMpinControllers[i].addListener(() {
        if (mounted && !_isDisposed && !_isClearingControllers) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MpinSetupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _log('didUpdateWidget — email changed: ${oldWidget.email} → ${widget.email}');
    // If email changed, restart status check
    if (oldWidget.email != widget.email) {
      _checkMpinStatus();
    }
  }

  @override
  void dispose() {
    _log('dispose called');
    _isDisposed = true;
    for (var controller in _mpinControllers) {
      controller.dispose();
    }
    for (var controller in _confirmMpinControllers) {
      controller.dispose();
    }
    for (var node in _mpinFocusNodes) {
      node.dispose();
    }
    for (var node in _confirmMpinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // CHECK MPIN STATUS
  // ============================================================
  Future<void> _checkMpinStatus() async {
    if (!mounted) return;
    _log('_checkMpinStatus — start');
    setState(() => _isLoading = true);
    try {
      final hasMpin = await SecureStorage.hasMpin();
      final isEnabled = await SecureStorage.isMpinEnabled();
      _log('_checkMpinStatus — hasMpin=$hasMpin isEnabled=$isEnabled');
      if (!mounted) return;
      setState(() {
        _hasExistingMpin = hasMpin;
        _isMpinEnabled = hasMpin && isEnabled;
        _showForm = false;
        _isLoading = false;
      });
      _log('_checkMpinStatus — done. _isMpinEnabled=$_isMpinEnabled');
    } catch (e) {
      _log('_checkMpinStatus — error: $e');
      if (mounted) {
        setState(() {
          _isMpinEnabled = false;
          _hasExistingMpin = false;
          _showForm = false;
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SAFE CLEAR (NO setState, listeners suppressed)
  // ============================================================
  void _clearControllersOnly() {
    if (_isDisposed) return;
    _isClearingControllers = true;
    for (final c in _mpinControllers) {
      c.clear();
    }
    for (final c in _confirmMpinControllers) {
      c.clear();
    }
    _isClearingControllers = false;
  }

  void _focusFirstMpinBox() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_showForm) return;
      try {
        FocusScope.of(context).requestFocus(_mpinFocusNodes[0]);
      } catch (_) {}
    });
  }

  // ============================================================
  // ✅ BULLETPROOF TOGGLE HANDLER
  //    The VERY FIRST thing this does after the guard, is either
  //    flip the flag immediately via setState, or await a dialog.
  //    No interleaved async work before the state flip.
  // ============================================================
  Future<void> _toggleMpin(bool value) async {
    _log('════════════════════════════════════════');
    _log('onChanged fired → value=$value');
    _log('  _hasExistingMpin=$_hasExistingMpin');
    _log('  _showForm=$_showForm');
    _log('  _isMpinEnabled=$_isMpinEnabled');
    _log('  _isLoading=$_isLoading');
    _log('  mounted=$mounted, _isDisposed=$_isDisposed');

    if (!mounted || _isDisposed) {
      _log('  ABORT: not mounted / disposed');
      return;
    }

    // ====================================================================
    // TURNING ON
    // ====================================================================
    if (value) {
      _log('  → TURNING ON');

      // ----- CASE A: MPIN already saved → just enable -----
      if (_hasExistingMpin) {
        _log('  CASE A: existing MPIN → just flip flag');
        setState(() {
          _isMpinEnabled = true;
          _showForm = false;
          _errorMessage = '';
        });
        try {
          await SecureStorage.setMpinEnabled(true);
        } catch (e) {
          _log('  error persisting enabled=true: $e');
          if (mounted) {
            setState(() => _isMpinEnabled = false);
          }
        }
        return;
      }

      // ----- CASE B: First-time setup → show form -----
      _log('  CASE B: first-time setup → show form');
      _clearControllersOnly();
      if (!mounted) return;
      setState(() {
        _isMpinEnabled = true;
        _showForm = true;
        _errorMessage = '';
      });
      _log('  AFTER setState → _isMpinEnabled=$_isMpinEnabled _showForm=$_showForm');
      _focusFirstMpinBox();
      return;
    }

    // ====================================================================
    // TURNING OFF
    // ====================================================================
    _log('  → TURNING OFF');

    // ----- CASE C: No MPIN saved → just hide form -----
    if (!_hasExistingMpin) {
      _log('  CASE C: no existing MPIN → just hide form');
      _clearControllersOnly();
      if (!mounted) return;
      setState(() {
        _isMpinEnabled = false;
        _showForm = false;
        _errorMessage = '';
      });
      return;
    }

    // ----- CASE D: Real MPIN → confirm before disable -----
    _log('  CASE D: existing MPIN → confirm dialog');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Disable MPIN"),
        content: const Text(
          "Are you sure you want to disable MPIN login?\n\n"
          "You can enable it again later from settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Disable"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      _log('  Confirm dialog cancelled');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SecureStorage.setMpinEnabled(false);
      _clearControllersOnly();
      if (!mounted) return;
      setState(() {
        _isMpinEnabled = false;
        _showForm = false;
        _hasExistingMpin = false;
        _errorMessage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("MPIN disabled successfully"),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _log('  error disabling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to disable MPIN: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // SAVE MPIN
  // ============================================================
  Future<void> _saveMpin() async {
    if (_isDisposed) return;

    final String mpin = _mpin;
    final String confirmMpin = _confirmMpin;

    if (mpin.length != 6) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Please enter 6-digit MPIN');
      return;
    }
    if (confirmMpin.length != 6) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Please confirm your 6-digit MPIN');
      return;
    }
    if (mpin != confirmMpin) {
      _clearControllersOnly();
      if (!mounted) return;
      setState(() => _errorMessage = 'MPIN does not match. Please try again.');
      _focusFirstMpinBox();
      return;
    }

    if (!mounted || _isDisposed) return;
    setState(() {
      _errorMessage = '';
      _isSaving = true;
    });

    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      await authController.setupMpin(widget.email, mpin);
      await SecureStorage.saveMpin(mpin);
      await SecureStorage.setMpinEnabled(true);

      if (!mounted || _isDisposed) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("MPIN saved successfully! 🔒"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      _clearControllersOnly();

      if (!mounted) return;
      setState(() {
        _hasExistingMpin = true;
        _isMpinEnabled = true;
        _showForm = false;
        _isSaving = false;
        _errorMessage = '';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isDisposed) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go(AppRoutes.userDashboard);
        }
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _isSaving = false;
        _showForm = true;
        _errorMessage = 'Failed to save MPIN. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save MPIN: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    _log('build — _isLoading=$_isLoading _isMpinEnabled=$_isMpinEnabled _showForm=$_showForm');

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
                  _buildToggleCard(),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty) _buildErrorWidget(),
                  if (_hasExistingMpin && _isMpinEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildRemoveButton(),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESIGN
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
                  "AI is loading your security...",
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

  Widget _buildHeader() {
    final bool isActive = _isMpinEnabled && _hasExistingMpin;
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
            child: Icon(
              isActive ? Icons.lock_open : Icons.lock_outline,
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
                  "MPIN Security",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isActive
                      ? "Your MPIN is currently enabled"
                      : _showForm
                          ? "Set up a 6‑digit PIN for quick login"
                          : "Enable MPIN for faster & secure login",
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

  // ============================================================
  // TOGGLE CARD
  // ============================================================
  Widget _buildToggleCard() {
    return _buildGlassContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isMpinEnabled
                            ? Colors.green.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pin,
                        color: _isMpinEnabled
                            ? Colors.green
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MPIN Login",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _isMpinEnabled
                                  ? Colors.green
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            _isMpinEnabled && _hasExistingMpin
                                ? "Quick login with 6‑digit PIN"
                                : _showForm
                                    ? "Set your 6‑digit PIN below"
                                    : "Enable MPIN for faster login",
                            style: TextStyle(
                              fontSize: 12,
                              color: _isMpinEnabled
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ REMOVED Transform.scale — was breaking hit-area on mobile
              Switch(
                value: _isMpinEnabled,
                onChanged: _toggleMpin,
                activeThumbColor: Colors.green,
                activeTrackColor: Colors.green.shade200,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.shade300,
              ),
            ],
          ),

          if (_isMpinEnabled && _hasExistingMpin)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "MPIN is enabled. You can use it for quick login.\n"
                      "✅ Your MPIN will NEVER be deleted on logout.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_showForm)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Set your MPIN below to enable MPIN login",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_showForm) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.grey, thickness: 1),
            const SizedBox(height: 20),
            _buildMpinForm(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MPIN FORM
  // ============================================================
  Widget _buildMpinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Enter MPIN", Icons.pin, Colors.blueAccent),
        const SizedBox(height: 12),
        _buildMpinInputRow(
          controllers: _mpinControllers,
          focusNodes: _mpinFocusNodes,
          isConfirm: false,
          onComplete: () {
            if (_mpin.length == 6) {
              try {
                FocusScope.of(context)
                    .requestFocus(_confirmMpinFocusNodes[0]);
              } catch (_) {}
            }
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _showMpin = !_showMpin),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMpin ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showMpin ? "Hide" : "Show",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Confirm MPIN", Icons.verified, Colors.green),
        const SizedBox(height: 12),
        _buildMpinInputRow(
          controllers: _confirmMpinControllers,
          focusNodes: _confirmMpinFocusNodes,
          isConfirm: true,
          onComplete: () {
            if (_confirmMpin.length == 6 && _mpin.length == 6) {
              _saveMpin();
            }
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () =>
                  setState(() => _showConfirmMpin = !_showConfirmMpin),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showConfirmMpin
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showConfirmMpin ? "Hide" : "Show",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isMpinComplete && _isConfirmMpinComplete)
          _buildSaveButton()
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Enter and confirm 6‑digit MPIN to save",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 18),
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

  Widget _buildMpinInputRow({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool isConfirm,
    required VoidCallback onComplete,
  }) {
    final bool showPin = isConfirm ? _showConfirmMpin : _showMpin;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return _buildMpinBox(
            controller: controllers[index],
            focusNode: focusNodes[index],
            onChanged: (value) {
              if (value.length == 1 && index < 5) {
                try {
                  FocusScope.of(context)
                      .requestFocus(focusNodes[index + 1]);
                } catch (_) {}
              }
              if (value.isEmpty && index > 0) {
                try {
                  FocusScope.of(context)
                      .requestFocus(focusNodes[index - 1]);
                } catch (_) {}
              }
              final currentValue =
                  controllers.map((c) => c.text).join();
              if (currentValue.length == 6) {
                onComplete();
              }
              if (mounted) setState(() {});
            },
            onSubmitted: (_) {
              if (index < 5) {
                try {
                  FocusScope.of(context)
                      .requestFocus(focusNodes[index + 1]);
                } catch (_) {}
              }
            },
            showPin: showPin,
          );
        }),
      ),
    );
  }

  // ============================================================
  // SINGLE MPIN BOX — no autofocus, explicit requestFocus elsewhere
  // ============================================================
  Widget _buildMpinBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    required Function(String) onSubmitted,
    required bool showPin,
  }) {
    return SizedBox(
      width: 46,
      height: 60,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: !showPin,
        obscuringCharacter: '●',
        enableIMEPersonalizedLearning: false,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: controller.text.isNotEmpty
              ? const Color(0xFF6C63FF).withOpacity(0.1)
              : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: focusNode.hasFocus
                  ? const Color(0xFF6C63FF)
                  : Colors.grey.shade300,
              width: focusNode.hasFocus ? 2.5 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF6C63FF),
              width: 2.5,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildSaveButton() {
    final bool isEnabled =
        _isMpinComplete && _isConfirmMpinComplete && !_isSaving;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isEnabled ? _saveMpin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.grey.shade300,
                      Colors.grey.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isSaving
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
                      Icon(Icons.save, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Save MPIN",
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

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = ''),
            child: const Icon(Icons.close,
                color: Colors.redAccent, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Remove MPIN"),
              content:
                  const Text("Are you sure you want to remove your MPIN?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Remove"),
                ),
              ],
            ),
          );

          if (confirm != true || !mounted) return;

          setState(() => _isLoading = true);
          try {
            await SecureStorage.deleteMpin();
            await SecureStorage.setMpinEnabled(false);
            _clearControllersOnly();
            if (!mounted) return;
            setState(() {
              _isMpinEnabled = false;
              _hasExistingMpin = false;
              _showForm = false;
              _errorMessage = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("MPIN removed successfully"),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Failed to remove MPIN: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text(
          "Remove MPIN",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_showForm && !_hasExistingMpin) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Cancel MPIN Setup"),
          content: const Text(
              "You haven't completed MPIN setup. Are you sure you want to leave?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Stay"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Leave"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _clearControllersOnly();
        if (mounted) {
          setState(() {
            _isMpinEnabled = false;
            _showForm = false;
            _errorMessage = '';
          });
        }
        return true;
      }
      return false;
    }
    return true;
  }
}