import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../utils/api_config.dart';

class CountrySegment {
  final String countryCode;
  final LatLng startPosition; // Approximate entry point
  CountrySegment(this.countryCode, this.startPosition);
}

class CountryService {
  final http.Client _client = http.Client();
  final Map<String, String> _cache = {};

  // Close client if needed
  void dispose() => _client.close();

  Future<List<CountrySegment>> getCountrySegments(List<LatLng> routePoints) async {
    List<CountrySegment> segments = [];
    
    if (routePoints.isEmpty) return [];

    // 1. Sampling points every ~60-80km
    List<LatLng> samples = [];
    samples.add(routePoints.first);
    
    double lastLat = routePoints.first.latitude;
    double lastLon = routePoints.first.longitude;
    
    for (var point in routePoints) {
      double dist = (point.latitude - lastLat).abs() + (point.longitude - lastLon).abs();
      if (dist > 0.7) { // ~75km
        samples.add(point);
        lastLat = point.latitude;
        lastLon = point.longitude;
      }
    }
    if (samples.last != routePoints.last) samples.add(routePoints.last);

    // 2. Sequential Fetch with delay (to respect Nominatim 1req/s)
    debugPrint("COUNTRY: Fetching ${samples.length} points sequentially via Proxy...");
    String currentCode = "";
    
    for (int i = 0; i < samples.length; i++) {
      String code = await _getCountryCode(samples[i]);
      if (code != "?" && code != currentCode) {
        segments.add(CountrySegment(code, samples[i]));
        currentCode = code;
      }
      
      // Delay to avoid backend spamming OS/Nominatim
      if (i < samples.length - 1) {
         await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    return segments;
  }

  Future<String> _getCountryCode(LatLng pos) async {
    String key = "${pos.latitude.toStringAsFixed(1)},${pos.longitude.toStringAsFixed(1)}";
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'reverse_proxy',
          'lat': pos.latitude,
          'lon': pos.longitude,
        })
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data == null || data['address'] == null) return "?";
        
        String countryCode = data['address']['country_code'] ?? "?";
        countryCode = countryCode.toUpperCase();
        
        _cache[key] = countryCode;
        return countryCode;
      }
    } catch (e) {
      debugPrint("Erreur country reverse (Proxy): $e");
    }
    return "?";
  }

  // Helper pour convertir code ISO en Emoji Drapeau
  String getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return "🌍";
    
    // 0x41 is 'A' mapping to 0x1F1E6
    int flagOffset = 0x1F1E6;
    int asciiOffset = 0x41;
    
    int firstChar = countryCode.codeUnitAt(0) - asciiOffset + flagOffset;
    int secondChar = countryCode.codeUnitAt(1) - asciiOffset + flagOffset;

    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }
}
