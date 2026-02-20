import 'package:flutter/foundation.dart';

class ApiConfig {
  // Toggle this to true to force production URL even in debug mode if needed
  static const bool forceProduction = false;

  static const String voiceRssKey = '70ec240377204ef3802821e9d07c2584'; 

  // CONFIGURATION AZURE (QUALITÉ NEURALE - GRATUIT 500k chars/mois)
  static const String azureKey = ''; 
  static const String azureRegion = 'francecentral';

  static const String _prodUrl = 'https://muhammed-ali.fr/web/api.php';
  static const String _devUrl = 'http://127.0.0.1:8001/api.php';

  static String get baseUrl {
    if (forceProduction || kReleaseMode) {
      return _prodUrl;
    }
    return _devUrl;
  }

  // Common headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };

  // Timeout durations
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration searchTimeout = Duration(seconds: 5);
  static const Duration routeTimeout = Duration(seconds: 15);
}
