
import 'package:latlong2/latlong.dart';

List<LatLng> decodeWithPrecision(String encoded, double precision) {
  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  try {
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      final double finalLat = lat / precision;
      final double finalLng = lng / precision;
      
      if (finalLat.isFinite && finalLng.isFinite && 
          finalLat > -90 && finalLat < 90 && 
          finalLng > -180 && finalLng < 180) {
        points.add(LatLng(finalLat, finalLng));
      }
    }
  } catch (e) {
    print("Error: $e");
  }
  return points;
}

void main() {
  final shape = "ag}d|AmbqnCnCqQ~Ew[^cCj@wDj@eFpCpAt@ZxMzFvClEbAhAX\\bAzAt@|Ap@`CBrBmApGWdAMv@{AbMSzAqMdf@gBfGeFnQmBjG";
  print("Testing 1e6:");
  final points6 = decodeWithPrecision(shape, 1e6);
  if (points6.isNotEmpty) {
     print("1e6 Decoded ${points6.length} points");
     print("First: ${points6.first.latitude}, ${points6.first.longitude}");
  }
  
  print("\nTesting 1e5:");
  final points5 = decodeWithPrecision(shape, 1e5);
  if (points5.isNotEmpty) {
     print("1e5 Decoded ${points5.length} points");
     print("First: ${points5.first.latitude}, ${points5.first.longitude}");
  }
}
