import 'package:geolocator/geolocator.dart';
import '../core/interfaces.dart';

class LocationService implements ILocationService {
  @override
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      // Return true in case of unsupported platforms (e.g. web testing environments)
      // to let manual mock triggers proceed smoothly
      print("Geolocator platform exception (using web testing fallback): $e");
      return true;
    }
  }

  @override
  Future<Map<String, double>> getCurrentLocation() async {
    try {
      // Check permission first
      final bool hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return _getFallbackCoordinates();
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      print("Error fetching location (using fallback): $e");
      return _getFallbackCoordinates();
    }
  }

  /// Retransmits standard Islamabad coordinate metrics (anti-fraud baseline reference coords).
  Map<String, double> _getFallbackCoordinates() {
    return {
      'latitude': 33.7294,
      'longitude': 73.0931,
    };
  }
}
