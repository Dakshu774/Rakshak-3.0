import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; // Add this import at the top
import '../services/ai_safety_service.dart';
import 'event_planner_screen.dart';
import 'location_tracking_screen.dart';
import 'ai_monitoring_screen.dart';
import 'voice_safety_settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _aiService = AISafetyService();
  bool _isLoading = false;
  Timer? _periodicTimer; // Add this line
  final Map<String, dynamic> _userStatus = {
    'isSafe': true,
    'currentLocation': null,
    'nextEvent': null,
    'aiStatus': 'Active',
  };

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
    _startPeriodicUpdates();
  }

  Future<void> _loadUserStatus() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final nextEvent = await _getNextEvent();
      
      setState(() {
        _userStatus['currentLocation'] = position;
        _userStatus['nextEvent'] = nextEvent;
      });
    } catch (e) {
      print('Error loading user status: $e');
    }
    setState(() => _isLoading = false);
  }

  void _startPeriodicUpdates() {
    _periodicTimer?.cancel(); // Cancel any existing timer
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _loadUserStatus();
    });
  }

  Future<Map<String, dynamic>?> _getNextEvent() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        final now = DateTime.now();
        final events = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('events')
            .where('startTime', isGreaterThan: now)
            .orderBy('startTime')
            .limit(1)
            .get();

        if (events.docs.isNotEmpty) {
          return events.docs.first.data();
        }
      }
    } catch (e) {
      print('Error getting next event: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSafetyStatus(),
                        const SizedBox(height: 24),
                        _buildNextEvent(),
                        const SizedBox(height: 24),
                        _buildFeatureGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('AI Safety Assistant'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.7),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.security,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyStatus() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Safety Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _userStatus['isSafe'] ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _userStatus['isSafe'] ? 'Safe' : 'Alert',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _userStatus['currentLocation'] != null
                        ? 'Location: ${_userStatus['currentLocation'].latitude.toStringAsFixed(4)}, ${_userStatus['currentLocation'].longitude.toStringAsFixed(4)}'
                        : 'Location: Loading...',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Status: ${_userStatus['aiStatus']}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextEvent() {
    final nextEvent = _userStatus['nextEvent'];
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Event',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (nextEvent != null) ...[
              Row(
                children: [
                  const Icon(Icons.event, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nextEvent['title'] ?? 'Untitled Event',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Time: ${_formatDateTime(nextEvent['startTime'])}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location: ${nextEvent['location'] ?? 'No location specified'}',
                    ),
                  ),
                ],
              ),
            ] else
              const Center(
                child: Text('No upcoming events'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildFeatureCard(
          'Event Planner',
          Icons.event,
          Colors.blue,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EventPlannerScreen(),
            ),
          ),
        ),
        _buildFeatureCard(
          'Location Tracking',
          Icons.location_on,
          Colors.green,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationTrackingScreen(),
            ),
          ),
        ),
        _buildFeatureCard(
          'AI Monitoring',
          Icons.psychology,
          Colors.purple,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIMonitoringScreen(),
            ),
          ),
        ),
        _buildFeatureCard(
          'Safety Settings',
          Icons.settings,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VoiceSafetySettings(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'No time specified';
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _periodicTimer?.cancel(); // Cancel the timer on dispose
    super.dispose();
  }
}