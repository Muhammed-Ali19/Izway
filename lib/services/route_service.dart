import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';
import 'direction_translator.dart';

class RouteService {
  final http.Client _client = http.Client();
  static const String _proxyUrl = kReleaseMode 
      ? 'https://muhammed-ali.fr/web/api.php' 
      : 'http://127.0.0.1:8001/api.php';

  // Calculer plusieurs routes avec alternatives
  Future<List<RouteInfo>> calculateRoutes(LatLng start, LatLng destination) async {
    List<RouteInfo> allRoutes = [];
    
    try {
      // 1. Chercher le trajet "Autoroute" + 2 Alternatives
      print("DEBUG: Fetching 'Autoroute'...");
      final autoroutes = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Autoroute", profile: "auto", alternates: 2);
      print("DEBUG: 'Autoroute' found: ${autoroutes.length}");
      for (var r in autoroutes) {
        if (_isDifferentRoute(r, allRoutes)) {
          allRoutes.add(r);
          print("DEBUG: Added Autoroute (${r.label}) - ${r.distance}m");
        } else {
          print("DEBUG: Skipped Autoroute (${r.label}) - Duplicate");
        }
      }
      
      // 2. Chercher le trajet "Nationale"
      print("DEBUG: Fetching 'Nationale'...");
      final nationales = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Nationale", profile: "auto", avoidHighways: true);
      print("DEBUG: 'Nationale' found: ${nationales.length}");
      for (var r in nationales) {
        if (_isDifferentRoute(r, allRoutes)) {
          allRoutes.add(r);
           print("DEBUG: Added Nationale (${r.label}) - ${r.distance}m");
        } else {
           print("DEBUG: Skipped Nationale (${r.label}) - Duplicate");
        }
      }

      // 3. Option: Sans Péage
      print("DEBUG: Fetching 'Sans Péage'...");
      final sansPeage = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Sans Péage", profile: "auto", avoidTolls: true);
      print("DEBUG: 'Sans Péage' found: ${sansPeage.length}");
      for (var r in sansPeage) {
        if (_isDifferentRoute(r, allRoutes)) {
          allRoutes.add(r);
          print("DEBUG: Added Sans Péage (${r.label}) - ${r.distance}m");
        } else {
          print("DEBUG: Skipped Sans Péage (${r.label}) - Duplicate");
        }
      }

      // 4. Stratégie "Plus Court" (Shortest)
      // On demande "shortest" en distance, souvent différent de "auto" (plus rapide)
      // print("DEBUG: Fetching 'Plus Court'...");
      // final shortestRoutes = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Plus Court", profile: "auto", costingProfileOverride: "shortest");
      // for (var r in shortestRoutes) {
      //   if (_isDifferentRoute(r, allRoutes)) {
      //     allRoutes.add(r);
      //   }
      // }
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
    int alternates = 0,
    String? costingProfileOverride,
  }) async {
    try {
      return await _fetchValhallaRoutes(
        start, dest, 
        labelPrefix: labelPrefix, 
        profile: costingProfileOverride ?? profile,
        avoidHighways: avoidHighways,
        avoidTolls: avoidTolls,
        alternates: alternates,
      );
    } catch (e) {
      print("Erreur Valhalla ($labelPrefix): $e");
      return [];
    }
  }

  // Vérifier si une route est différente des routes existantes
  bool _isDifferentRoute(RouteInfo route, List<RouteInfo> existingRoutes) {
    for (var existing in existingRoutes) {
      // If the label is different (e.g. Autoroute vs Nationale), we allow it!
      // This ensures the user sees the "Autoroute" option even if it happens to be the same path as "Nationale".
      if (route.label != existing.label) continue;

      // Otherwise, check for geometry/time duplicates
      if ((route.distance - existing.distance).abs() < 1 && 
          (route.duration - existing.duration).abs() < 1) {
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
    int alternates = 0,
  }) async {
    final Map<String, dynamic> jsonPayload = {
      "locations": [
        {"lat": start.latitude, "lon": start.longitude},
        {"lat": dest.latitude, "lon": dest.longitude}
      ],
      "costing": profile,
      "language": "fr",
      "costing_options": {
        profile: {
          // Standard "Autoroute" / "Fastest" should use defaults (usually use_highways=0.5).
          // Forcing 1.0 might have broken it.
          // Only add avoidance if explicitly requested.
          if (avoidHighways) "use_highways": 0.0,
          if (avoidTolls) "use_tolls": 0.0,
          
          "maneuver_penalty": 5.0,
          "country_crossing_penalty": 0.0,
          "country_crossing_cost": 0.0,
        }
      },
      "shape_format": "polyline6",
      "units": "kilometers",
      "format": "json",
      "id": labelPrefix,
      // "alternates": alternates, // Removing alternates to diagnose failure
      "directions_options": {
        "language": "fr",
        "narrative": true
      },
      "annotations": ["admins", "maxspeed"]
    };

    if (kDebugMode) {
      print("DEBUG: Fetching Valhalla Route ($labelPrefix)...");
      print("DEBUG: Payload: ${json.encode(jsonPayload)}");
    }

    final response = await _client.post(
      Uri.parse(_proxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'route_proxy',
        'payload': jsonPayload
      }),
    ).timeout(const Duration(seconds: 15));
    
    if (kDebugMode) {
       print("DEBUG: Response Status ($labelPrefix): ${response.statusCode}");
       // print("DEBUG: Response Body: ${response.body}"); // Too verbose
    }
    
    final data = json.decode(response.body);
    if (data['trip'] == null || data['trip']['legs'] == null) {
      return [];
    }

    final trip = data['trip'];
    List<RouteInfo> results = [];
    
    // Parse main trip
    results.add(_parseValhallaTrip(trip, start, labelPrefix));

    // Parse alternates if any
    if (data['alternates'] != null && data['alternates'] is List) {
      int altIdx = 1;
      for (var altTrip in data['alternates']) {
        results.add(_parseValhallaTrip(altTrip, start, "$labelPrefix (Alt ${altIdx++})"));
      }
    }

    return results;
  }

