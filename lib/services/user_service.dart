import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class Peer {
  final String id;
  final LatLng position;

  Peer({required this.id, required this.position});

  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      id: json['user_id'],
      position: LatLng(
        double.parse(json['latitude'].toString()),
        double.parse(json['longitude'].toString()),
      ),
    );
  }
}

class UserService {
  static const String _userKey = 'user_unique_id';
  static const String _baseUrl = kReleaseMode 
      ? 'https://muhammed-ali.fr/web/api.php' 
      : 'http://127.0.0.1:8001/api.php';
  
  String? _userId;

  Future<String> getUserId() async {
    if (_userId != null) return _userId!;
    
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userKey);
    
    if (_userId == null) {
      _userId = const Uuid().v4();
      await prefs.setString(_userKey, _userId!);
    }
    
    return _userId!;
  }

  Future<List<Peer>> updatePosition(LatLng position) async {
    try {
      final userId = await getUserId();
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'update_position',
          'user_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Peer.fromJson(item)).toList();
      }
    } catch (e) {
      print("Erreur UserService: $e");
    }
    return [];
  }
}
