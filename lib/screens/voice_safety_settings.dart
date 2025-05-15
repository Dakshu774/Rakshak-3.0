import 'package:flutter/material.dart';
import '../services/ai_safety_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class VoiceSafetySettings extends StatefulWidget {
  const VoiceSafetySettings({Key? key}) : super(key: key);

  @override
  _VoiceSafetySettingsState createState() => _VoiceSafetySettingsState();
}

class _VoiceSafetySettingsState extends State<VoiceSafetySettings> {
  final _aiService = AISafetyService();
  final _parentContactController = TextEditingController();
  final _maxSpeedController = TextEditingController();
  bool _isServiceActive = false;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _statusCheckTimer;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startStatusChecks();
  }

  void _startStatusChecks() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkServiceStatus();
    });
  }

  Future<void> _checkServiceStatus() async {
    try {
      final isInitialized = await _aiService.initialize();
      if (mounted) {
        setState(() {
          _isServiceActive = isInitialized;
        });
      }
    } catch (e) {
      print('Error checking service status: $e');
      if (mounted) {
        setState(() {
          _isServiceActive = false;
          _errorMessage = 'Service status check failed: $e';
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _aiService.initialize();
      
      // Load user data from Firestore
      if (FirebaseAuth.instance.currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _parentContactController.text = data['parent_contact'] ?? '';
              _maxSpeedController.text = (data['max_speed'] ?? 120.0).toString();
              _isServiceActive = true;
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading settings: $e';
          _isLoading = false;
          _isServiceActive = false;
        });
      }
    }
  }

  Future<void> _updateSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (FirebaseAuth.instance.currentUser != null) {
        // Validate input
        final maxSpeed = double.tryParse(_maxSpeedController.text);
        if (maxSpeed == null || maxSpeed <= 0) {
          throw Exception('Invalid speed limit value');
        }

        final parentContact = _parentContactController.text.trim();
        if (parentContact.isEmpty) {
          throw Exception('Parent contact number is required');
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'parent_contact': parentContact,
          'max_speed': maxSpeed,
          'last_updated': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error updating settings: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error updating settings: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startVoiceTraining() async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Voice Training'),
          content: const Text(
            'Please speak naturally for 10 seconds to train the voice model. '
            'This will help improve security.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Training'),
            ),
          ],
        ),
      );

      if (result == true) {
        await _aiService.trainVoiceModel('user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice model trained successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error training voice model: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error training voice model: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
            tooltip: 'Refresh Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Parent Contact',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _parentContactController,
                              decoration: const InputDecoration(
                                hintText: 'Enter parent contact number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a contact number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Speed Limit',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _maxSpeedController,
                              decoration: const InputDecoration(
                                hintText: 'Enter maximum speed (km/h)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.speed),
                                suffixText: 'km/h',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a speed limit';
                                }
                                final speed = double.tryParse(value);
                                if (speed == null || speed <= 0) {
                                  return 'Please enter a valid speed limit';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Service Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _isServiceActive
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _isServiceActive
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isServiceActive
                                      ? 'Safety Service Active'
                                      : 'Safety Service Inactive',
                                  style: TextStyle(
                                    color: _isServiceActive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _checkServiceStatus,
                                  tooltip: 'Check Status',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Voice Recognition', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _startVoiceTraining,
                              icon: const Icon(Icons.mic),
                              label: const Text('Train Voice Model'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Train your voice model to improve security',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _parentContactController.dispose();
    _maxSpeedController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}