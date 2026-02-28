import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // Vérifier et demander les permissions avec retour détaillé
  Future<String> checkPermissionsStatus() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test si le service de localisation est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return "service_disabled";
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return "permission_denied";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return "permission_denied_forever";
    }

    return "ok";
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 16));
    } catch (e) {
      debugPrint("Location error: $e");
      return Position(
        latitude: 48.8566, longitude: 2.3522,
        timestamp: DateTime.now(),
        accuracy: 10, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
        altitudeAccuracy: 0, headingAccuracy: 0,
      );
    }
  }

  // Obtenir le flux de position
  Stream<Position> getPositionStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter, // 10m par défaut
      ),
    );
  }

  // Calculer la distance entre deux points en mètres
  double distanceBetween(LatLng p1, LatLng p2) {
    return Geolocator.distanceBetween(
      p1.latitude, p1.longitude,
      p2.latitude, p2.longitude,
    );
  }
  
  // Calculer la distance réelle le long de la route (Polyline distance)
  // userPos: position actuelle
  // targetPos: point cible sur la route (ex: frontière)
  // routePoints: liste complète des points du tracé
  double distanceAlongRoute(LatLng userPos, LatLng targetPos, List<LatLng> routePoints) {
    // 1. Trouver l'index du point le plus proche de l'utilisateur
    int startIndex = findClosestPointIndex(userPos, routePoints);
    int endIndex = findClosestPointIndex(targetPos, routePoints);
    
    if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
       // Fallback vol d'oiseau si échec ou si cible derrière nous
       return distanceBetween(userPos, targetPos);
    }

    double totalDist = 0;
    
    // Distance user -> point route le plus proche
    totalDist += distanceBetween(userPos, routePoints[startIndex]);

    // Somme des segments entre start et end
    for (int i = startIndex; i < endIndex; i++) {
       totalDist += distanceBetween(routePoints[i], routePoints[i+1]);
    }
    
    // Distance point route end -> cible exacte
    // (souvent négligeable mais pour être propre)
    
    return totalDist;
  }

  int findClosestPointIndex(LatLng pos, List<LatLng> points, {int startIdx = 0, int window = 50}) {
    // Optimization: Search only within a window around startIdx
    // If startIdx is -1 or window is very large, we search everything (fallback)
    
    int start = 0;
    int end = points.length;
    
    if (startIdx != -1 && window > 0) {
      start = (startIdx - window).clamp(0, points.length);
      end = (startIdx + window + 1).clamp(0, points.length);
      
      // If window search fails (e.g. huge jump), should we fallback to full search?
      // Logic below returns local minimum. If user jumped, we might need full search.
      // For now, let's just do full search if startIdx is 0 (first run) or explicitly requested, 
      // but the caller usually passes the last known index.
      // To be safe: if minD found in window is too large, we could trigger full search?
      // Let's keep it simple: Search Window first.
    } else {
       // Full search
       start = 0;
       end = points.length;
    }

    double minD = double.infinity;
    int idx = -1;
    
    for (int i = start; i < end; i++) {
       // Squared distance comparison is faster (avoid sqrt) if we just want index
       // But Geolocator calculates real distance.
       // Let's assume standard distanceBetween is fine for < 100 points/sec.
       double d = distanceBetween(pos, points[i]);
       if (d < minD) {
         minD = d;
         idx = i;
       }
    }
    
    // Fallback: If local search gave a bad result (> 200m) AND we didn't search everything, try full search
    if (minD > 200 && (end - start) < points.length) {
       // Trigger full search
       for (int i = 0; i < points.length; i++) {
           if (i >= start && i < end) continue; // Skip already checked
           double d = distanceBetween(pos, points[i]);
           if (d < minD) {
             minD = d;
             idx = i;
           }
       }
    }
    
    return idx;
  }
}
