import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';

class RouteService {
  final http.Client _client = http.Client();

  // Calculer plusieurs routes avec alternatives
  Future<List<RouteInfo>> calculateRoutes(LatLng start, LatLng destination) async {
    List<RouteInfo> allRoutes = [];
    
    try {
      // On lance les 3 types de recherche en parallèle
      // On utilise une petite fonction helper pour ne pas tout bloquer si une requête échoue
      Future<List<RouteInfo>> safeAutoroute() async {
        try {
          return await _fetchOSRMRoutes(start, destination, labelPrefix: "Autoroute");
        } catch (e) {
          print("Erreur Autoroute: $e");
          return [];
        }
      }

      final results = await Future.wait([
        safeAutoroute(),
        _safeFetchOSRMRoutes(start, destination, labelPrefix: "Sans Péage", alternatives: false),
        _safeFetchOSRMRoutes(start, destination, labelPrefix: "Nationale", alternatives: false),
      ]);

      // Fusionner les résultats en évitant les doublons
      // 1. Autoroutes
      allRoutes.addAll(results[0]);
      
      // 2. Sans péage
      for (var route in results[1]) {
        if (_isDifferentRoute(route, allRoutes)) {
          allRoutes.add(route);
        }
      }
      
      // 3. Nationales
      for (var route in results[2]) {
        if (_isDifferentRoute(route, allRoutes)) {
          allRoutes.add(route);
        }
      }

      // Si vraiment rien n'a été trouvé
      if (allRoutes.isEmpty) {
        print("Aucun itinéraire trouvé.");
      }
      
    } catch (e) {
      print("Erreur critique calcul routes: $e");
    }
    
    return allRoutes;
  }
  // Wrapper safe pour éviter de bloquer tout le processus
  Future<List<RouteInfo>> _safeFetchOSRMRoutes(
    LatLng start, 
    LatLng dest, {
    String labelPrefix = "",
    bool alternatives = true,
  }) async {
    try {
      return await _fetchOSRMRoutes(start, dest, labelPrefix: labelPrefix, alternatives: alternatives);
    } catch (e) {
      print("Erreur OSRM ($labelPrefix): $e");
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

  // Fetch routes depuis OSRM
  Future<List<RouteInfo>> _fetchOSRMRoutes(
    LatLng start, 
    LatLng dest, {
    String labelPrefix = "",
    bool alternatives = true,
  }) async {
    final stopWatch = Stopwatch()..start();
    // NOTE: On retire 'excludeType' car le serveur public OSRM retourne souvent 400 si on l'utilise.
    String urlString = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson&steps=true&alternatives=$alternatives';
    
    print("OSRM URL ($labelPrefix): $urlString");

    final response = await _client.get(
      Uri.parse(urlString), 
      headers: {'User-Agent': 'com.alihirlak.gpsfrontiere'}
    ).timeout(const Duration(seconds: 8));
    
    stopWatch.stop();
    print("OSRM DONE ($labelPrefix): ${stopWatch.elapsedMilliseconds}ms");

    if (response.statusCode != 200) {
      throw Exception("Erreur OSRM (${response.statusCode})");
    }

    final data = json.decode(response.body);
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      return [];
    }

    List<RouteInfo> routes = [];
    int routeIndex = 1;
    
    for (var routeData in data['routes']) {
      final geometry = routeData['geometry']['coordinates'] as List;
      final double duration = (routeData['duration'] as num).toDouble();
      final double distance = (routeData['distance'] as num).toDouble();

      List<LatLng> points = geometry.map((coord) {
        return LatLng(coord[1].toDouble(), coord[0].toDouble());
      }).toList();

      // Parsing Steps
      List<RouteStep> steps = [];
      if (routeData['legs'] != null && routeData['legs'].isNotEmpty) {
        final legs = routeData['legs'][0];
        if (legs['steps'] != null) {
          for (var step in legs['steps']) {
            final maneuver = step['maneuver'] ?? {};
            final location = maneuver['location'] ?? [0, 0];
            
            // OSRM peut fournir une instruction complète
            String instr = maneuver['instruction'] ?? "";
            
            // Si l'instruction est vide, on la construit manuellement
            if (instr.isEmpty) {
               final String type = maneuver['type'] ?? "drive";
               final String mod = maneuver['modifier'] ?? "";
               final String name = step['name'] ?? "";
               instr = "$type $mod ${name.isNotEmpty ? 'sur $name' : ''}";
            }

            steps.add(RouteStep(
              instruction: instr, 
              name: step['name'] ?? "",
              distance: (step['distance'] as num).toDouble(),
              duration: (step['duration'] as num).toDouble(),
              maneuverType: maneuver['type'] ?? "move",
              maneuverModifier: maneuver['modifier'] ?? "",
              location: LatLng(location[1].toDouble(), location[0].toDouble())
            ));
          }
        }
      }

      // Speed Limits
      List<int>? speeds;
      if (routeData['legs'] != null && routeData['legs'].isNotEmpty) {
        final annotation = routeData['legs'][0]['annotation'];
        if (annotation != null && annotation['speed'] != null) {
          speeds = [];
          for (var s in (annotation['speed'] as List)) {
            speeds.add(s == null ? 0 : (s is num ? s.round() : 0));
          }
        }
      }

      // Générer label
      String label;
      if (routeIndex == 1) {
        label = labelPrefix;
      } else {
        final firstRoute = routes.first;
        final timeDiff = duration - firstRoute.duration;
        final distDiff = distance - firstRoute.distance;
        
        if (timeDiff < 60) {
          label = "$labelPrefix $routeIndex";
        } else if (distDiff < 0) {
          label = "$labelPrefix $routeIndex (plus courte)";
        } else {
          label = "$labelPrefix $routeIndex (+${(timeDiff / 60).round()} min)";
        }
      }

      routes.add(RouteInfo(
        points: points,
        duration: duration,
        distance: distance,
        label: label,
        countries: ["Chargement..."], 
        hasEUExit: false, 
        distanceToBorder: null,
        speedLimits: speeds,
        steps: steps,
      ));
      
      routeIndex++;
    }

    return routes;
  }

  // Enrichir les routes avec les pays (à appeler après)
  Future<void> enrichRouteWithCountries(RouteInfo route) async {
    // Cette fonction sera implémentée plus tard si nécessaire
    // Pour l'instant on garde la logique dans main.dart
  }
}
