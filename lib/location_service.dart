import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  StreamSubscription<Position>? _locationSubscription;

  // Get the currently logged-in user's ID
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  // Get current location with permissions
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled. Please enable them.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied. Enable it in settings.");
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Start tracking user location and update Firebase
  Future<void> startLocationUpdates(String path) async {
    String? userId = getUserId();
    if (userId == null || userId.isEmpty) {
      print("Error: User is not logged in.");
      return;
    }

    print("Tracking started at: $path"); // Debugging print

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      print("📍 New Location: ${position.latitude}, ${position.longitude}");

      final DatabaseReference locationRef = _db.child(path);

      await locationRef.set({
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timestamp": DateTime.now().toIso8601String(),
      }).catchError((error) {
        print("Firebase Error: $error");
      });

      await _updateVisitedPlaces(userId, position.latitude, position.longitude);
    });
  }

  // Stop live location tracking
  void stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    print("Location tracking stopped");
  }

  // Update visited places and store in Firebase
  Future<void> _updateVisitedPlaces(String userId, double latitude, double longitude) async {
    final DatabaseReference visitedPlacesRef = _db.child('users/$userId/visitedPlaces');
    final DataSnapshot visitedPlacesSnapshot = await visitedPlacesRef.get();

    Map<String, dynamic> visitedPlaces = {};
    if (visitedPlacesSnapshot.exists && visitedPlacesSnapshot.value is Map) {
      visitedPlaces = Map<String, dynamic>.from(visitedPlacesSnapshot.value as Map);
    }

    bool visitUpdated = false;
    const double geofenceRadius = 0.5; // 500 meters

    visitedPlaces.forEach((placeKey, visitCount) {
      final List<String> latLng = placeKey.split(',');
      final double placeLat = double.parse(latLng[0]);
      final double placeLng = double.parse(latLng[1]);

      final double distance = Geolocator.distanceBetween(latitude, longitude, placeLat, placeLng);
      if (distance <= geofenceRadius * 1000) {
        visitedPlaces[placeKey] = (visitCount as int) + 1;
        visitUpdated = true;
      }
    });

    if (!visitUpdated) {
      final newPlaceKey = '$latitude,$longitude';
      visitedPlaces[newPlaceKey] = 1;
    }

    await visitedPlacesRef.set(visitedPlaces).catchError((error) {
      print("Firebase Error (Visited Places): $error");
    });
  }
}
