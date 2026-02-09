import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../models/alert.dart';

class AlertService {
  static const String _alertsKey = 'alerts';
  static const String _votedAlertsKey = 'voted_alerts';
  static const String _hiddenAlertsKey = 'hidden_alerts';
  
  // Production URL
  static const String _baseUrl = 'https://muhammed-ali.fr/gpsfrontiere/api.php'; 
  
  final List<Alert> _alerts = [];
  final Set<String> _votedIds = {};
  final Set<String> _deletedIds = {}; 
  final Set<String> _hiddenIds = {}; // Blacklist locale (pour cacher radars OSM ou reports supprimés)

  List<Alert> get alerts => _alerts;

  // Charger les alertes depuis le stockage local
  Future<void> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? alertsJson = prefs.getString(_alertsKey);
    
    if (alertsJson != null) {
      final List<dynamic> decoded = json.decode(alertsJson);
      _alerts.clear();
      _alerts.addAll(
        decoded.map((json) => Alert.fromJson(json)).where((alert) => !alert.isExpired)
      );
      
      // Sauvegarder après nettoyage des expirées
      await _saveAlerts();
    }

    // Charger les votes
    final List<String>? votedList = prefs.getStringList(_votedAlertsKey);
    if (votedList != null) {
      _votedIds.addAll(votedList);
    }

    // Charger les IDs cachés
    final List<String>? hiddenList = prefs.getStringList(_hiddenAlertsKey);
    if (hiddenList != null) {
      _hiddenIds.addAll(hiddenList);
    }
  }

  // Sauvegarder les alertes
  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _alerts.map((alert) => alert.toJson()).toList();
    await prefs.setString(_alertsKey, json.encode(jsonList));
  }

  // Ajouter une alerte (API + Local)
  Future<void> addAlert(AlertType type, LatLng position, {String? description}) async {
    final alert = Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      position: position,
      timestamp: DateTime.now(),
      description: description,
    );
    
    // 1. Ajouter localement pour feedback immédiat
    _alerts.add(alert);
    await _saveAlerts();

    // 2. Envoyer au backend (PHP/MySQL)
    try {
      await http.post(
        Uri.parse(_baseUrl), // on appelle api.php direct (le script gère GET/POST)
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': alert.id,
          'type': type.name, // 'police', 'accident'
          'latitude': position.latitude,
          'longitude': position.longitude,
          'description': description,
          'user_id': 'user_flutter' 
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print("Erreur envoi PHP: $e");
      // On garde en local si échec
    }

  }

  // Supprimer une alerte
  Future<Map<String, dynamic>> removeAlert(String id) async {
    print("ALERT: Tentative de suppression de $id...");
    
    // 1. Marquer comme caché/supprimé localement définitivement
    _hiddenIds.add(id);
    _deletedIds.add(id); // Protection immédiate pour la sync
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenAlertsKey, _hiddenIds.toList());
    
    // 2. Local
    _alerts.removeWhere((alert) => alert.id == id);
    await _saveAlerts();

    // 3. API (Seulement si ce n'est pas un radar OSM qui n'est pas en BDD)
    if (id.startsWith('osm_')) {
      return {"success": true, "message": "Radar OSM masqué localement"};
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'delete_alert',
          'id': id,
        }),
      ).timeout(const Duration(seconds: 5));
      
      print("Suppression API ID: $id - Status: ${response.statusCode}");
      print("Réponse API (Brute): ${response.body}");
      
      final data = json.decode(response.body);
      if (data['success'] == true) {
        // En plus du blacklist, on vire de la liste locale active
        _alerts.removeWhere((a) => a.id == id);
        await _saveAlerts();
      }
      return data;
    } catch (e) {
      print("Erreur critique suppression PHP: $e");
      return {"success": false, "error": e.toString()};
    }
  }

  // Nettoyer les alertes expirées
  Future<void> cleanExpiredAlerts() async {
    _alerts.removeWhere((alert) => alert.isExpired);
    await _saveAlerts();
  }

  // Obtenir les alertes proches (et sync avec API si possible)
  Future<List<Alert>> getAlertsNearby(LatLng position, double radiusMeters) async {
    // Attendre la synchro pour avoir les données fraîches
    await _syncWithBackendIfNeeded(position);

    final Distance distance = Distance();
    return _alerts.where((alert) {
      final dist = distance.as(
        LengthUnit.Meter,
        alert.position,
        position,
      );
      return dist <= radiusMeters && !alert.isExpired;
    }).toList();
  }

  // Voter pour une alerte (API)
  Future<void> voteAlert(String id, bool up) async {
    markAsVoted(id);
    try {
      await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'vote',
          'id': id,
          'type': up ? 'up' : 'down'
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print("Erreur vote: $e");
    }
  }

  bool isVoted(String id) => _votedIds.contains(id);
  bool isHidden(String id) => _hiddenIds.contains(id);

  Future<void> markAsVoted(String id) async {
    _votedIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_votedAlertsKey, _votedIds.toList());
  }

  Future<void> _syncWithBackendIfNeeded(LatLng pos) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get&lat=${pos.latitude}&lon=${pos.longitude}')
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
         final dynamic data = json.decode(response.body);
         
         if (data is List) {
            print("Fetched ${data.length} alerts from backend");
            // On récupère les IDs du backend et on filtre ceux supprimés/cachés
            final fetchedAlerts = data.map((item) => Alert(
              id: item['id'],
              // (Même logique de parsing qu'avant)
              type: AlertType.values.firstWhere(
                (e) => e.name == item['type'], 
                orElse: () => AlertType.danger
              ),
              position: LatLng(
                double.parse(item['latitude'].toString()), 
                double.parse(item['longitude'].toString())
              ),
              timestamp: DateTime.parse(item['timestamp']),
              description: item['description'],
              upvotes: int.tryParse(item['upvotes'].toString()) ?? 0,
              downvotes: int.tryParse(item['downvotes'].toString()) ?? 0,
            )).where((a) => !_deletedIds.contains(a.id) && !_hiddenIds.contains(a.id)).toList();

            // MERGE LOGIC:
            // 1. Supprimer les alertes locales qui ne sont plus sur le serveur 
            //    ET qui ne sont pas "très récentes" (pour éviter de wiper un post en cours)
            final now = DateTime.now();
            _alerts.removeWhere((local) {
              bool onServer = fetchedAlerts.any((remote) => remote.id == local.id);
              bool isVeryRecent = now.difference(local.timestamp).inMinutes < 2;
              return !onServer && !isVeryRecent;
            });

            // 2. Mettre à jour ou ajouter les alertes du serveur
            for (var remote in fetchedAlerts) {
              int index = _alerts.indexWhere((local) => local.id == remote.id);
              if (index != -1) {
                _alerts[index] = remote; // Update (scores...)
              } else {
                _alerts.add(remote); // Add new
              }
            }

            await _saveAlerts();
         }
      }
    } catch (e) {
      print("Erreur sync PHP: $e");
    }
  }


  // Obtenir le nombre d'alertes actives
  int get activeAlertsCount => _alerts.where((alert) => !alert.isExpired).length;
}
