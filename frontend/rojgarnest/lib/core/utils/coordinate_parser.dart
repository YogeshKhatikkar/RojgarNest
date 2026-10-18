// lib/core/utils/coordinate_parser.dart
// Complete coordinate parser - NO EMPTY CATCH BLOCKS

import 'dart:math';

class CoordinateParser {
  static const double earthRadiusMeters = 6371000;

  /// Parse DMS format: 41°24'12.2"N 2°10'26.5"E
  static List<double> parseDMS(String dmsString) {
    final pattern = RegExp(
      r'(\d+)°(\d+)′?(\d+(?:\.\d+)?)?"?([NS])\s+(\d+)°(\d+)′?(\d+(?:\.\d+)?)?"?([EW])',
    );

    final match = pattern.firstMatch(dmsString.trim());
    if (match == null) {
      throw FormatException('Invalid DMS format: $dmsString');
    }

    final latDeg = int.parse(match.group(1)!);
    final latMin = int.parse(match.group(2)!);
    final latSec = double.parse(match.group(3)!);
    final latDir = match.group(4)!;

    final lonDeg = int.parse(match.group(5)!);
    final lonMin = int.parse(match.group(6)!);
    final lonSec = double.parse(match.group(7)!);
    final lonDir = match.group(8)!;

    double latitude = latDeg + latMin / 60 + latSec / 3600;
    if (latDir == 'S') latitude = -latitude;

    double longitude = lonDeg + lonMin / 60 + lonSec / 3600;
    if (lonDir == 'W') longitude = -longitude;

    return [latitude, longitude];
  }

  /// Parse DMM format: 41 24.2028, 2 10.4418
  static List<double> parseDMM(String dmmString) {
    final pattern = RegExp(
      r'(\d+)\s+(\d+(?:\.\d+)?)\s*[, ]\s*(\d+)\s+(\d+(?:\.\d+)?)',
    );
    final match = pattern.firstMatch(dmmString.trim());

    if (match == null) {
      throw FormatException('Invalid DMM format: $dmmString');
    }

    final latDeg = int.parse(match.group(1)!);
    final latMin = double.parse(match.group(2)!);
    final lonDeg = int.parse(match.group(3)!);
    final lonMin = double.parse(match.group(4)!);

    double latitude = latDeg + latMin / 60;
    double longitude = lonDeg + lonMin / 60;

    final upper = dmmString.toUpperCase();
    if (upper.contains('S')) latitude = -latitude.abs();
    if (upper.contains('W')) longitude = -longitude.abs();

    return [latitude, longitude];
  }

  /// Parse DD format: 41.40338, 2.17403
  static List<double> parseDD(String ddString) {
    final parts = ddString.trim().split(RegExp(r'[ ,]+'));
    if (parts.length != 2) {
      throw FormatException('Invalid DD format: $ddString');
    }

    final latitude = double.parse(parts[0]);
    final longitude = double.parse(parts[1]);

    return [latitude, longitude];
  }

  /// Parse any coordinate format
  static List<double> parseAny(String coordinateString) {
    final trimmed = coordinateString.trim();

    // Try DD first
    try {
      return parseDD(trimmed);
    } on FormatException {
      // Not DD format, continue to next format
    } catch (e) {
      // Other error, continue to next format
    }

    // Try DMS (has degree symbol)
    if (trimmed.contains('°')) {
      try {
        return parseDMS(trimmed);
      } on FormatException {
        // Not DMS format, continue to next format
      } catch (e) {
        // Other error, continue to next format
      }
    }

    // Try DMM (space separated numbers)
    if (RegExp(
      r'\d+\s+\d+(?:\.\d+)?\s*[, ]\s*\d+\s+\d+(?:\.\d+)?',
    ).hasMatch(trimmed)) {
      try {
        return parseDMM(trimmed);
      } on FormatException {
        // Not DMM format, continue to next format
      } catch (e) {
        // Other error, continue to next format
      }
    }

    throw FormatException('Unsupported coordinate format: $coordinateString');
  }

  /// Convert decimal degrees to DMS format
  static String toDMS(double latitude, double longitude) {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lonDir = longitude >= 0 ? 'E' : 'W';

    final latAbs = latitude.abs();
    final lonAbs = longitude.abs();

    final latDeg = latAbs.floor();
    final latMin = ((latAbs - latDeg) * 60).floor();
    final latSec = ((latAbs - latDeg - latMin / 60) * 3600);

    final lonDeg = lonAbs.floor();
    final lonMin = ((lonAbs - lonDeg) * 60).floor();
    final lonSec = ((lonAbs - lonDeg - lonMin / 60) * 3600);

    return '$latDeg°${latMin.toString().padLeft(2, '0')}\'${latSec.toStringAsFixed(1)}"$latDir $lonDeg°${lonMin.toString().padLeft(2, '0')}\'${lonSec.toStringAsFixed(1)}"$lonDir';
  }

  /// Convert decimal degrees to DMM format
  static String toDMM(double latitude, double longitude) {
    final latAbs = latitude.abs();
    final lonAbs = longitude.abs();

    final latDeg = latAbs.floor();
    final latMin = (latAbs - latDeg) * 60;

    final lonDeg = lonAbs.floor();
    final lonMin = (lonAbs - lonDeg) * 60;

    return '$latDeg ${latMin.toStringAsFixed(4)}, $lonDeg ${lonMin.toStringAsFixed(4)}';
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final deltaLat = _toRadians(lat2 - lat1);
    final deltaLon = _toRadians(lon2 - lon1);

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}
