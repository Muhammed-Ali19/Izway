import 'package:latlong2/latlong.dart';

class RouteStep {
  final String instruction; 
  final String name; 
  final double distance; 
  final double duration;
  final String maneuverType; // "turn", "new name", "depart"...
  final String maneuverModifier; // "right", "left", "slight right"...
  final LatLng location; 

  RouteStep({
    required this.instruction,
    required this.name,
    required this.distance,
    required this.duration,
    required this.maneuverType,
    required this.maneuverModifier,
    required this.location,
  });

  String get formattedDistance {
    if (distance > 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.round()} m';
  }
}

class RouteInfo {
  final List<LatLng> points;
  final double duration; // en secondes
  final double distance; // en mètres
  final String label;
  
  // Nouveaux champs pour l'International
  final List<String> countries; // Code ISO ou Nom
  final bool hasEUExit; // Si on sort de l'UE
  final double? distanceToBorder; // Prochaine frontière en m
  final List<int>? speedLimits; // Liste des vitesses (si dispo)
  final List<MapEntry<int, String>>? borderCrossings; // Index du point -> Nouveau Pays
  final List<RouteStep> steps; // Instructions de guidage

  RouteInfo({
    required this.points,
    required this.duration,
    required this.distance,
    required this.label,
    this.countries = const [],
    this.hasEUExit = false,
    this.distanceToBorder,
    this.speedLimits,
    this.borderCrossings,
    this.steps = const [],
  });

  String get formattedDuration {
    final int minutes = (duration / 60).round();
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      return '${hours}h ${mins.toString().padLeft(2, '0')}';
    }
    return '${minutes}min';
  }

  String get formattedDistance {
    if (distance > 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.round()} m';
  }
}

class SearchResult {
  final String displayName;
  final double lat;
  final double lon;

  SearchResult(this.displayName, this.lat, this.lon);
}
