import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
    print("COUNTRY: Fetching ${samples.length} points sequentially...");
    String currentCode = "";
    
    for (int i = 0; i < samples.length; i++) {
      String code = await _getCountryCode(samples[i]);
      if (code != "?" && code != currentCode) {
        segments.add(CountrySegment(code, samples[i]));
        currentCode = code;
      }
      
      // Petit délai si on n'a pas fini et que c'était pas du cache (l'implémentation de _getCountryCode gère le cache)
      // On rajoute un petit sleep de sécurité si on enchaîne les requêtes réelles
      if (i < samples.length - 1) {
         // On pourrait optimiser en ne dormant que si la dernière requête était longue
         await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    
    return segments;
  }

  Future<String> _getCountryCode(LatLng pos) async {
    // Clé de cache grossière (1 decimal place) pour regrouper les zones
    String key = "${pos.latitude.toStringAsFixed(1)},${pos.longitude.toStringAsFixed(1)}";
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=3'
      );
      
      final response = await _client.get(
        url, 
        headers: {'User-Agent': 'com.alihirlak.gpsfrontiere'}
      ).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String countryCode = data['address']['country_code'] ?? "?";
        countryCode = countryCode.toUpperCase();
        
        // Convertir en drapeau (emoji) ? Ou juste garder le code.
        // On retourne le code ISO (ex: FR, DE, TR)
        _cache[key] = countryCode;
        return countryCode;
      }
    } catch (e) {
      print("Erreur country reverse: $e");
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
