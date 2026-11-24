import 'package:flutter/foundation.dart';

class ApiConfig {
  // XAMPP di komputer
  static const String localApi = 'http://localhost/cafe_api';

  // Android Emulator
  static const String emulatorApi = 'http://10.0.2.2/cafe_api';

  // IP komputer yang menjalankan XAMPP
  static const String physicalDeviceApi = 'http://192.168.0.103/cafe_api';

  static const String productionApi = '';

  static String get baseUrl {
    if (kIsWeb) {
      return localApi;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return physicalDeviceApi;
    }

    return localApi;
  }

  static String get loginUrl => '$baseUrl/login.php';
}
