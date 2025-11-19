import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kEmerald500 = Color(0xFF10B981);
const Color kRed500 = Color(0xFFEF4444);
const Color kSlate600 = Color(0xFF475569);

// Optimized Dark Map Style
const String _darkMapStyle = '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}]';

class LocationTrackingScreen extends StatefulWidget {
  const LocationTrackingScreen({Key? key}) : super(key: key);

  @override
  _LocationTrackingScreenState createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Battery _battery = Battery();
  
  // Streams
  StreamSubscription<Position>? _myLocationStream;
  StreamSubscription<QuerySnapshot>? _familyLocationStream;
  
  // Map Data
  Map<String, Marker> _markers = {}; 
  Set<Circle> _circles = {};   // Safe Zones (Green)
  Set<Polygon> _polygons = {}; // Danger Zones (Red)
  
  // State Data
  List<QueryDocumentSnapshot> _familyMembers = [];
  String? _myFamilyId;
  bool _isLoading = true;
  Position? _myPosition;
  
  // Camera Control
  bool _shouldFollowUser = true; 

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  @override
  void dispose() {
    _myLocationStream?.cancel();
    _familyLocationStream?.cancel();
    super.dispose();
  }

  Future<void> _initServices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 1. Get Family ID
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _myFamilyId = doc.data()?['familyId'];
          _isLoading = false;
        });
        
        // 2. Start Listening to Family
        _listenToFamilyLocations(user.uid);
        
        // 3. Start Broadcasting My Location
        _broadcastMyLocation(user.uid);
      }
    }
  }

  // --- A. SAFE ZONE LOGIC ---
  void _updateSafeZone(LatLng center) {
    setState(() {
      // Clear old safe zones
      _circles.clear(); 
      
      // Add new Green Circle
      _circles.add(
        Circle(
          circleId: const CircleId('home_zone'),
          center: center, 
          radius: 500, // 500 meters
          fillColor: kEmerald500.withOpacity(0.15),
          strokeColor: kEmerald500.withOpacity(0.5),
          strokeWidth: 2,
        ),
      );

      // Add a Demo Danger Zone relative to user (just for visualization)
      _polygons.clear();
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('danger_zone'),
          points: [
            LatLng(center.latitude + 0.005, center.longitude + 0.005),
            LatLng(center.latitude + 0.008, center.longitude + 0.008),
            LatLng(center.latitude + 0.002, center.longitude + 0.008),
          ],
          fillColor: kRed500.withOpacity(0.2),
          strokeColor: kRed500,
          strokeWidth: 2,
        ),
      );
    });
  }

  // --- B. FAMILY LISTENER (OPTIMIZED) ---
  void _listenToFamilyLocations(String myUid) {
    if (_myFamilyId == null) return;

    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('familyId', isEqualTo: _myFamilyId)
        .snapshots();

    _familyLocationStream = stream.listen((snapshot) {
      _familyMembers = snapshot.docs;
      
      Map<String, Marker> newMarkers = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['location'] != null) {
          final GeoPoint point = data['location'];
          final String name = data['name'] ?? 'Unknown';
          final int battery = data['battery'] ?? 0;
          
          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(point.latitude, point.longitude),
            rotation: 0, 
            icon: BitmapDescriptor.defaultMarkerWithHue(
              doc.id == myUid ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueGreen
            ),
            infoWindow: InfoWindow(title: name, snippet: '🔋 $battery%'),
          );
          newMarkers[doc.id] = marker;
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    });
  }

  // --- C. MY LOCATION BROADCASTER ---
  void _broadcastMyLocation(String uid) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, 
      distanceFilter: 10 
    );

    _myLocationStream = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position position) async {
        
        _myPosition = position;

        // ** FIX: Automatically set Safe Zone on first load **
        if (_circles.isEmpty) {
           _updateSafeZone(LatLng(position.latitude, position.longitude));
        }

        // Camera Follow Logic
        if (_shouldFollowUser) {
           final GoogleMapController controller = await _controller.future;
           controller.animateCamera(
             CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude))
           );
        }

        // Update Firebase
        final batteryLevel = await _battery.batteryLevel;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'location': GeoPoint(position.latitude, position.longitude),
          'battery': batteryLevel,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kBlue500))
          : Stack(
              children: [
                // --- MAP WIDGET ---
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(20.5937, 78.9629), // Default center
                    zoom: 15
                  ),
                  markers: Set<Marker>.of(_markers.values),
                  circles: _circles,   // <--- Safe Zones
                  polygons: _polygons, // <--- Danger Zones
                  zoomControlsEnabled: false,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  trafficEnabled: false, 
                  buildingsEnabled: false,
                  onCameraMoveStarted: () {
                    _shouldFollowUser = false; // Stop auto-follow if user drags
                  },
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                    controller.setMapStyle(_darkMapStyle);
                  },
                ),

                // --- TOP BAR ---
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Live Circle', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
                              if (_myFamilyId == null)
                                const Text('No Family Joined', style: TextStyle(color: Colors.white70, fontSize: 12, shadows: [Shadow(color: Colors.black54, blurRadius: 10)])),
                            ],
                          ),
                          Row(
                            children: [
                              // SAFE ZONE BUTTON
                              _buildGlassIconButton(
                                icon: LucideIcons.shieldCheck,
                                color: kEmerald500,
                                onTap: () {
                                  if (_myPosition != null) {
                                    _updateSafeZone(LatLng(_myPosition!.latitude, _myPosition!.longitude));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Safe Zone moved to your location!")),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              // ADD MEMBER BUTTON
                              _buildGlassIconButton(
                                icon: LucideIcons.userPlus,
                                color: kBlue500,
                                onTap: () {
                                   if (_myFamilyId != null) {
                                    Share.share('Join my Safety Circle! Use Family ID: $_myFamilyId');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- RE-CENTER BUTTON ---
                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).size.height * 0.40,
                  child: _buildFab(
                    _shouldFollowUser ? LucideIcons.navigation : LucideIcons.crosshair, 
                    () async {
                      setState(() => _shouldFollowUser = true);
                      if (_myPosition != null) {
                         final GoogleMapController controller = await _controller.future;
                         controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_myPosition!.latitude, _myPosition!.longitude), 16));
                      }
                  }),
                ),

                // --- BOTTOM SHEET ---
                DraggableScrollableSheet(
                  initialChildSize: 0.35, minChildSize: 0.15, maxChildSize: 0.6,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: kSlate900.withOpacity(0.95),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5))],
                      ),
                      child: Column(
                        children: [
                          Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: kSlate700, borderRadius: BorderRadius.circular(2)))),
                          
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.users, color: kBlue500, size: 20),
                                const SizedBox(width: 8),
                                Text("Members (${_familyMembers.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _familyMembers.length,
                              itemBuilder: (context, index) {
                                final userData = _familyMembers[index].data() as Map<String, dynamic>;
                                final isMe = _familyMembers[index].id == FirebaseAuth.instance.currentUser?.uid;
                                return _buildUserCard(userData, isMe, () => _zoomToUser(_familyMembers[index]));
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  // --- HELPER FUNCTIONS ---

  Future<void> _zoomToUser(QueryDocumentSnapshot userDoc) async {
    setState(() => _shouldFollowUser = false); 
    final data = userDoc.data() as Map<String, dynamic>;
    if (data['location'] != null) {
      final GeoPoint point = data['location'];
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), 16));
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isMe, VoidCallback onTap) {
    final String name = isMe ? 'You' : (user['name'] ?? 'Unknown');
    final String status = user['status'] ?? 'Active';
    final int battery = user['battery'] ?? 0;
    final String? image = user['imageUrl'];
    
    String distanceString = '';
    if (!isMe && _myPosition != null && user['location'] != null) {
      GeoPoint p = user['location'];
      double distanceInMeters = Geolocator.distanceBetween(
        _myPosition!.latitude, _myPosition!.longitude,
        p.latitude, p.longitude
      );
      distanceString = distanceInMeters > 1000 
          ? '${(distanceInMeters / 1000).toStringAsFixed(1)} km' 
          : '${distanceInMeters.toStringAsFixed(0)} m';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? kBlue500.withOpacity(0.1) : kSlate800.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? kBlue500.withOpacity(0.3) : kSlate800),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: kSlate800,
              backgroundImage: image != null ? NetworkImage(image) : null,
              child: image == null ? const Icon(LucideIcons.user, color: kSlate500, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Row(
                    children: [
                      if (distanceString.isNotEmpty) ...[
                         Text(distanceString, style: TextStyle(color: kBlue500, fontSize: 12, fontWeight: FontWeight.bold)),
                         const SizedBox(width: 6),
                         Text("•", style: TextStyle(color: kSlate600)),
                         const SizedBox(width: 6),
                      ],
                      Text(status, style: TextStyle(color: kSlate500, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: kSlate700.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(
                    battery > 20 ? LucideIcons.batteryCharging : LucideIcons.batteryWarning, 
                    size: 14, 
                    color: battery > 20 ? kEmerald500 : kRed500
                  ),
                  const SizedBox(width: 4),
                  Text('$battery%', style: TextStyle(color: battery > 20 ? kEmerald500 : kRed500, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, VoidCallback? onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kSlate900.withOpacity(0.6), shape: BoxShape.circle, border: Border.all(color: kSlate800.withOpacity(0.5))),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildFab(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kSlate800, shape: BoxShape.circle, border: Border.all(color: kSlate700), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Icon(icon, color: kBlue500, size: 24),
      ),
    );
  }
}