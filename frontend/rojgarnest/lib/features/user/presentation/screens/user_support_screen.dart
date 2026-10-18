// lib/features/user/presentation/screens/user_support_screen.dart
// ✅ AI‑BASED MODERN DESIGN (light gradient, glass containers, brand colors)
// ✅ FULLY FUNCTIONAL: Email sending, Customer Care, WhatsApp, Copy to Clipboard
// ✅ FAST AND RESPONSIVE on all platforms

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  bool _isSubmitting = false;
  String? _userEmail;
  String? _userName;

  // Customer care numbers
  final List<Map<String, String>> _customerCareNumbers = [
    {'number': '7869986602', 'type': 'Primary', 'icon': '📞'},
    {'number': '1800125348', 'type': 'Toll-Free', 'icon': '📱'},
  ];

  // Support email (default recipient)
  static const String _supportEmail = "yhk.capital@gmail.com";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final email = await SecureStorage.getEmail();
      final name = await SecureStorage.getName();
      if (mounted) {
        setState(() {
          _userEmail = email ?? '';
          _userName = name ?? '';
        });
      }
      debugPrint("📧 Support - User Email: $_userEmail, Name: $_userName");
    } catch (e) {
      debugPrint("❌ Error loading user info: $e");
    }
  }

  Future<void> _sendSupportMessage() async {
    final message = _messageController.text.trim();
    final subject = _subjectController.text.trim();

    if (message.isEmpty) {
      showMessage(context, "Please enter your message", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await SecureStorage.getToken();
      if (token == null) {
        throw Exception("Please login to send support message");
      }

      final emailData = {
        'to': _supportEmail,
        'from_email': _userEmail,
        'from_name': _userName,
        'subject': subject.isNotEmpty
            ? subject
            : "Support Request from RojgarNest User",
        'message': message,
        'user_email': _userEmail,
        'user_name': _userName,
      };

      debugPrint("📧 Sending support email to: $_supportEmail");
      debugPrint("   From: $_userEmail");
      debugPrint(
          "   Subject: ${subject.isNotEmpty ? subject : 'Support Request'}");
      debugPrint("   Message length: ${message.length}");

      final response = await DioClient.dio.post(
        '/support/send-email',
        data: emailData,
      );

      if (!mounted) return;

      if (response.data['success'] == true) {
        showMessage(
          context,
          "✅ Your message has been sent to support team! We'll respond within 24-48 hours.",
        );
        _messageController.clear();
        _subjectController.clear();
      } else {
        throw Exception(response.data['message'] ?? "Failed to send message");
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("❌ Support email error: $e");
      _showEmailCompositionFallback(message, subject);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showEmailCompositionFallback(
      String message, String subject) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _buildEmailQuery(message, subject),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (mounted) {
        showMessage(
          context,
          "Opening email client. Please send your message to $_supportEmail",
        );
      }
    } else {
      if (mounted) {
        showMessage(
          context,
          "Could not open email client. Please email your message to: $_supportEmail",
          isError: true,
        );
      }
    }
  }

  String _buildEmailQuery(String message, String subject) {
    final params = <String, String>{
      'subject':
          subject.isNotEmpty ? subject : "Support Request from RojgarNest",
      'body': '''
User Name: ${_userName ?? 'Not provided'}
User Email: ${_userEmail ?? 'Not provided'}

Message: 
$message
---
This message was sent from RojgarNest App
      ''',
    };
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        showMessage(context, "Could not make call to $phoneNumber",
            isError: true);
      }
    }
  }

  Future<void> _sendWhatsAppMessage(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: cleanNumber,
      queryParameters: {'text': 'Hello, I need support from RojgarNest.'},
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showMessage(context, "WhatsApp is not installed on this device",
            isError: true);
      }
    }
  }

  void _copyEmailToClipboard() {
    Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (mounted) {
      showMessage(context, "Email address copied to clipboard!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildUserInfoCard(),
                const SizedBox(height: 20),
                _buildSendMessageSection(),
                const SizedBox(height: 20),
                _buildCustomerCareSection(),
                const SizedBox(height: 20),
                _buildAlternativeContactSection(),
                const SizedBox(height: 20),
                _buildFaqHint(),
                const SizedBox(height: 20),
              ],
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
  // HEADER
  // ============================================================
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
              Icons.support_agent,
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
                  "Support Center",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "We're here to help you 24/7",
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
  // USER INFO CARD
  // ============================================================
  Widget _buildUserInfoCard() {
    return _buildGlassContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName != null && _userName!.isNotEmpty
                      ? "Welcome, ${_userName!.split(' ').first}!"
                      : "Welcome, User!",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_userEmail != null && _userEmail!.isNotEmpty)
                  Text(
                    _userEmail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const Text(
                  "How can we help you today?",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadUserInfo,
            tooltip: "Refresh",
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEND MESSAGE SECTION
  // ============================================================
  Widget _buildSendMessageSection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Send Message to Support", Icons.email_outlined),
          const SizedBox(height: 16),
          // Subject Field
          _buildAITextField(
            _subjectController,
            "Subject (Optional)",
            prefixIcon: Icons.subject,
            hintText: "e.g., Application Issue, Technical Problem",
          ),
          const SizedBox(height: 12),
          // Message Field
          _buildAITextField(
            _messageController,
            "Your Message *",
            prefixIcon: Icons.message,
            maxLines: 5,
            hintText: "Describe your issue or question in detail...",
          ),
          const SizedBox(height: 8),
          Text(
            "We'll respond to your registered email: ${_userEmail ?? 'your email'}",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          // Send Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: _buildGradientButton(
              text: _isSubmitting ? "Sending..." : "Send Message",
              icon: Icons.send,
              isLoading: _isSubmitting,
              onTap: _isSubmitting ? null : _sendSupportMessage,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER CARE SECTION
  // ============================================================
  Widget _buildCustomerCareSection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Customer Care", Icons.phone_in_talk),
          const SizedBox(height: 16),
          ..._customerCareNumbers.map((contact) => _buildContactCard(
                icon: contact['icon']!,
                number: contact['number']!,
                label: contact['type']!,
                onCall: () => _makePhoneCall(contact['number']!),
                onWhatsApp: () => _sendWhatsAppMessage(contact['number']!),
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Support Hours: Mon-Sat, 10:00 AM - 6:00 PM",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
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

  Widget _buildContactCard({
    required String icon,
    required String number,
    required String label,
    required VoidCallback onCall,
    required VoidCallback onWhatsApp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Call Button
              InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call, color: Colors.green, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // WhatsApp Button
              InkWell(
                onTap: onWhatsApp,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat,
                      color: Color(0xFF25D366), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALTERNATIVE CONTACT SECTION
  // ============================================================
  Widget _buildAlternativeContactSection() {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Alternative Contact", Icons.alternate_email),
          const SizedBox(height: 16),
          InkWell(
            onTap: _copyEmailToClipboard,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.1),
                    const Color(0xFFFF6588).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF6C63FF),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Email Support",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _supportEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6588)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Copy",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FAQ HINT
  // ============================================================
  Widget _buildFaqHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.orange.shade100.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Quick FAQ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "• How to apply for jobs?\n"
                  "• How to update profile?\n"
                  "• Payment related issues?\n"
                  "Contact us for any assistance!",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    height: 1.5,
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
  // COMMON WIDGETS
  // ============================================================

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
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
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

  Widget _buildAITextField(
    TextEditingController ctrl,
    String label, {
    required IconData prefixIcon,
    int maxLines = 1,
    String? hintText,
  }) {
    return Container(
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
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          hintText: hintText ?? (label.contains('*') ? null : "Optional"),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(prefixIcon, color: Colors.grey.shade600, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    return ElevatedButton(
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
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}