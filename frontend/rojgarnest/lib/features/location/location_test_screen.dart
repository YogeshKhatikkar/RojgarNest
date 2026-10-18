// lib/features/location/location_test_screen.dart
// FIXED VERSION - No async gap warnings

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/services/unified_location_service.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _location;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Test - REAL GPS'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _getRealLocation,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Get REAL GPS Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text('❌ Error: $_error'),
              ),
            ],
            if (_location != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📍 YOUR REAL LOCATION:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Location Name', _location!['location_name']),
                    _buildInfoRow(
                        'Latitude', _location!['latitude'].toString()),
                    _buildInfoRow(
                        'Longitude', _location!['longitude'].toString()),
                    _buildInfoRow(
                        'Accuracy', '${_location!['accuracy']} meters'),
                    _buildInfoRow('Source', _location!['source']),
                    _buildInfoRow('Confidence', _location!['confidence']),
                    _buildInfoRow('Platform', _location!['platform']),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    '⚠️ NOTE:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Allow location permission when prompted\n'
                    '• Turn ON GPS on your phone\n'
                    '• On Web: Allow browser location access\n'
                    '• If still showing Bhopal, check your GPS settings',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      // ✅ FIXED: EdgeInsets.symmetric का use करें
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ✅ FIXED: Added mounted check
  Future<void> _getRealLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _location = null;
    });

    try {
      final location = await UnifiedLocationService.getCurrentLocation();

      // ✅ CRITICAL: Check if widget is still mounted before using context
      if (!mounted) return;

      setState(() {
        _location = location;
      });

      // ✅ Show success message with mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Location found: ${location['location_name']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // ✅ Check mounted before using context
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // ✅ Check mounted before setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
