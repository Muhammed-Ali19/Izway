import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import '../models/alert.dart';
import '../utils/api_config.dart';

class TrafficService {
  final http.Client _client = http.Client();
  
  // Overpass API URL (OSM)
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  void dispose() => _client.close();

  // Fetch alerts along the entire route (Corridor search)
  Future<List<Alert>> fetchTrafficAlertsForRoute(List<LatLng> routePoints) async {
    // Simplify: instead of complex polygon query, we take bounding box of the whole route
    // IF the route is short (< 200km).
    // If long, we should split. For MVP, let's take a smart sampling.
    
    // Sampling every 50km
    List<Alert> allAlerts = [];
    Set<String> processedIds = {};

    // 1. Calculate simplified points (every ~50km)
    List<LatLng> samples = [];
    if (routePoints.isEmpty) return [];
    
    samples.add(routePoints.first);
    double lastLat = routePoints.first.latitude;
    double lastLon = routePoints.first.longitude;
    
    for (var point in routePoints) {
       double dist = (point.latitude - lastLat).abs() + (point.longitude - lastLon).abs();
       if (dist > 0.5) { // ~50km
          samples.add(point);
          lastLat = point.latitude;
          lastLon = point.longitude;
       }
    }
    samples.add(routePoints.last);

    // 2. Fetch for each sample point (corridor bubbles)
    // To avoid spamming API, we do this sequentially or unlimited parallel? 
    // Parallel limited to 5 concurrent reqs
    
    // Note: Overpass has rate limits.
    // Optimization: Construct ONE big query with multiple bboxes union.
    
    String unionQuery = "[out:json][timeout:25];(";
    
    for (var center in samples) {
       double r = 0.3; // ~30km radius box
       String bbox = '${center.latitude - r},${center.longitude - r},${center.latitude + r},${center.longitude + r}';
       unionQuery += 'node["highway"="speed_camera"]($bbox);';
       unionQuery += 'node["man_made"="monitoring_station"]["monitoring:traffic"]($bbox);';
    }
    
    unionQuery += "); out body;";

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': unionQuery},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];

        for (var e in elements) {
           String id = "osm_${e['id']}";
           if (!processedIds.contains(id)) {
              processedIds.add(id);
              allAlerts.add(Alert(
                id: id,
                type: AlertType.radar,
                position: LatLng(e['lat'], e['lon']),
                timestamp: DateTime.now(),
                description: "Radar Fixe (OSM)",
              ));
           }
        }
      }
    } catch (e) {
      debugPrint("Route Overpass error: $e");
    }

    return allAlerts;
  }

  // Keep old method for compatibility/single point check
  Future<List<Alert>> fetchTrafficAlerts(LatLng center, double radiusKm) async {
     return _fetchOSMRadars(center, radiusKm);
  }

  Future<List<Alert>> _fetchOSMRadars(LatLng center, double radiusKm) async {
    // Calcul de la Bounding Box aprx
    double latDelta = radiusKm / 111.0;
    double lonDelta = radiusKm / (111.0 * cos(center.latitude * 0.01745).abs());
    
    String bbox = '${center.latitude - latDelta},${center.longitude - lonDelta},${center.latitude + latDelta},${center.longitude + lonDelta}';

    // Query Overpass: nodes with "highway=speed_camera" or "man_made=monitoring_station"
    // Query Overpass: nodes with "highway=speed_camera" or "man_made=monitoring_station"
    String query = """
      [out:json][timeout:15];
      (
        node["highway"="speed_camera"]($bbox);
        node["man_made"="monitoring_station"]["monitoring:traffic"]($bbox);
      );
      out body;
    """;

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];

        return elements.map((e) => Alert(
          id: "osm_${e['id']}",
          type: AlertType.radar,
          position: LatLng(e['lat'], e['lon']),
          timestamp: DateTime.now(),
          description: "Radar Fixe (OSM)",
        )).toList();
      }
    } catch (e) {
      debugPrint("Overpass Radar error: $e");
    }
    
    return [];
  }

  // Fetch real-time border wait times from backend proxy
  Future<Map<String, dynamic>?> fetchBorderWait(LatLng position, String name) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_border_wait',
          'lat': position.latitude,
          'lon': position.longitude,
          'name': name,
        })
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("fetchBorderWait error: $e");
    }
    return null;
  }
}
