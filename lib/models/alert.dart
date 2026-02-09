import 'package:latlong2/latlong.dart';

enum AlertType {
  police,
  accident,
  radar,
  travaux,
  danger,
  embouteillage,
}

class Alert {
  final String id;
  final AlertType type;
  final LatLng position;
  final DateTime timestamp;
  final String? description;
  final int upvotes;
  final int downvotes;

  Alert({
    required this.id,
    required this.type,
    required this.position,
    required this.timestamp,
    this.description,
    this.upvotes = 0,
    this.downvotes = 0,
  });

  int get score => upvotes - downvotes;

  // Vérifier si l'alerte est expirée (> 2h)
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours >= 2;
  }

  // Convertir en Map pour le stockage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'upvotes': upvotes,
      'downvotes': downvotes,
    };
  }

  // Créer depuis Map
  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      type: AlertType.values[json['type']],
      position: LatLng(json['latitude'], json['longitude']),
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'],
      upvotes: json['upvotes'] ?? 0,
      downvotes: json['downvotes'] ?? 0,
    );
  }

  // Obtenir l'icône selon le type
  String get icon {
    switch (type) {
      case AlertType.police:
        return '👮';
      case AlertType.accident:
        return '🚗';
      case AlertType.radar:
        return '📷';
      case AlertType.travaux:
        return '🚧';
      case AlertType.danger:
        return '⚠️';
      case AlertType.embouteillage:
        return '🚦';
    }
  }

  // Obtenir le label selon le type
  String get label {
    switch (type) {
      case AlertType.police:
        return 'Police';
      case AlertType.accident:
        return 'Accident';
      case AlertType.radar:
        return 'Radar';
      case AlertType.travaux:
        return 'Travaux';
      case AlertType.danger:
        return 'Danger';
      case AlertType.embouteillage:
        return 'Embouteillage';
    }
  }

  // Obtenir la couleur selon le type
  String get colorHex {
    switch (type) {
      case AlertType.police:
        return '#3B82F6'; // Bleu
      case AlertType.accident:
        return '#EF4444'; // Rouge
      case AlertType.radar:
        return '#F59E0B'; // Orange
      case AlertType.travaux:
        return '#F59E0B'; // Orange
      case AlertType.danger:
        return '#EF4444'; // Rouge
      case AlertType.embouteillage:
        return '#EF4444'; // Rouge
    }
  }
}
