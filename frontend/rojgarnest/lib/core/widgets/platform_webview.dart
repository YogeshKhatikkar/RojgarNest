// lib/core/widgets/platform_webview.dart
// ✅ Android-safe WebView — no web-only packages imported.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/platform_utils.dart';

class PlatformWebView extends StatefulWidget {
  final String htmlContent;
  final String? url;
  final String title;
  final bool showAppBar;

  const PlatformWebView({
    super.key,
    required this.htmlContent,
    this.url,
    this.title = 'Preview',
    this.showAppBar = true,
  });

  @override
  State<PlatformWebView> createState() => _PlatformWebViewState();
}

class _PlatformWebViewState extends State<PlatformWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isWeb = false;

  @override
  void initState() {
    super.initState();
    _isWeb = PlatformUtils.isWeb;

    // Web build (compiled separately) handles WebView differently.
    // On Android/iOS/desktop — use native WebView.
    if (!_isWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = true);
            },
            onWebResourceError: (error) {
              debugPrint('❌ WebView error: ${error.description}');
              if (mounted) setState(() => _isLoading = false);
            },
          ),
        )
        ..loadHtmlString(widget.htmlContent);
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              actions: [
                if (_controller != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        _controller!.loadHtmlString(widget.htmlContent),
                  ),
              ],
            )
          : null,
      body: _isWeb
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Preview not supported on this platform.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}