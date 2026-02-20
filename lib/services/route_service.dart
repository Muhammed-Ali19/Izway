import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';
import 'direction_translator.dart';
import '../utils/api_config.dart';

class RouteService {
  final http.Client _client = http.Client();
  static final String _proxyUrl = ApiConfig.baseUrl;

  // Calculer plusieurs routes avec alternatives
  Future<List<RouteInfo>> calculateRoutes(LatLng start, LatLng destination) async {
    List<RouteInfo> allRoutes = [];
    
    try {
      final autoroutes = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Autoroute", profile: "auto", alternates: 1);
      for (var r in autoroutes) {
        if (_isDifferentRoute(r, allRoutes)) {
          allRoutes.add(r);
        }
      }
      
      final nationales = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Nationale", profile: "auto", avoidHighways: true);
      for (var r in nationales) {
        if (_isDifferentRoute(r, allRoutes)) {
          allRoutes.add(r);
        }
      }

      final sansPeage = await _safeFetchValhallaRoutes(start, destination, labelPrefix: "Sans Péage", profile: "auto", avoidTolls: true);
      for (var r in sansPeage) {
        if (_isDifferentRoute(r, allRoutes)) {
          allRoutes.add(r);
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
      debugPrint("Valhalla critical error: $e");
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
      debugPrint("Valhalla error ($labelPrefix): $e");
      return [];
    }
  }

  // Vérifier si une route est différente des routes existantes
  bool _isDifferentRoute(RouteInfo route, List<RouteInfo> existingRoutes) {
    for (var existing in existingRoutes) {
      // Si les libellés sont différents (ex: Autoroute vs Nationale), on garde les deux !
      // Cela permet à l'utilisateur de choisir explicitement son mode de transport.
      if (route.label != existing.label) continue;

      // Sinon, on compare la durée et la distance pour éviter les vrais doublons géométriques
      final double timeDiff = (route.duration - existing.duration).abs();
      final double distDiff = (route.distance - existing.distance).abs();
      
      if (timeDiff < 30 && distDiff < 500) {
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


    final response = await _client.post(
      Uri.parse(_proxyUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'action': 'route_proxy',
        'payload': jsonPayload
      }),
    ).timeout(ApiConfig.routeTimeout);
    
    
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
        String code = admin['iso_3166_1'] ?? "??";
        adminIsoCodes.add(code);
      }
      debugPrint("DEBUG RouteService: Found admins: ${adminIsoCodes.join(', ')}");
    } else {
      debugPrint("DEBUG RouteService: NO ADMINS FOUND IN TRIP");
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
               debugPrint("DEBUG RouteService: BORDER CROSSING detected at index ${globalPointIndex + j} to $country");
             }
           }
           lastAdminIndex = currentAdminIndex;
        }
      } else {
        debugPrint("DEBUG RouteService: NO ADMINS ANNOTATION IN LEG");
      }
      
      globalPointIndex += decodedPoints.length;

      if (leg['maneuvers'] != null) {
        for (var maneuver in leg['maneuvers']) {
          final int startIdx = maneuver['begin_shape_index'] ?? 0;
          final String original = maneuver['instruction'] ?? "";
          final String instr = DirectionTranslator.translate(original);
          
          
          allSteps.add(RouteStep(
            instruction: instr,
            name: maneuver['street_names'] != null ? (maneuver['street_names'] as List).join(", ") : "",
            distance: (maneuver['length'] as num).toDouble() * 1000, 
            duration: (maneuver['time'] as num).toDouble(),
            maneuverType: maneuver['type']?.toString() ?? "move",
            maneuverModifier: "", 
            location: decodedPoints[startIdx < decodedPoints.length ? startIdx : 0],
            pointIndex: globalPointIndex - decodedPoints.length + startIdx,
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
      if (pLat >= -90.0 && pLat <= 90.0 && pLng >= -180.0 && pLng <= 180.0) {
        points.add(LatLng(pLat, pLng));
      } else {
        break;
      }
    }
    return points;
  }
}
