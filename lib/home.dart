import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/ai_safety_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AISafetyService _aiService = AISafetyService();
  bool _isListening = false;
  bool _isMonitoring = true;
  final bool _isInSafeZone = true;
  double _currentSpeed = 0.0;
  Timer? _updateTimer;
  final List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _aiService.initialize();
      _startMonitoringUpdates();
    } catch (e) {
      print('Error initializing service: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error initializing safety service. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startMonitoringUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        try {
          final position = await Geolocator.getCurrentPosition();
          setState(() {
            _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
          });
        } catch (e) {
          print('Error updating location: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _aiService.dispose();
    super.dispose();
  }

  Future<void> _handleEmergencyCall() async {
    try {
      final uri = Uri.parse('tel:911');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch emergency call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error making emergency call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error making emergency call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.pinkAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI Safety Assistant',
                        style: AppTheme.titleLarge.copyWith(color: Colors.white),
                      ),
                      Text(
                        'Automatic Monitoring Active',
                        style: AppTheme.bodyLarge.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Emergency Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildEmergencyButton(),
            ),
          ),

          // Safety Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSafetyStatus(),
            ),
          ),

          // Monitoring Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMonitoringStatus(),
            ),
          ),

          // Today's Schedule
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTodaysSchedule(),
            ),
          ),

          // Voice Commands
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice Commands', style: AppTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildVoiceCommands(),
                ],
              ),
            ),
          ),

          // Recent Activity
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Activity', style: AppTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildRecentActivity(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            if (_isListening) {
              await _aiService.stopListening();
            } else {
              await _aiService.startListening();
            }
            if (mounted) {
              setState(() {
                _isListening = !_isListening;
              });
            }
          } catch (e) {
            print('Error toggling voice recognition: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error with voice recognition'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        backgroundColor: _isListening ? Colors.red : Colors.blue,
        child: Icon(_isListening ? Icons.mic_off : Icons.mic, color: Colors.white),
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: AppTheme.emergencyGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleEmergencyCall,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emergency, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Text(
                  'Emergency Help',
                  style: AppTheme.titleLarge.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safety Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildSafetyItem(
              'Safe Zone',
              _isInSafeZone ? 'In Safe Zone' : 'Outside Safe Zone',
              _isInSafeZone ? Icons.check_circle : Icons.warning,
              _isInSafeZone ? Colors.green : Colors.orange,
            ),
            _buildSafetyItem(
              'Speed',
              '${_currentSpeed.toStringAsFixed(1)} km/h',
              Icons.speed,
              _currentSpeed > 120 ? Colors.red : Colors.green,
            ),
            _buildSafetyItem(
              'Monitoring',
              'Active',
              Icons.security,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyItem(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monitoring Status', style: Theme.of(context).textTheme.titleMedium),
                Switch(
                  value: _isMonitoring,
                  onChanged: (value) {
                    setState(() {
                      _isMonitoring = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusItem('Location Tracking', Icons.location_on, 'Active'),
            _buildStatusItem('Schedule Monitoring', Icons.schedule, 'Active'),
            _buildStatusItem('Parent Alerts', Icons.notifications, 'Enabled'),
            _buildStatusItem('Safe Zones', Icons.security, 'Active'),
            _buildStatusItem('Speed Monitoring', Icons.speed, 'Active'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, IconData icon, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Text(title),
          const Spacer(),
          Text(
            status,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSchedule() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Schedule', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildScheduleItem('8:00 AM', 'School', Icons.school),
            _buildScheduleItem('12:00 PM', 'Lunch Break', Icons.lunch_dining),
            _buildScheduleItem('3:00 PM', 'Sports Practice', Icons.sports),
            _buildScheduleItem('6:00 PM', 'Homework', Icons.book),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String time, String activity, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppTheme.primaryColor),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(activity),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCommands() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Commands',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildCommandCard('Emergency', 'Say "help" or "emergency"', Icons.emergency),
        const SizedBox(height: 8),
        _buildCommandCard('Police', 'Say "call police"', Icons.local_police),
        const SizedBox(height: 8),
        _buildCommandCard('Ambulance', 'Say "ambulance"', Icons.medical_services),
        const SizedBox(height: 8),
        _buildCommandCard('Navigation', 'Say "go home" or "lost"', Icons.navigation),
        const SizedBox(height: 8),
        _buildCommandCard('Location', 'Say "where am I"', Icons.location_on),
        const SizedBox(height: 8),
        _buildCommandCard('Safe Zone', 'Say "safe zone"', Icons.security),
        const SizedBox(height: 8),
        _buildCommandCard('Speed Check', 'Say "speed"', Icons.speed),
        const SizedBox(height: 8),
        _buildCommandCard('Status', 'Say "status"', Icons.info),
      ],
    );
  }

  Widget _buildCommandCard(String title, String command, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        subtitle: Text(command),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.notifications),
            ),
            title: Text('Voice Command ${index + 1}'),
            subtitle: const Text('2 hours ago'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}