  RouteInfo _parseValhallaTrip(Map<String, dynamic> trip, LatLng start, String label) {
    final legs = trip['legs'] as List;
    
    List<LatLng> allPoints = [];
    List<RouteStep> allSteps = [];
    List<int> allSpeedLimits = [];
    List<MapEntry<int, String>> borderCrossings = [];
    
    List<String> adminIsoCodes = [];
    if (trip['admins'] != null) {
      for (var admin in trip['admins']) {
        adminIsoCodes.add(admin['iso_3166_1'] ?? "??");
      }
    }

    int globalPointIndex = 0;
    int lastAdminIndex = -1;

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final String? shape = leg['shape'];
      if (shape == null || shape.isEmpty) continue;
      
      final List<LatLng> decodedPoints = _decodePolyline(shape, hint: start);
      allPoints.addAll(decodedPoints);
      
      if (leg['annotation'] != null && leg['annotation']['admins'] != null) {
        final List<dynamic> adminIndices = leg['annotation']['admins'];
        for (int j = 0; j < adminIndices.length && j < decodedPoints.length; j++) {
           int currentAdminIndex = adminIndices[j] as int;
           if (lastAdminIndex != -1 && currentAdminIndex != lastAdminIndex) {
             if (currentAdminIndex < adminIsoCodes.length) {
               String country = adminIsoCodes[currentAdminIndex];
               borderCrossings.add(MapEntry(globalPointIndex + j, country));
             }
           }
           lastAdminIndex = currentAdminIndex;
        }
      }
      
      globalPointIndex += decodedPoints.length;

      if (leg['maneuvers'] != null) {
        for (var maneuver in leg['maneuvers']) {
          final int startIdx = maneuver['begin_shape_index'] ?? 0;
          final String original = maneuver['instruction'] ?? "";
          final String instr = DirectionTranslator.translate(original);
          
          if (kDebugMode) {
             print("DEBUG: [Maneuver] $original -> $instr");
          }
          
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
      
      List<int> legLimits = List.filled(decodedPoints.length, 0);
      if (leg['annotation'] != null && leg['annotation']['maxspeed'] != null) {
         final List<dynamic> speeds = leg['annotation']['maxspeed'];
         for (int j = 0; j < speeds.length && j < decodedPoints.length; j++) {
           legLimits[j] = (speeds[j] as num).toInt();
         }
      }
      allSpeedLimits.addAll(legLimits);
    }
    
    return RouteInfo(
      points: allPoints,
      duration: (trip['summary']['time'] as num).toDouble(),
      distance: (trip['summary']['length'] as num).toDouble() * 1000,
      label: label,
      speedLimits: allSpeedLimits,
      steps: allSteps,
      borderCrossings: borderCrossings,
      countries: adminIsoCodes.where((c) => c != "??").toSet().toList(),
    );
  }

  List<LatLng> _decodePolyline(dynamic encoded, {required LatLng? hint}) {
    if (encoded == null) return [];
    if (encoded is List) {
      return encoded.map<LatLng>((p) {
        if (p is List && p.length >= 2) return LatLng(p[0].toDouble(), p[1].toDouble());
        if (p is Map && p.containsKey('lat') && p.containsKey('lon')) return LatLng(p['lat'].toDouble(), p['lon'].toDouble());
        return const LatLng(0, 0);
      }).where((p) => p.latitude != 0).toList();
    }
    if (encoded is! String) return [];

    List<LatLng> points = _decodeWithPrecision(encoded, 1e6);
    if (hint != null && points.isNotEmpty) {
      final d = (hint.latitude - points.first.latitude).abs() + (hint.longitude - points.first.longitude).abs();
      if (d > 5.0) points = _decodeWithPrecision(encoded, 1e5);
    } else if (points.isEmpty) {
      points = _decodeWithPrecision(encoded, 1e5);
    }
    return points;
  }

  List<LatLng> _decodeWithPrecision(String encoded, double precision) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 31) << shift; shift += 5; } while (b >= 32);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)).toSigned(32);
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 31) << shift; shift += 5; } while (b >= 32);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)).toSigned(32);
      final double pLat = lat / precision, pLng = lng / precision;
      if (pLat >= -90.0 && pLat <= 90.0 && pLng >= -180.0 && pLng <= 180.0) points.add(LatLng(pLat, pLng)); else break;
    }
    return points;
  }
}
