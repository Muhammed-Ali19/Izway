import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
      print("Location: Tentative de récupération position...");
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 16));
    } catch (e) {
      print("Location: ERREUR ou TIMEOUT ($e). Utilisation du FALLBACK Paris.");
      // Fallback Position
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

  int findClosestPointIndex(LatLng pos, List<LatLng> points) {
    double minD = double.infinity;
    int idx = -1;
    
    // Optim: chercher seulement dans une fenêtre raisonnable si on suivait l'index précédent
    // Ici version naïve: scan tout
    for (int i = 0; i < points.length; i++) {
       double d = distanceBetween(pos, points[i]);
       if (d < minD) {
         minD = d;
         idx = i;
       }
    }
    
    // Si la distance est trop grande (> 1km), l'utilisateur n'est peut-être pas sur cette route
    if (minD > 1000) return -1;
    return idx;
  }
}
