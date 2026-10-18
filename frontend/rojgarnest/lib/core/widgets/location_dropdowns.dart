// lib/core/widgets/location_dropdowns.dart
import 'package:flutter/material.dart';
import 'package:rojgarnest/core/master_date/locations.dart';
import 'package:rojgarnest/core/services/geocoding_service.dart';

class LocationDropdowns extends StatefulWidget {
  final Function(String fullLocation, Map<String, dynamic>? coordinates)
  onLocationChanged;
  final String? initialCountry;
  final String? initialState;
  final String? initialDistrict;

  const LocationDropdowns({
    super.key,
    required this.onLocationChanged,
    this.initialCountry,
    this.initialState,
    this.initialDistrict,
  });

  @override
  State<LocationDropdowns> createState() => _LocationDropdownsState();
}

class _LocationDropdownsState extends State<LocationDropdowns> {
  String? selectedCountry;
  String? selectedState;
  String? selectedDistrict;

  bool _isGeocoding = false;
  Map<String, dynamic>? _coordinates;
  String _geocodingStatus = '';

  @override
  void initState() {
    super.initState();
    selectedCountry = widget.initialCountry ?? 'India';
    selectedState = widget.initialState;
    selectedDistrict = widget.initialDistrict;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyLocation();
    });
  }

  Future<void> _notifyLocation() async {
    if (selectedCountry != null &&
        selectedState != null &&
        selectedDistrict != null) {
      final fullLocation =
          "$selectedDistrict, $selectedState, $selectedCountry";

      setState(() {
        _isGeocoding = true;
        _geocodingStatus = 'Getting coordinates...';
      });

      final coordinates = await GeocodingService.geocodeAddress(fullLocation);

      setState(() {
        _isGeocoding = false;
        _coordinates = coordinates;
        if (coordinates != null) {
          _geocodingStatus = '✅ Coordinates found';
        } else {
          _geocodingStatus = '⚠️ Coordinates not found';
        }
      });

      widget.onLocationChanged(fullLocation, coordinates);
    }
  }

  Future<void> _manualGeocode() async {
    if (selectedCountry != null &&
        selectedState != null &&
        selectedDistrict != null) {
      final fullLocation =
          "$selectedDistrict, $selectedState, $selectedCountry";

      setState(() {
        _isGeocoding = true;
        _geocodingStatus = 'Searching online...';
      });

      final coordinates = await GeocodingService.geocodeAddress(fullLocation);

      setState(() {
        _isGeocoding = false;
        _coordinates = coordinates;
        if (coordinates != null) {
          _geocodingStatus =
              '✅ Coordinates found! Lat: ${coordinates['latitude'].toStringAsFixed(6)}, Lon: ${coordinates['longitude'].toStringAsFixed(6)}';
        } else {
          _geocodingStatus =
              '❌ Could not find coordinates. Please check location.';
        }
      });

      widget.onLocationChanged(fullLocation, coordinates);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdown(
          "Country",
          LocationData.getCountries(),
          selectedCountry,
          (val) {
            setState(() {
              selectedCountry = val;
              selectedState = null;
              selectedDistrict = null;
              _coordinates = null;
              _geocodingStatus = '';
            });
            _notifyLocation();
          },
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          "State",
          selectedCountry != null
              ? LocationData.getStates(selectedCountry!)
              : [],
          selectedState,
          (val) {
            setState(() {
              selectedState = val;
              selectedDistrict = null;
              _coordinates = null;
              _geocodingStatus = '';
            });
            _notifyLocation();
          },
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          "District",
          (selectedCountry != null && selectedState != null)
              ? LocationData.getDistricts(selectedCountry!, selectedState!)
              : [],
          selectedDistrict,
          (val) {
            setState(() {
              selectedDistrict = val;
              _coordinates = null;
              _geocodingStatus = '';
            });
            _notifyLocation();
          },
        ),
        const SizedBox(height: 12),

        // Geocoding Status
        if (_geocodingStatus.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _geocodingStatus.contains('✅')
                  ? Colors.green.shade50
                  : _geocodingStatus.contains('❌')
                  ? Colors.red.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _geocodingStatus.contains('✅')
                      ? Icons.check_circle
                      : _geocodingStatus.contains('❌')
                      ? Icons.error
                      : Icons.info,
                  size: 16,
                  color: _geocodingStatus.contains('✅')
                      ? Colors.green
                      : _geocodingStatus.contains('❌')
                      ? Colors.red
                      : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _geocodingStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _geocodingStatus.contains('✅')
                          ? Colors.green
                          : _geocodingStatus.contains('❌')
                          ? Colors.red
                          : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Manual Geocode Button
        if (selectedDistrict != null && _coordinates == null && !_isGeocoding)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: _manualGeocode,
              icon: const Icon(Icons.gps_fixed, size: 16),
              label: const Text("Find Coordinates"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),

        if (_isGeocoding)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        // Coordinates Preview
        if (_coordinates != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📍 Coordinates Found:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Latitude: ${_coordinates!['latitude'].toStringAsFixed(6)}",
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  "Longitude: ${_coordinates!['longitude'].toStringAsFixed(6)}",
                  style: const TextStyle(fontSize: 11),
                ),
                if (_coordinates!['city'] != null)
                  Text(
                    "City: ${_coordinates!['city']}",
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: items.isEmpty
          ? null
          : items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
      onChanged: items.isEmpty ? null : onChanged,
      validator: (value) => value == null ? "$label is required" : null,
      hint: items.isEmpty ? Text("Select $label first") : null,
    );
  }
}
