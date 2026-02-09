import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';

class RouteService {
  final http.Client _client = http.Client();
  static const String _proxyUrl = 'http://127.0.0.1:8001/api.php';

  // Calculer plusieurs routes avec alternatives
  Future<List<RouteInfo>> calculateRoutes(LatLng start, LatLng destination) async {
    List<RouteInfo> allRoutes = [];
    
    try {
      // 1. Chercher le trajet "Autoroute"
      final autoroutes = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Autoroute", profile: "auto");
      if (autoroutes.isNotEmpty) {
        allRoutes.add(autoroutes.first);
      }
      
      // 2. Chercher le trajet "Nationale" (en réduisant le poids des autoroutes)
      final nationales = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Nationale", profile: "auto", avoidHighways: true);
      if (nationales.isNotEmpty) {
        if (_isDifferentRoute(nationales.first, allRoutes)) {
          allRoutes.add(nationales.first);
        }
      }

      // 3. Optionnel: Sans Péage
      final sansPeage = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Sans Péage", profile: "auto", avoidTolls: true);
      if (sansPeage.isNotEmpty) {
        if (_isDifferentRoute(sansPeage.first, allRoutes)) {
          allRoutes.add(sansPeage.first);
        }
      }
    } catch (e) {
      print("Erreur critique calcul routes Valhalla: $e");
    }
    
    return allRoutes;
  }
  // Wrapper safe pour Valhalla
  Future<List<RouteInfo>> _safeFetchValhallaRoutes(
    LatLng start, 
    LatLng dest, {
    String labelPrefix = "",
    String profile = "auto",
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    try {
      return await _fetchValhallaRoutes(
        start, dest, 
        labelPrefix: labelPrefix, 
        profile: profile,
        avoidHighways: avoidHighways,
        avoidTolls: avoidTolls,
      );
    } catch (e) {
      print("Erreur Valhalla ($labelPrefix): $e");
      return [];
    }
  }

  // Vérifier si une route est différente des routes existantes
  bool _isDifferentRoute(RouteInfo route, List<RouteInfo> existingRoutes) {
    for (var existing in existingRoutes) {
      if ((route.distance - existing.distance).abs() < 1000 && 
          (route.duration - existing.duration).abs() < 120) {
        return false;
      }
    }
    return true;
  }

  // Fetch routes depuis Valhalla API
  Future<List<RouteInfo>> _fetchValhallaRoutes(
    LatLng start, 
    LatLng dest, {
    String labelPrefix = "",
    String profile = "auto",
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    final stopWatch = Stopwatch()..start();
    
    final Map<String, dynamic> jsonPayload = {
      "locations": [
        {"lat": start.latitude, "lon": start.longitude},
        {"lat": dest.latitude, "lon": dest.longitude}
      ],
      "costing": profile,
      "costing_options": {
        profile: {
          if (avoidHighways) "use_highways": 0.0,
          if (avoidTolls) "use_tolls": 0.0,
        }
      },
      "shape_format": "polyline6",
      "units": "kilometers",
      "format": "json",
      "id": labelPrefix
    };

    final String urlString = _proxyUrl;
    

    final response = await _client.post(
      Uri.parse(urlString),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'action': 'route_proxy',
        'payload': jsonPayload
      }),
    ).timeout(const Duration(seconds: 15));
    

    final data = json.decode(response.body);
    if (data['trip'] == null || data['trip']['legs'] == null) {
      print("Valhalla Error: No trip or legs in response");
      return [];
    }

    final trip = data['trip'];
    final legs = trip['legs'] as List;
    
    List<LatLng> allPoints = [];
    List<RouteStep> allSteps = [];
    List<int> allSpeedLimits = [];

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final String? shape = leg['shape'];
      if (shape == null || shape.isEmpty) continue;
      

      // Décodage de la polyline avec indice de position pour auto-détection précision
      final List<LatLng> decodedPoints = _decodePolyline(shape, hint: start);
      allPoints.addAll(decodedPoints);

      // Parsing Maneuvers (Steps)
      if (leg['maneuvers'] != null) {
        for (var maneuver in leg['maneuvers']) {
          final int startIdx = maneuver['begin_shape_index'] ?? 0;
          final String instr = maneuver['instruction'] ?? "";
          
          allSteps.add(RouteStep(
            instruction: instr,
            name: maneuver['street_names'] != null ? (maneuver['street_names'] as List).join(", ") : "",
            distance: (maneuver['length'] as num).toDouble() * 1000, 
            duration: (maneuver['time'] as num).toDouble(),
            maneuverType: maneuver['type']?.toString() ?? "move",
            maneuverModifier: "", 
            location: decodedPoints[startIdx < decodedPoints.length ? startIdx : 0],
          ));
        }
      }
    }

