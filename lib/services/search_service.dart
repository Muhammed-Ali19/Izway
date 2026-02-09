import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';

class SearchService {
  // Rechercher des lieux via Nominatim
  Future<List<SearchResult>> searchPlaces(String query, LatLng? currentPosition) async {
    if (query.isEmpty) {
      return [];
    }
    
    // Construire l'URL avec viewbox pour prioriser les résultats proches
    // URL optimisée pour plus de précision et rapidité
    // dedupe=1 évite les doublons, limit=20 pour plus de choix
    String urlString = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=20&addressdetails=1&dedupe=1';
    
    if (currentPosition != null) {
      final lat = currentPosition.latitude;
      final lon = currentPosition.longitude;
      // Viewbox un peu plus serré pour la priorité locale mais sans blocage
      final latDelta = 1.0; 
      final lonDelta = 1.0;
      urlString += '&viewbox=${lon - lonDelta},${lat + latDelta},${lon + lonDelta},${lat - latDelta}';
      urlString += '&bounded=0';
    }
    
    final url = Uri.parse(urlString);
    try {
      final response = await http.get(
        url, 
        headers: {
          'User-Agent': 'com.alihirlak.gpsfrontiere',
          'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
        }
      );
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          // Si c'est une adresse précise, on essaie de garder un nom lisible 
          // mais Nominatim display_name est déjà complet.
          return SearchResult(
            item['display_name'] ?? 'Inconnu',
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
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=3'
      );
      final response = await http.get(
        url, 
        headers: {'User-Agent': 'com.alihirlak.gpsfrontiere'}
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
