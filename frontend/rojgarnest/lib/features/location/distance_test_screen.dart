// lib/features/location/distance_test_screen.dart
// COMPLETE FIXED VERSION - NO NULL SAFETY ERRORS

import 'package:flutter/material.dart';
import 'package:rojgarnest/core/services/unified_location_service.dart';
import 'package:rojgarnest/core/utils/distance_calculator.dart';
import 'package:rojgarnest/core/utils/app_snackbar.dart';

class DistanceTestScreen extends StatefulWidget {
  const DistanceTestScreen({super.key});

  @override
  State<DistanceTestScreen> createState() => _DistanceTestScreenState();
}

class _DistanceTestScreenState extends State<DistanceTestScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _location1;
  Map<String, dynamic>? _location2;
  double? _distanceMeters;
  String? _formattedDistance;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Distance Calculator"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "दो locations के बीच की दूरी निकालें। GPS ON रखें।",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "1",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Location 1",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _getLocation(1),
                          icon: const Icon(Icons.location_searching, size: 18),
                          label: const Text("Get"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(80, 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_location1 != null) ...[
                      _buildInfoRow(
                        Icons.location_on,
                        "Location",
                        _location1!['location_name']?.toString() ?? 'N/A',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.gps_fixed,
                        "Latitude",
                        _location1!['latitude']?.toStringAsFixed(6) ?? 'N/A',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.gps_fixed,
                        "Longitude",
                        _location1!['longitude']?.toStringAsFixed(6) ?? 'N/A',
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            "No location selected",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "2",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Location 2",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _getLocation(2),
                          icon: const Icon(Icons.location_searching, size: 18),
                          label: const Text("Get"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size(80, 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_location2 != null) ...[
                      _buildInfoRow(
                        Icons.location_on,
                        "Location",
                        _location2!['location_name']?.toString() ?? 'N/A',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.gps_fixed,
                        "Latitude",
                        _location2!['latitude']?.toStringAsFixed(6) ?? 'N/A',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.gps_fixed,
                        "Longitude",
                        _location2!['longitude']?.toStringAsFixed(6) ?? 'N/A',
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            "No location selected",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_location1 == null || _location2 == null)
                    ? null
                    : _calculateDistance,
                icon: const Icon(Icons.calculate, size: 24),
                label: const Text(
                  "CALCULATE DISTANCE",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_formattedDistance != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Column(
                  children: <Widget>[
                    const Icon(Icons.straighten, size: 50, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _formattedDistance!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _distanceMeters != null && _distanceMeters! >= 1000
                          ? "${(_distanceMeters! / 1000).toStringAsFixed(2)} kilometers"
                          : "${_distanceMeters?.toStringAsFixed(0)} meters",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!)),
                  ],
                ),
              ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    "📊 Example Distances (For Reference):",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildExampleRow("Kukshi to Indore", "~120 km", Colors.blue),
                  _buildExampleRow("Kukshi to Bhopal", "~180 km", Colors.green),
                  _buildExampleRow("Kukshi to Delhi", "~800 km", Colors.orange),
                  _buildExampleRow(
                    "Kukshi to Mumbai",
                    "~650 km",
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getLocation(int locationNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> location =
          await UnifiedLocationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          if (locationNumber == 1) {
            _location1 = location;
          } else {
            _location2 = location;
          }
          _isLoading = false;
        });

        showMessage(
          context,
          "📍 Location ${locationNumber == 1 ? '1' : '2'} saved!",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _calculateDistance() {
    if (_location1 == null || _location2 == null) {
      showMessage(context, "Please get both locations first", isError: true);
      return;
    }

    final lat1 = _location1!['latitude'] as double;
    final lon1 = _location1!['longitude'] as double;
    final lat2 = _location2!['latitude'] as double;
    final lon2 = _location2!['longitude'] as double;

    final distanceInMeters = DistanceCalculator.calculateDistance(
      lat1,
      lon1,
      lat2,
      lon2,
    );
    final formatted = DistanceCalculator.formatDistance(lat1, lon1, lat2, lon2);

    setState(() {
      _distanceMeters = distanceInMeters;
      _formattedDistance = formatted;
    });
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildExampleRow(String places, String distance, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(places, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(
            distance,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
