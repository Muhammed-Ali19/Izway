import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';

class SearchService {
  static const String _baseUrl = 'http://127.0.0.1:8001/api.php';

  // Rechercher des lieux via Nominatim
  Future<List<SearchResult>> searchPlaces(String query, LatLng? currentPosition) async {
    if (query.isEmpty) {
      return [];
    }
    
    // Construire l'URL avec viewbox pour prioriser les résultats proches
    // URL optimisée pour plus de précision et rapidité
    // dedupe=1 évite les doublons, limit=20 pour plus de choix
    String viewBoxStr = "";
    if (currentPosition != null) {
      final lat = currentPosition.latitude;
      final lon = currentPosition.longitude;
      viewBoxStr = '${lon - 2.0},${lat + 2.0},${lon + 2.0},${lat - 2.0}';
    }
    
    final url = Uri.parse(_baseUrl);
    try {
      final response = await http.post(
        url, 
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'action': 'search_proxy',
          'query': query,
          if (viewBoxStr.isNotEmpty) 'viewbox': viewBoxStr
        })
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          final addr = item['address'] ?? {};
          String name = item['display_name'] ?? 'Inconnu';
          
          // Construction plus précise de l'adresse pour l'UI
          if (addr['road'] != null) {
            final house = addr['house_number'] ?? '';
            final road = addr['road'];
            final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb'] ?? '';
            
            if (house.isNotEmpty) {
              name = "$house $road, $city";
            } else {
              name = "$road, $city";
            }
          }

          return SearchResult(
            name.trim(),
            double.parse(item['lat']),
            double.parse(item['lon']),
          );
        }).toList();
      }
    } catch (e) {
      print("Erreur search: $e");
    }
    
    return [];
  }

  // Obtenir le code pays d'une position
  Future<String> getCountryCode(LatLng position) async {
    try {
      final url = Uri.parse(_baseUrl);
      final response = await http.post(
        url, 
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'reverse_proxy',
          'lat': position.latitude,
          'lon': position.longitude
        })
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['address']['country'] ?? "?";
      }
    } catch (e) {
      print("Erreur getCountryCode: $e");
    }
    return "?";
  }
}
