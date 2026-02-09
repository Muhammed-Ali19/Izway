import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


// Services
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/search_service.dart';
import '../services/alert_service.dart';
import '../services/traffic_service.dart';
import '../services/country_service.dart';
import '../services/user_service.dart';

// Models
import '../models/route_models.dart';
import '../models/alert.dart';

// Widgets
import '../widgets/search/search_bar.dart';
import '../widgets/search/search_results.dart';
import '../widgets/navigation/instruction_banner.dart';
import '../widgets/navigation/navigation_dashboard.dart';
import '../widgets/navigation/speed_limit_widget.dart';
import '../widgets/routes/route_selector.dart';
import '../widgets/routes/trip_summary.dart';
import '../widgets/alerts/alert_buttons.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // Services
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final SearchService _searchService = SearchService();

  final AlertService _alertService = AlertService();
  final TrafficService _trafficService = TrafficService();
  final CountryService _countryService = CountryService();
  final UserService _userService = UserService();

  // Controllers
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _markerAnimController;
  late AnimationController _cameraAnimController;
  
  // State Locations
  Position? _currentPosition;
  LatLng? _currentDisplayPosition;
  double _currentHeading = 0.0;
  LatLng? _animStartPos;
  LatLng? _animEndPos;
  double _animStartHeading = 0.0;
  double _animEndHeading = 0.0;
  
  // State Navigation/Routes
  List<RouteInfo> _routes = [];
  int _selectedRouteIndex = 0;
  bool _isRouting = false;
  bool _isNavigationMode = false;
  bool _isFollowingUser = true;
  LatLng? _destination;
  List<String> _tripFlags = [];
  List<CountrySegment> _countrySegments = [];
  String? _nextBorderDist;
  String? _nextBorderFlag;
  
  // State Search
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  
  // State Alerts
  List<Alert> _nearbyAlerts = [];
  List<Alert> _trafficAlerts = [];
  List<Peer> _peers = [];
  Timer? _alertTimer;
  Timer? _userSyncTimer;
  Timer? _searchDebounce;
  Alert? _activeValidationAlert;
  bool _isDarkMode = false;
  double _currentSpeed = 0.0;
  bool _isSpeeding = false;
  int _currentLimit = 50; // Par défaut
  bool _isInRadarZone = false;
  bool _isCalculatingCountries = false;

  @override
  void initState() {
    super.initState();
    print("--------------------------------------------------");
    print("GPS FRONTIERE - VERSION 3.1 - UI MISE À JOUR");
    print("--------------------------------------------------");
    _initAnimation();
    _initLocation();
    _initAlerts();
    _initUserSync();
    _checkNightMode();
    _restoreNavigationState(); // Charger le trajet précédent si existe
  }

  Future<void> _restoreNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    final String? destJson = prefs.getString('nav_destination');
    print("DEBUG: _restoreNavigationState, destJson: ${destJson != null ? 'EXISTS' : 'NULL'}");
    if (destJson != null) {
      final Map<String, dynamic> data = json.decode(destJson);
      final dest = LatLng(data['lat'], data['lon']);
      
      // Attendre que la position soit disponible (plusieurs tentatives si nécessaire)
      for (int i = 0; i < 10; i++) {
        if (_currentPosition != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted && _currentPosition != null) {
        _calculateRoutes(dest, autoStart: true);
      }
    }
  }

  Future<void> _saveNavigationState(LatLng? dest) async {
    final prefs = await SharedPreferences.getInstance();
    if (dest == null) {
      await prefs.remove('nav_destination');
    } else {
      await prefs.setString('nav_destination', json.encode({
        'lat': dest.latitude,
        'lon': dest.longitude,
      }));
    }
  }

  void _initUserSync() {
    // Sync position every 10 seconds
    _userSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _syncPosition());
  }

  Future<void> _syncPosition() async {
    if (_currentDisplayPosition != null) {
      final peers = await _userService.updatePosition(_currentDisplayPosition!);
      if (mounted) {
        setState(() {
          _peers = peers;
        });
      }
    }
  }
  
  void _checkNightMode() {
    final hour = DateTime.now().hour;
    setState(() {
      _isDarkMode = hour < 6 || hour >= 20; // 20h - 6h
    });
  }
  
  void _initAnimation() {
    _markerAnimController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300)
    );
    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000)
    );
    _markerAnimController.addListener(() {
      if (_animStartPos != null && _animEndPos != null) {
        setState(() {
          double t = _markerAnimController.value;
          
          // Interpolate Position
          double lat = _animStartPos!.latitude + (_animEndPos!.latitude - _animStartPos!.latitude) * t;
          double lng = _animStartPos!.longitude + (_animEndPos!.longitude - _animStartPos!.longitude) * t;
          _currentDisplayPosition = LatLng(lat, lng);
          
          // Interpolate Heading (shortest path)
          double diff = _animEndHeading - _animStartHeading;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;
          _currentHeading = _animStartHeading + diff * t;

          // Sync Camera
          if (_isFollowingUser) {
            _mapController.move(_currentDisplayPosition!, _mapController.camera.zoom);
            if (_isNavigationMode) {
              _mapController.rotate(-_currentHeading);
            }
          }
        });
      }
    });
  }

  Future<void> _initLocation() async {
    final status = await _locationService.checkPermissionsStatus();
    if (status != "ok") {
      String msg = "Erreur de localisation : $status";
      if (status == "service_disabled") msg = "Veuillez activer le GPS de votre appareil.";
      if (status == "permission_denied") msg = "L'accès à la position a été refusé.";
      if (status == "permission_denied_forever") msg = "L'accès à la position a été refusé de manière permanente. Veuillez l'activer dans les paramètres de l'appareil.";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    // Récupérer la position initiale avec un timeout très court pour ne pas bloquer l'UI
    try {
      final pos = await _locationService.getCurrentPosition().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null, // On laisse le stream prendre le relais après
      );
      if (pos != null) {
        _updatePosition(pos);
      } else {
        // Fallback immédiat si trop long
        print("Location: GPS trop lent, utilisation position par défaut.");
        _updatePosition(Position(
          latitude: 46.0746, longitude: 6.5720, // Region Frontière
          timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0,
        ));
      }
    } catch (e) {
      print("Erreur position initiale: $e");
    }

    _locationService.getPositionStream(distanceFilter: 5).listen(
      (Position position) {
        _updatePosition(position);
      },
      onError: (e) {
        print("STREAM ERROR: $e");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Perte du signal GPS: $e")),
           );
        }
      }
    );
  }

  Future<void> _initAlerts() async {
    await _alertService.loadAlerts();
    // Refresh immediately at start with map center
    _refreshAlerts();
    // Refresh alerts every 30s
    _alertTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshAlerts());
  }

  void _refreshAlerts() async {
    // Utiliser la position GPS si dispo, sinon le centre de la carte
    final LatLng center = _currentDisplayPosition ?? _mapController.camera.center;
    
    // 1. Local/User alerts (Police, Accident)
    final userAlerts = await _alertService.getAlertsNearby(center, 250000); // 250km
    
    // 2. API Traffic alerts (Radar, Bouchon)
    List<Alert> apiAlerts = [];
    if (_routes.isEmpty) {
       apiAlerts = await _trafficService.fetchTrafficAlerts(center, 50);
       _trafficAlerts = apiAlerts;
    }

    if (mounted) {
      setState(() {
        _nearbyAlerts = userAlerts;
      });
    }
  }

  @override
  void dispose() {
    _markerAnimController.dispose();
    _cameraAnimController.dispose();
    _alertTimer?.cancel();
    _userSyncTimer?.cancel();
    _searchDebounce?.cancel();
    _countryService.dispose();
    _trafficService.dispose();
    super.dispose();
  }

  void _updatePosition(Position position) {
    LatLng newPos = LatLng(position.latitude, position.longitude);
    
    setState(() {
      _currentPosition = position;
      _currentHeading = position.heading;
      _currentSpeed = position.speed * 3.6; // m/s to km/h
      
      // Mise à jour de la limite de vitesse basée sur la route
      if (_isNavigationMode && _routes.isNotEmpty) {
        final route = _routes[_selectedRouteIndex];
        final idx = _locationService.findClosestPointIndex(newPos, route.points);
        if (idx != -1 && route.speedLimits != null && idx < route.speedLimits!.length) {
          final speedLimitMs = route.speedLimits![idx]; // OSRM renvoie souvent en m/s ou km/h selon version
          // NOTE: Sur router.project-osrm.org, c'est souvent la vitesse "théorique" en m/s ou index.
          // Pour cet exercice, on va assumer que c'est une valeur exploitable ou on garde le fallback.
          if (speedLimitMs > 0) {
            _currentLimit = (speedLimitMs * 3.6).round(); // Conversion si m/s
            // Ajustement si OSRM renvoie des valeurs bizarres (ex: 130 km/h)
            if (_currentLimit > 200) _currentLimit = (speedLimitMs).round(); 
          }
        }
      }
      
      _isSpeeding = _currentSpeed > (_currentLimit + 5); // Tolérance de 5km/h
      
      if (_currentDisplayPosition == null) {
        _currentDisplayPosition = newPos;
        _animEndPos = newPos;
        _animEndHeading = _currentHeading;
        // Trigger alert refresh immediately when location is found
        _refreshAlerts();
      } else {
        _animStartPos = _currentDisplayPosition;
        _animEndPos = newPos;
        _animStartHeading = _currentHeading;
        _animEndHeading = position.heading;
        _markerAnimController.reset();
        _markerAnimController.forward();
      }
      
      // Filter out hidden/deleted alerts immediately from display lists
      _nearbyAlerts.removeWhere((a) => _alertService.isHidden(a.id));
      _trafficAlerts.removeWhere((a) => _alertService.isHidden(a.id));
    });

    if (_isNavigationMode && _isFollowingUser) {
      _checkOffRoute(position);
    }
    
    // Check next border distance
    if (_countrySegments.isNotEmpty) {
      _checkNextBorder(newPos);
    }

    // Check for nearby alerts to validate
    _checkAlertValidation(newPos);

    // Check if in radar zone for visual warning
    _checkRadarZone(newPos);
  }

  void _checkRadarZone(LatLng userPos) {
    bool found = false;
    for (var alert in [..._nearbyAlerts, ..._trafficAlerts]) {
       if (alert.type == AlertType.radar) {
          final dist = _locationService.distanceBetween(userPos, alert.position);
          if (dist < 1500) { // 1.5km radar zone alert
             found = true;
             break;
          }
       }
    }
    if (found != _isInRadarZone) {
       setState(() => _isInRadarZone = found);
    }
  }

  void _checkAlertValidation(LatLng userPos) {
    if (_activeValidationAlert != null) {
      // Si on s'éloigne de l'alerte en cours, on ferme le popup
      final dist = _locationService.distanceBetween(userPos, _activeValidationAlert!.position);
      if (dist > 1000) setState(() => _activeValidationAlert = null);
      return;
    }

    // Chercher une alerte proche (< 500m) non votée
    for (var alert in [..._nearbyAlerts, ..._trafficAlerts]) {
      // EXCLUSION : On ne demande pas de valider les radars (fixes)
      if (alert.type == AlertType.radar) continue;
      
      // Utiliser le service pour la persistance des votes
      if (_alertService.isVoted(alert.id)) continue;

      final dist = _locationService.distanceBetween(userPos, alert.position);
      if (dist < 500) {
        setState(() => _activeValidationAlert = alert);
        break;
      }
    }
  }

  void _checkNextBorder(LatLng userPos) {
    if (_countrySegments.length < 2) return; // Only 1 country or empty

    // Find next segment that is NOT the current country
    // Simple logic: find closest segment start point that is ahead?
    // Or just look at the list sequentially. 
    // Optimization: Assume segments are ordered.
    
    // Current country code?
    // We iterate to find the first segment where country code != current detected code
    // actually segments are [FR, DE, AT]
    
    for (int i = 0; i < _countrySegments.length; i++) {
        final seg = _countrySegments[i];
        
        // Skip current country
        if (seg.countryCode == _countrySegments.first.countryCode && i == 0) continue;

        // Calculate real distance along route
        if (_routes.isNotEmpty) {
           double realDist = _locationService.distanceAlongRoute(
              userPos, 
              seg.startPosition, 
              _routes[_selectedRouteIndex].points
           );

           if (realDist > 500) { // If more than 500m away
              final dKm = (realDist / 1000).toStringAsFixed(1);
              setState(() {
                 _nextBorderDist = "$dKm km";
                 _nextBorderFlag = _countryService.getFlagEmoji(seg.countryCode);
              });
              return;
           }
        }
    }
    // No more borders detected
    if (_nextBorderDist != null) {
      setState(() {
        _nextBorderDist = null;
        _nextBorderFlag = null;
      });
    }
  }

  void _checkOffRoute(Position position) {
    if (_routes.isEmpty || _destination == null) return;
    
    final route = _routes[_selectedRouteIndex];
    double minDist = double.infinity;
    
    // Simple check: distance au point le plus proche
    // Optimisation possible: check seulement sur le segment actuel
    for (var point in route.points) {
      final dist = _locationService.distanceBetween(
        LatLng(position.latitude, position.longitude),
        point
      );
      if (dist < minDist) minDist = dist;
    }

    if (minDist > 50) {
      print("Hors route (${minDist.round()}m) - Recalcul automatique...");
      _calculateRoutes(_destination!, autoResume: true);
    }
  }

  void _onSearchChanged(String val) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (val.length > 1) {
        _search(val);
      } else if (val.isEmpty) {
        setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _search(String query) async {
    print("DEBUG: _search called with: $query");
    setState(() => _isSearching = true);
    final results = await _searchService.searchPlaces(query, _currentDisplayPosition);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _calculateRoutes(LatLng dest, {bool autoResume = false, bool autoStart = false}) async {
    print("DEBUG: _calculateRoutes appelé. Dest: ${dest.latitude}, ${dest.longitude}, autoResume: $autoResume");
    if (_currentPosition == null) {
      if (!autoResume) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ERREUR: Position actuelle nulle!")),
        );
      }
      return;
    }
    
    if (!autoResume && !autoStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Calcul de l'itinéraire en cours..."), duration: Duration(seconds: 1)),
      );
    }
    
    setState(() {
      _isRouting = true;
      _destination = dest;
      _routes = [];
      _selectedRouteIndex = 0; 
      if (!autoResume) _isFollowingUser = false; 
      _searchResults = []; 
      if (!autoResume && !autoStart) _isNavigationMode = false;
    });

    final start = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final routes = await _routeService.calculateRoutes(start, dest);

      if (routes.isEmpty) {
        setState(() => _isRouting = false);
        if (!autoResume) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun itinéraire trouvé vers cette destination.")),
          );
        }
        return;
      }

      setState(() {
        _routes = routes;
        _isRouting = false;
        
        print("MAP: Route set! ${routes.length} routes. First route has ${routes.first.points.length} points.");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${routes.length} itinéraires trouvés !")),
        );

        // Zoom pour voir toute la route (seulement si pas auto)
        final points = routes.first.points;
        if (points.isNotEmpty && !autoResume && !autoStart) {
          final bounds = LatLngBounds.fromPoints(points);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(80.0),
            ),
          );
        }

        if (autoResume || autoStart) {
          _isNavigationMode = true;
          _isFollowingUser = true;
        }

        // 3. Calculer les pays traversés (Async)
        _calculateCountries(routes.first.points);

        // 4. Récupérer les radars sur TOUTE la route (Async)
        _fetchRouteAlerts(routes.first.points);
      });
  }

  Future<void> _fetchRouteAlerts(List<LatLng> points) async {
      final alerts = await _trafficService.fetchTrafficAlertsForRoute(points);
      if (mounted) {
        setState(() {
          // On ajoute sans écraser les autres (si possible) ou en remplaçant les radars précédents
          // Ici on assume que _trafficAlerts contient les radars de la route
          _trafficAlerts = alerts;
        });
      }
  }

  Future<void> _calculateCountries(List<LatLng> points) async {
    setState(() => _isCalculatingCountries = true);
    final segments = await _countryService.getCountrySegments(points);
    final flags = segments.map((s) => _countryService.getFlagEmoji(s.countryCode)).toSet().toList(); // unique flags
    
    if (mounted) {
      setState(() {
         _countrySegments = segments;
         _tripFlags = flags;
         _isCalculatingCountries = false;
      });
    }
  }

  void _startNavigation() {
    if (_currentPosition == null) return;

    final LatLng startPos = _mapController.camera.center;
    final double startZoom = _mapController.camera.zoom;
    final double startRotation = _mapController.camera.rotation;

    final LatLng endPos = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final double endZoom = 17.5;
    final double endRotation = -_currentHeading;

    // S'assurer qu'il y a un mouvement visible
    // Si déjà trop proche en zoom, on dézoom un peu d'abord pour l'effet "plongée"
    double startZoomAdj = startZoom;
    if ((startZoom - endZoom).abs() < 1) {
       startZoomAdj = endZoom - 4; // Dézoom forcé de 4 niveaux
    }

    _cameraAnimController.stop();
    _cameraAnimController.reset();

    final Animation<double> curve = CurvedAnimation(
      parent: _cameraAnimController,
      curve: Curves.fastOutSlowIn,
    );

    VoidCallback? listener;
    listener = () {
      if (!mounted) {
        _cameraAnimController.removeListener(listener!);
        return;
      }
      final double t = curve.value;
      
      // Interpolate Position
      final double lat = startPos.latitude + (endPos.latitude - startPos.latitude) * t;
      final double lng = startPos.longitude + (endPos.longitude - startPos.longitude) * t;
      
      // Interpolate Zoom (utiliser le zoom ajusté pour garantir l'effet)
      final double zoom = startZoomAdj + (endZoom - startZoomAdj) * t;
      
      // Interpolate Rotation
      double diff = endRotation - startRotation;
      while (diff > 180) diff -= 360;
      while (diff < -180) diff += 360;
      final double rotation = startRotation + diff * t;

      _mapController.move(LatLng(lat, lng), zoom);
      _mapController.rotate(rotation);

      if (t == 1.0) {
        _cameraAnimController.removeListener(listener!);
      }
    };

    _cameraAnimController.addListener(listener);

    setState(() {
      _isNavigationMode = true;
      _isFollowingUser = false; // Désactiver pendant l'animation pour éviter les conflits
    });

    _cameraAnimController.forward().then((_) {
      if (mounted) {
        setState(() => _isFollowingUser = true); // Réactiver une fois fini
      }
    });

    _saveNavigationState(_destination);
  }

  void _stopNavigation() {
    setState(() {
      _isNavigationMode = false;
      _routes = [];
      _destination = null;
      _mapController.rotate(0);
    });
    _saveNavigationState(null);
  }

  void _onAlertReported(AlertType type) {
    if (_currentPosition != null) {
      _alertService.addAlert(
        type, 
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      );
      _refreshAlerts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signalement envoyé ! Merci de votre contribution."))
      );
    }
  }

  void _voteForAlert(Alert alert, bool up) {
    _alertService.voteAlert(alert.id, up);
    setState(() {
      _activeValidationAlert = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(up ? "Merci d'avoir confirmé !" : "Merci de votre signalement."),
        duration: const Duration(seconds: 1),
      )
    );
  }

  void _deleteAlert(Alert alert) async {
    final res = await _alertService.removeAlert(alert.id);
    setState(() {
      _activeValidationAlert = null;
      _nearbyAlerts.removeWhere((a) => a.id == alert.id);
      _trafficAlerts.removeWhere((a) => a.id == alert.id);
    });

    if (mounted) {
      String msg = "Signalement supprimé localement.";
      if (res['success'] == true) {
        if (res['deleted_count'] != null && res['deleted_count'] > 0) {
           msg = "Signalement supprimé avec succès du serveur.";
        } else if (res['message'] != null) {
           msg = res['message'];
        }
      } else {
        msg = "Erreur serveur : ${res['error'] ?? 'Inconnu'}";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_routes.isNotEmpty) {
       print("BUILD: Rendering ${_routes.length} routes. First route has ${_routes.first.points.length} points.");
    }
    // Calcul ETA pour Dashboard
    String duration = "", distance = "", eta = "";
    if (_routes.isNotEmpty) {
      final route = _routes[_selectedRouteIndex];
      duration = route.formattedDuration;
      distance = route.formattedDistance;
      final arrival = DateTime.now().add(Duration(seconds: route.duration.toInt()));
      eta = "${arrival.hour}h${arrival.minute.toString().padLeft(2,'0')}";
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(48.8566, 2.3522),
              initialZoom: 15.0,
              minZoom: 3.0, // Permettre de dézoomer davantage
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              crs: const Epsg3857(), 
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
              ),
              onPositionChanged: (cam, hasGesture) {
                if (hasGesture) {
                  setState(() => _isFollowingUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isDarkMode 
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.alihirlak.gpsfrontiere',
                maxNativeZoom: 19,
                maxZoom: 19,
              ),
              
              // Polylines
              PolylineLayer(
                polylines: <Polyline>[
                  // REAL ROUTES
                  if (_routes.isNotEmpty)
                    ..._routes.asMap().entries.map<Polyline>((entry) {
                      final i = entry.key;
                      final route = entry.value;
                      final isSelected = i == _selectedRouteIndex;
                      
                      return Polyline(
                        points: route.points,
                        strokeWidth: isSelected ? 8.0 : 4.0,
                        color: isSelected ? const Color(0xFF2196F3) : Colors.blueGrey,
                      );
                    }),
                ],
              ),
                
              // Markers (Destination + Alerts + User)
              MarkerLayer(
                markers: [
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  
                  // Alerts (User + Traffic)
                  ...[..._nearbyAlerts, ..._trafficAlerts].where((a) => !_alertService.isHidden(a.id)).map((alert) {
                    final dist = (_currentDisplayPosition != null) 
                      ? _locationService.distanceBetween(_currentDisplayPosition!, alert.position)
                      : 999999.0;
                      
                    if (alert.type == AlertType.radar && dist > 5000) return null; // Hide very far radars
                    
                    // Dynamic size based on distance
                    double size = (dist < 1000) ? 45.0 : 30.0;
                    double iconSize = (dist < 1000) ? 28.0 : 18.0;

                    return Marker(
                      point: alert.position,
                      width: size,
                      height: size,
                      child: GestureDetector(
                        onTap: () => setState(() => _activeValidationAlert = alert),
                        child: Container(
                          decoration: BoxDecoration(
                            color: alert.type == AlertType.radar ? Colors.orange.withOpacity(0.9) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                            border: alert.type == AlertType.radar ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                          child: Center(child: Text(alert.icon, style: TextStyle(fontSize: iconSize))),
                        ),
                      ),
                    );
                  }).whereType<Marker>(),

                  // Other Users (Social GPS)
                  for (var peer in _peers)
                    Marker(
                      point: peer.position,
                      width: 45,
                      height: 45,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orangeAccent, width: 2),
                          boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)],
                        ),
                        child: const Center(
                          child: Icon(Icons.directions_car, color: Colors.orange, size: 28),
                        ),
                      ),
                    ),

                  // User (Car/Spot)
                  if (_currentDisplayPosition != null)
                    Marker(
                      point: _currentDisplayPosition!,
                      width: 60,
                      height: 60,
                      child: Transform.rotate(
                        angle: _isNavigationMode ? 0 : (_currentHeading * (pi / 180)),
                        child: Icon(
                          _isNavigationMode ? Icons.navigation : Icons.circle,
                          color: Colors.blueAccent,
                          size: 40,
                          shadows: [],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. UI LAYERS
          
          // Search Bar (si pas en navigation)
          if (!_isNavigationMode)
            ModernSearchBar(
              controller: _searchController,
              isSearching: _isSearching,
              onClear: () {
                _searchController.clear();
                setState(() => _searchResults = []);
              },
              onSubmitted: _search,
              onChanged: _onSearchChanged,
            ),

          // Search Results
          if (_searchResults.isNotEmpty && !_isNavigationMode)
            SearchResults(
              results: _searchResults,
              onResultSelected: (res) {
                 print("DEBUG: Result selected: ${res.displayName} (${res.lat}, ${res.lon})");
                 FocusScope.of(context).unfocus();
                 _calculateRoutes(LatLng(res.lat, res.lon));
              },
            ),

          /*
          // Navigation Instruction (si en nav)
          if (_isNavigationMode && 
              _routes.isNotEmpty && 
              _selectedRouteIndex < _routes.length &&
              _routes[_selectedRouteIndex].steps.isNotEmpty)
             InstructionBanner(
               instruction: _routes[_selectedRouteIndex].steps.first.instruction,
               distance: _routes[_selectedRouteIndex].steps.first.formattedDistance, 
             ),

          // Trip Summary (Flags) - Affiché si route calculée, avant ou pendant navigation
          if (_routes.isNotEmpty && _tripFlags.isNotEmpty)
             Positioned(
               top: _isNavigationMode ? 120 : 160,
               left: 16,
               child: TripSummary(
                 countryFlags: _tripFlags,
                 isLoading: _isCalculatingCountries,
                 nextBorderDistance: _nextBorderDist,
                 nextBorderFlag: _nextBorderFlag,
               ),
             ),
          */

          // Radar Zone Warning
          if (_isInRadarZone)
            Positioned(
              top: 110,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.orange[800]!.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black45)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.white, size: 30),
                    const SizedBox(width: 15),
                    const Expanded(
                      child: Text(
                        "ZONE DE CONTRÔLE RADAR",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Speed Limit & Recenter Button
          Positioned(
            bottom: _isNavigationMode ? 260 : 120,
            right: 16,
            child: Column(
              children: [
                if (_isNavigationMode)
                   SpeedLimitWidget(
                     limit: _currentLimit,
                     isSpeeding: _isSpeeding,
                   ), 
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "recenter",
                  backgroundColor: const Color(0xFF1E293B),
                  child: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed, color: Colors.blueAccent),
                  onPressed: () {
                    setState(() => _isFollowingUser = true);
                    if (_currentPosition != null) {
                      _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 17);
                      if (_isNavigationMode) _mapController.rotate(-_currentHeading);
                    }
                  },
                ),
              ],
            ),
          ),

          // Alert Buttons (EN Navigation OU si on suit l'utilisateur)
          if ((_isNavigationMode || _isFollowingUser) && _currentPosition != null)
             Positioned(
               bottom: _isNavigationMode ? 220 : 120, // Ajuster selon le dashboard
               left: 16,
               child: AlertButtons(onAlertSelected: _onAlertReported),
             ),
             
          // Alert Validation Dialog
          if (_activeValidationAlert != null)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black45)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Signalement : ${_activeValidationAlert!.label} ${_activeValidationAlert!.icon}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Est-il toujours présent ?",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _voteForAlert(_activeValidationAlert!, false),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text("NON", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _voteForAlert(_activeValidationAlert!, true),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text("OUI", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                        ),
                        IconButton(
                          onPressed: () => _deleteAlert(_activeValidationAlert!),
                          icon: const Icon(Icons.delete, color: Colors.white70),
                          tooltip: "Supprimer",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
             
          // Route Selector (si routes calculées mais pas démarrées)
          if (_routes.isNotEmpty && !_isNavigationMode)
             Positioned(
               bottom: 0,
               left: 0,
               right: 0,
               child: RouteSelector(
                 routes: _routes,
                 selectedIndex: _selectedRouteIndex,
                 onRouteSelected: (i) => setState(() => _selectedRouteIndex = i),
                 onStartNavigation: _startNavigation,
               ),
             ),
             
          // Navigation Dashboard (si en nav)
          if (_isNavigationMode)
             Positioned(
               bottom: 0,
               left: 0,
               right: 0,
                child: NavigationDashboard(
                  duration: duration,
                  distance: distance,
                  eta: eta,
                  nextBorderDist: _nextBorderDist,
                  nextBorderFlag: _nextBorderFlag,
                  onStopNavigation: _stopNavigation,
                ),
             ),
             
          if (_isRouting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ),

          // DEBUG BUTTON
          Positioned(
            top: 250,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'debug_lyon',
              onPressed: () => _calculateRoutes(const LatLng(45.7640, 4.8357)),
              backgroundColor: Colors.red,
              child: const Text("LYON"),
            ),
          ),
        ],
      ),
    );
  }
}
