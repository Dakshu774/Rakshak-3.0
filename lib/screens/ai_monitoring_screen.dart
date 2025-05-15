import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_safety_service.dart';

class AIMonitoringScreen extends StatefulWidget {
  const AIMonitoringScreen({Key? key}) : super(key: key);

  @override
  _AIMonitoringScreenState createState() => _AIMonitoringScreenState();
}

class _AIMonitoringScreenState extends State<AIMonitoringScreen> {
  final _aiService = AISafetyService();
  bool _isLoading = false;
  bool _isListening = false;
  final String _lastCommand = '';
  List<Map<String, dynamic>> _recentAlerts = [];
  Map<String, dynamic> _aiStats = {
    'totalCommands': 0,
    'distressDetected': 0,
    'safetyChecks': 0,
    'lastActive': null,
  };
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadRecentAlerts();
      await _loadAIStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRecentAlerts() async {
    if (!mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final alerts = await FirebaseFirestore.instance
            .collection('alerts')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get();

        if (mounted) {
          setState(() {
            _recentAlerts = alerts.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading alerts: $e');
    }
  }

  Future<void> _loadAIStats() async {
    if (!mounted) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final stats = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('stats')
            .doc('ai_stats')
            .get();

        if (stats.exists && mounted) {
          setState(() {
            _aiStats = stats.data()!;
          });
        }
      }
    } catch (e) {
      print('Error loading AI stats: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling voice recognition: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Safety Monitor'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVoiceControl(),
                  const SizedBox(height: 24),
                  _buildAIStats(),
                  const SizedBox(height: 24),
                  _buildRecentAlerts(),
                ],
              ),
            ),
    );
  }

  Widget _buildVoiceControl() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Voice Command Control',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            if (_lastCommand.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Last Command: $_lastCommand',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAIStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Monitoring Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total Commands', _aiStats['totalCommands']?.toString() ?? '0'),
            _buildStatRow('Distress Detected', _aiStats['distressDetected']?.toString() ?? '0'),
            _buildStatRow('Safety Checks', _aiStats['safetyChecks']?.toString() ?? '0'),
            if (_aiStats['lastActive'] != null)
              _buildStatRow(
                'Last Active',
                _aiStats['lastActive'].toDate().toString(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Alerts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_recentAlerts.isEmpty)
              const Center(
                child: Text('No recent alerts'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentAlerts.length,
                itemBuilder: (context, index) {
                  final alert = _recentAlerts[index];
                  return ListTile(
                    leading: Icon(
                      _getAlertIcon(alert['type']),
                      color: _getAlertColor(alert['type']),
                    ),
                    title: Text(alert['title']),
                    subtitle: Text(alert['message']),
                    trailing: Text(
                      _formatTimestamp(alert['timestamp']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'emergency':
        return Icons.warning;
      case 'distress':
        return Icons.error;
      case 'location':
        return Icons.location_on;
      default:
        return Icons.notification_important;
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'emergency':
        return Colors.red;
      case 'distress':
        return Colors.orange;
      case 'location':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _mounted = false;
    if (_isListening) {
      _aiService.stopListening();
    }
    super.dispose();
  }
} 