    // Extraction des limites de vitesse depuis les manoeuvres
    allSpeedLimits = List.filled(allPoints.length, 0);
    for (var leg in legs) {
      if (leg['maneuvers'] != null) {
        for (var maneuver in leg['maneuvers']) {
          final int startIdx = maneuver['begin_shape_index'] ?? 0;
          final int? limit = maneuver['speed_limit'] != null ? (maneuver['speed_limit'] as num).round() : null;
          if (limit != null && limit > 0) {
            for (int i = startIdx; i < allPoints.length; i++) {
              allSpeedLimits[i] = limit;
            }
          }
        }
      }
    }


    return [
      RouteInfo(
        points: allPoints,
        duration: (trip['summary']['time'] as num).toDouble(),
        distance: (trip['summary']['length'] as num).toDouble() * 1000,
        label: labelPrefix,
        speedLimits: allSpeedLimits,
        steps: allSteps,
      )
    ];
  }

  // Décodeur Polyline avec détection de précision auto (1e5 ou 1e6)
  List<LatLng> _decodePolyline(dynamic encoded, {required LatLng? hint}) {
    if (encoded == null) return [];
    
    // Si déjà une liste (Valhalla peut parfois retourner les points en clair)
    if (encoded is List) {
      return encoded.map<LatLng>((p) {
        if (p is List && p.length >= 2) {
          return LatLng(p[0].toDouble(), p[1].toDouble());
        } else if (p is Map && p.containsKey('lat') && p.containsKey('lon')) {
          return LatLng(p['lat'].toDouble(), p['lon'].toDouble());
        }
        return const LatLng(0, 0);
      }).where((p) => p.latitude != 0).toList();
    }

    if (encoded is! String) return [];

    // On essaie d'abord 1e6 (Valhalla default)
    List<LatLng> points = _decodeWithPrecision(encoded, 1e6);
    
    // Si on a un point de référence (hint) et que le premier point est trop loin,
    // ou si on n'a aucun point valide, on tente 1e5.
    if (hint != null && points.isNotEmpty) {
      final d = _calculateSimpleDist(hint, points.first);
      if (d > 5.0) { // Si > 5 degrés de différence, probabilité de précision 1e5
        points = _decodeWithPrecision(encoded, 1e5);
      }
    } else if (points.isEmpty) {
      points = _decodeWithPrecision(encoded, 1e5);
    }
    
    return points;
  }

  List<LatLng> _decodeWithPrecision(String encoded, double precision) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 31) << shift;
        shift += 5;
      } while (b >= 32);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)).toSigned(32);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 31) << shift;
        shift += 5;
      } while (b >= 32);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)).toSigned(32);
      lng += dlng;

      final double pLat = lat / precision;
      final double pLng = lng / precision;
      
      if (pLat >= -90.0 && pLat <= 90.0 && pLng >= -180.0 && pLng <= 180.0) {
        points.add(LatLng(pLat, pLng));
      } else {
        // Stop on drift
        break;
      }
    }
    return points;
  }

  double _calculateSimpleDist(LatLng p1, LatLng p2) {
    return (p1.latitude - p2.latitude).abs() + (p1.longitude - p2.longitude).abs();
  }

  // Enrichir les routes avec les pays (à appeler après)
  Future<void> enrichRouteWithCountries(RouteInfo route) async {
    // Cette fonction sera implémentée plus tard si nécessaire
    // Pour l'instant on garde la logique dans main.dart
  }
}
