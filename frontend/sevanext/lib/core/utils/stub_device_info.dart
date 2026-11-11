// lib/core/utils/stub_device_info.dart
// Stub implementation for web platform

class DeviceInfoPlugin {
  Future<AndroidDeviceInfo> get androidInfo async => AndroidDeviceInfo();
  Future<IosDeviceInfo> get iosInfo async => IosDeviceInfo();
}

class AndroidDeviceInfo {
  String get manufacturer => 'Web';
  String get model => 'Browser';
  String get version => '';
  String get id => '';
  String get serialNumber => '';
}

class IosDeviceInfo {
  String get name => 'Web';
  String get model => 'Browser';
  String get systemVersion => '';
  String get identifierForVendor => '';
}
