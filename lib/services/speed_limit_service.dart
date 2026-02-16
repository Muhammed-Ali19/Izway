import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SpeedLimitService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  
  // Cache simple pour éviter de spammer l'API
  DateTime? _lastFetch;
  LatLng? _lastPos;
  int? _cachedLimit;
  
  Future<int?> fetchSpeedLimit(LatLng pos) async {
    // 1. Throttling / Caching (Même position < 20m ou < 5 secondes)
    if (_lastPos != null && 
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inSeconds < 5) {
      final dist = const Distance().as(LengthUnit.Meter, _lastPos!, pos);
      if (dist < 20) return _cachedLimit;
    }

    try {
      // 2. Query Overpass (Rayon 15m)
      final String query = """
        [out:json];
        way(around:15, ${pos.latitude}, ${pos.longitude})[maxspeed];
        out tags;
      """;

      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'] != null && (data['elements'] as List).isNotEmpty) {
          // Prendre le premier way avec maxspeed
          for (var el in data['elements']) {
            if (el['tags'] != null && el['tags']['maxspeed'] != null) {
              final val = el['tags']['maxspeed'];
              int? limit = _parseIntLimit(val);
              if (limit != null) {
                _lastFetch = DateTime.now();
                _lastPos = pos;
                _cachedLimit = limit;
                return limit;
              }
            }
          }
        }
      }
    } catch (e) {
      print("SpeedLimitService Error: $e");
    }
    
    return null; // Pas trouvé ou erreur
  }

  int? _parseIntLimit(String raw) {
    if (raw == 'none') return null; // Autobahn illimité ?
    
    // Nettoyage (ex: "50 mph", "FR:urban")
    // Pour la France, FR:urban = 50, FR:rural = 80/90... 
    // Pour l'instant, on gère les chiffres bruts
    
    // Extraction des chiffres
    final RegExp reg = RegExp(r'(\d+)');
    final match = reg.firstMatch(raw);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    
    if (raw == 'FR:urban') return 50;
    if (raw == 'FR:rural') return 80;
    if (raw == 'FR:motorway') return 130;
    
    return null;
  }
}
