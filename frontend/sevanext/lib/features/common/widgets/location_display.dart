// lib/features/common/widgets/location_display.dart
// ⚠️ LOCATION DISPLAY - TEMPORARILY HIDDEN
// Backend me location save hota rahega, frontend me sirf hide kiya hai
// Future me enable karne ke liye bas comment symbols hata dena

import 'package:flutter/material.dart';

class LocationDisplay extends StatefulWidget {
  const LocationDisplay({super.key});

  @override
  State<LocationDisplay> createState() => _LocationDisplayState();
}

class _LocationDisplayState extends State<LocationDisplay> {
  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ⚠️ LOCATION DISPLAY - TEMPORARILY HIDDEN
    // ============================================================
    // Backend me location save hota rahega.
    // Future me enable karne ke liye:
    // 1. Return statement ke comment symbols hata do
    // 2. "return const SizedBox.shrink();" ko comment kar do
    // 3. Sab variables aur methods ka comment hata do
    // 4. Sab import statements ka comment hata do
    // ============================================================

    // ✅ LOCATION DISPLAY HIDDEN - Returns empty widget (No warnings)
    return const SizedBox.shrink();

    /* ==================== ORIGINAL CODE (COMMENTED) ====================
    bool _isLoading = true;
    String _locationName = 'Fetching location...';
    bool _hasLocation = false;

    @override
    void initState() {
      super.initState();
      _loadLocation();
    }

    Future<void> _loadLocation() async {
      final auth = Provider.of<AuthController>(context, listen: false);
      final locationData = await auth.getUserLocationDetails();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLocation = locationData?['has_location'] ?? false;
          if (_hasLocation && locationData != null) {
            _locationName =
                locationData['location']?['location_name'] ??
                locationData['location']?['formatted_name'] ??
                'Unknown location';
          } else {
            _locationName = 'Location not saved';
          }
        });
      }
    }

    Future<void> _refreshLocation() async {
      setState(() => _isLoading = true);
      await _loadLocation();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 20,
            color: _hasLocation ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Flexible(
              child: Text(
                _locationName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _hasLocation ? Colors.black87 : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _refreshLocation,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
    ============================================================ */
  }
}
