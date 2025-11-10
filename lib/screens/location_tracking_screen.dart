import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

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

const String _darkMapStyle = '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},{"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},{"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}]';

class LocationTrackingScreen extends StatefulWidget {
  const LocationTrackingScreen({Key? key}) : super(key: key);

  @override
  _LocationTrackingScreenState createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Battery _battery = Battery();
  StreamSubscription<Position>? _positionStream;
  Set<Marker> _markers = {};
  String? _myFamilyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initFamilyAndLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initFamilyAndLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 1. Get my Family ID
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _myFamilyId = doc.data()?['familyId'];
            _isLoading = false;
          });
        }
        // 2. Start sharing MY location
        _startSharingLocation(user.uid);
      } catch (e) {
        print("Error initializing: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _startSharingLocation(String uid) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      final batteryLevel = await _battery.batteryLevel;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'location': GeoPoint(position.latitude, position.longitude),
        'battery': batteryLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
        'status': 'Active',
      }, SetOptions(merge: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Decide which stream to use based on family ID
    final Stream<QuerySnapshot> userStream = (_myFamilyId != null && _myFamilyId!.isNotEmpty)
        ? FirebaseFirestore.instance.collection('users').where('familyId', isEqualTo: _myFamilyId).snapshots()
        : FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, isEqualTo: currentUser?.uid).snapshots();

    return Scaffold(
      backgroundColor: kSlate950,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kBlue500))
          : Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: userStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _updateMarkers(snapshot.data!.docs, currentUser?.uid);
                    }
                    return GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 4.5),
                      markers: _markers,
                      zoomControlsEnabled: false,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                        controller.setMapStyle(_darkMapStyle);
                      },
                    );
                  },
                ),
                // Top Bar
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
                          _buildGlassIconButton(
                            icon: LucideIcons.userPlus,
                            color: kBlue500,
                            onTap: () {
                              if (_myFamilyId != null) {
                                Share.share('Join my Safety Circle! Use Family ID: $_myFamilyId');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set a Family ID in Firebase first!')));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // FABs
                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).size.height * 0.45,
                  child: Column(
                    children: [
                      _buildFab(LucideIcons.navigation, () async {
                         final GoogleMapController controller = await _controller.future;
                         final position = await Geolocator.getCurrentPosition();
                         controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 16));
                      }),
                    ],
                  ),
                ),
                // Bottom Sheet
                DraggableScrollableSheet(
                  initialChildSize: 0.4, minChildSize: 0.2, maxChildSize: 0.8,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: kSlate900.withOpacity(0.9),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5))],
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: userStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kBlue500));
                          final users = snapshot.data!.docs;
                          return Column(
                            children: [
                              Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: kSlate700, borderRadius: BorderRadius.circular(2)))),
                              if (users.isEmpty || _myFamilyId == null)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text("You are alone! Add a 'familyId' in Firebase to see others.", style: TextStyle(color: kSlate400), textAlign: TextAlign.center),
                                ),
                              Expanded(
                                child: ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final userData = users[index].data() as Map<String, dynamic>;
                                    final isMe = users[index].id == currentUser?.uid;
                                    return _buildUserCard(userData, isMe, () => _zoomToUser(users[index]));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  void _updateMarkers(List<QueryDocumentSnapshot> userDocs, String? currentUserId) {
    final newMarkers = userDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['location'] == null) return null;
      final GeoPoint point = data['location'];
      return Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(point.latitude, point.longitude),
        infoWindow: InfoWindow(title: data['name'] ?? 'Unknown'),
        icon: BitmapDescriptor.defaultMarkerWithHue(doc.id == currentUserId ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueGreen),
      );
    }).whereType<Marker>().toSet();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _markers = newMarkers);
    });
  }

  Future<void> _zoomToUser(QueryDocumentSnapshot userDoc) async {
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
                  const SizedBox(height: 2),
                  Text(status, style: TextStyle(color: isMe ? kBlue500 : kSlate500, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: kSlate700.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(LucideIcons.batteryCharging, size: 14, color: battery > 20 ? kEmerald500 : kRed500),
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