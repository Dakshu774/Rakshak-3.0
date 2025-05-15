import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class LocationSharingPage extends StatefulWidget {
  const LocationSharingPage({super.key});

  @override
  _LocationSharingPageState createState() => _LocationSharingPageState();
}

class _LocationSharingPageState extends State<LocationSharingPage> {
  GoogleMapController? _mapController;
  Marker? _userMarker;
  final Set<Marker> _visitedMarkers = {};
  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _locationSubscription;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // Check and request location permissions
  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  }

  // Start or stop live location updates
  Future<void> _toggleLocationUpdates() async {
    if (_isTracking) {
      _stopLocationUpdates();
    } else {
      _startLocationUpdates();
    }
    setState(() {
      _isTracking = !_isTracking;
    });
  }

  // Start live location tracking
  Future<void> _startLocationUpdates() async {
    String? userId = _locationService.getUserId();

    if (userId == null || userId.isEmpty) {
      print("❌ Error: User ID is null or empty");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User is not logged in")),
      );
      return;
    }

    String path = "users/$userId/location"; // ✅ Corrected path
    print("✅ Firebase Path: $path"); // Debugging print

    _locationService.startLocationUpdates(path); // ✅ Fixed positional argument error

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      print("📍 New Location: ${position.latitude}, ${position.longitude}");

      if (_mapController != null) {
        setState(() {
          _userMarker = Marker(
            markerId: const MarkerId('user'),
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Your Live Location'),
          );

          _mapController!.animateCamera(
            CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
          );
        });

        // Store live location in Firebase
        FirebaseDatabase.instance.ref(path).set({
          "latitude": position.latitude,
          "longitude": position.longitude,
          "timestamp": DateTime.now().toIso8601String(),
        }).catchError((error) {
          print("🔥 Firebase Error: $error");
        });
      }
    });
  }

  // Stop live location tracking
  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    print("🛑 Location tracking stopped");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Location Sharing"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629), // Default to India
              zoom: 14.0,
            ),
            markers: _userMarker != null ? {_userMarker!, ..._visitedMarkers} : _visitedMarkers,
            onMapCreated: (controller) {
              _mapController = controller;
              _startLocationUpdates();
            },
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _toggleLocationUpdates,
              label: Text(_isTracking ? "Stop Tracking" : "Start Tracking"),
              icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
              backgroundColor: _isTracking ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
