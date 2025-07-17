import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'dart:async';
import 'dart:math';

class AISafetyService {
  static final AISafetyService _instance = AISafetyService._internal();
  factory AISafetyService() => _instance;

  final SpeechToText _speechToText = SpeechToText();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LanguageIdentifier _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
  bool _isListening = false;
  Timer? _monitoringTimer;
  Timer? _timetableCheckTimer;
  Timer? _safetyCheckTimer;
  String? _parentContact;
  Map<String, dynamic>? _userTimetable;
  Position? _lastKnownPosition;
  DateTime? _lastActivityTime;
  List<String> _safeZones = [];
  List<String> _restrictedZones = [];
  double _maxSpeed = 120.0; // km/h
  bool _isInSafeZone = true;
  final int _consecutiveDeviations = 0;
  bool _isInitialized = false;
  Map<String, dynamic> _settings = {
    'autoCallEnabled': true,
    'distressDetectionEnabled': true,
    'locationSharingEnabled': true,
    'triggerWord': 'help',
    'sensitivityLevel': 'high',
    'strictVoiceAuth': false,
  };
  late final Map<String, Function> _commandPatterns;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Voice identification properties
  final Map<String, List<double>> _voiceProfiles = {};
  List<double>? _lastVoiceFeatures;
  bool _isVoiceModelTrained = false;
  final double _voiceMatchThreshold = 0.85;

  // Routine analysis properties
  final Map<String, Map<String, dynamic>> _userRoutines = {};
  final List<Map<String, dynamic>> _routineDeviations = [];
  final int _maxDeviationsBeforeAlert = 3;

  AISafetyService._internal() {
    _commandPatterns = {
      'emergency': _handleEmergency,
      'danger': _handleEmergency,
      'help': _handleEmergency,
      'police': _handlePolice,
      'ambulance': _handleAmbulance,
      'fire': _handleFire,
      'home': _handleNavigation,
      'lost': _handleNavigation,
      'location': _handleLocation,
      'unsafe': _handleUnsafe,
      'suspicious': _handleSuspicious,
      'schedule': _handleSchedule,
      'timetable': _handleTimetable,
      'safe': _handleSafeZone,
      'restricted': _handleRestrictedZone,
      'speed': _handleSpeedCheck,
      'status': _handleStatus,
      'check': _handleSafetyCheck,
      'alert': _handleAlert,
    };
  }

  bool _isTestMode = false;
  String? _triggerWord;
  List<String> _emergencyContacts = [];
  Map<String, String> _contactTypes = {}; // Maps contact to type (email, phone, etc.)
  bool _enableSMS = true;
  bool _enableEmail = true;
  bool _enablePushNotifications = true;
  String? _smtpServer;
  String? _smtpUsername;
  String? _smtpPassword;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get initial position
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Start location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        _lastKnownPosition = position;
        _updateLocationInFirestore(position);
      });

      await _loadSettings();
      await _initializeNotifications();
      await _loadUserData();
      _startAutomaticMonitoring();
      _startTimetableTracking();
      _startSafetyChecks();
      _startEventMonitoring();
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing AISafetyService: $e');
      return false;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _triggerWord = prefs.getString('trigger_word')?.toLowerCase() ?? 'help';
    _emergencyContacts = prefs.getStringList('emergency_contacts') ?? [];
    final contactTypesString = prefs.getString('contact_types');
    if (contactTypesString != null) {
      _contactTypes = Map<String, String>.from(
        contactTypesString.split(',').fold<Map<String, String>>({}, (map, element) {
          final parts = element.split(':');
          if (parts.length == 2) {
            map[parts[0]] = parts[1];
          }
          return map;
        })
      );
    }
    _enableSMS = prefs.getBool('enable_sms') ?? true;
    _enableEmail = prefs.getBool('enable_email') ?? true;
    _enablePushNotifications = prefs.getBool('enable_push') ?? true;
    _smtpServer = prefs.getString('smtp_server');
    _smtpUsername = prefs.getString('smtp_username');
    _smtpPassword = prefs.getString('smtp_password');
  }

  Future<void> _initializeNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _notifications.initialize(initSettings);
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      if (_auth.currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          _parentContact = data['parent_contact'];
          _userTimetable = data['timetable'];
          _safeZones = List<String>.from(data['safe_zones'] ?? []);
          _restrictedZones = List<String>.from(data['restricted_zones'] ?? []);
          _maxSpeed = data['max_speed']?.toDouble() ?? 120.0;
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _startAutomaticMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        await _checkUserStatus();
      } catch (e) {
        print('Error in automatic monitoring: $e');
      }
    });
  }

  void _startTimetableTracking() {
    _timetableCheckTimer?.cancel();
    _timetableCheckTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      try {
        await _checkTimetableCompliance();
      } catch (e) {
        print('Error in timetable tracking: $e');
      }
    });
  }

  void _startSafetyChecks() {
    _safetyCheckTimer?.cancel();
    _safetyCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        await _performSafetyChecks();
      } catch (e) {
        print('Error in safety checks: $e');
      }
    });
  }

  Future<void> _checkUserStatus() async {
    try {
      final currentLocation = await Geolocator.getCurrentPosition();
      final now = DateTime.now();

      // Check if user is moving
      if (_lastKnownPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          currentLocation.latitude,
          currentLocation.longitude,
        );

        // If user hasn't moved more than 100 meters in 30 minutes
        if (distance < 100 && _lastActivityTime != null) {
          final timeSinceLastActivity = now.difference(_lastActivityTime!);
          if (timeSinceLastActivity.inMinutes > 30) {
            await _sendParentAlert('Inactivity Alert', 
              'User has been inactive for ${timeSinceLastActivity.inMinutes} minutes at location: ${currentLocation.latitude}, ${currentLocation.longitude}');
          }
        }
      }

      _lastKnownPosition = currentLocation;
      _lastActivityTime = now;

    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  Future<void> _checkTimetableCompliance() async {
    if (_userTimetable == null) return;

    final now = DateTime.now();
    final currentDay = now.weekday.toString();
    final currentTime = '${now.hour}:${now.minute}';

    if (_userTimetable!.containsKey(currentDay)) {
      final daySchedule = _userTimetable![currentDay] as Map<String, dynamic>;
      final scheduledActivity = daySchedule[currentTime];

      if (scheduledActivity != null) {
        // Check if user is at the expected location
        final expectedLocation = scheduledActivity['location'];
        final currentLocation = await Geolocator.getCurrentPosition();

        final distance = Geolocator.distanceBetween(
          expectedLocation['latitude'],
          expectedLocation['longitude'],
          currentLocation.latitude,
          currentLocation.longitude,
        );

        // If user is more than 500 meters from expected location
        if (distance > 500) {
          await _sendParentAlert('Schedule Deviation',
            'User is not at the expected location for scheduled activity: $scheduledActivity');
        }
      }
    }
  }

  Future<void> _performSafetyChecks() async {
    try {
      final currentLocation = await Geolocator.getCurrentPosition();
      final speed = currentLocation.speed * 3.6; // Convert m/s to km/h

      // Check speed
      if (speed > _maxSpeed) {
        await _sendParentAlert(
          'Speed Alert',
          'User is traveling at ${speed.toStringAsFixed(1)} km/h, exceeding the limit of $_maxSpeed km/h'
        );
      }

      // Check safe zones
      final isInSafeZone = await _checkSafeZone(currentLocation);
      if (!isInSafeZone && _isInSafeZone) {
        await _sendParentAlert(
          'Safe Zone Alert',
          'User has left a safe zone'
        );
      }
      _isInSafeZone = isInSafeZone;

      // Check restricted zones
      if (await _checkRestrictedZone(currentLocation)) {
        await _sendParentAlert(
          'Restricted Zone Alert',
          'User has entered a restricted zone'
        );
      }

    } catch (e) {
      print('Error performing safety checks: $e');
    }
  }

  Future<bool> _checkSafeZone(Position position) async {
    for (var zone in _safeZones) {
      final zoneData = await _firestore.collection('safe_zones').doc(zone).get();
      if (zoneData.exists) {
        final data = zoneData.data() as Map<String, dynamic>;
        final zoneLocation = data['location'] as GeoPoint;
        final radius = data['radius'] as double;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          zoneLocation.latitude,
          zoneLocation.longitude,
        );

        if (distance <= radius) {
          return true;
        }
      }
    }
    return false;
  }

  Future<bool> _checkRestrictedZone(Position position) async {
    for (var zone in _restrictedZones) {
      final zoneData = await _firestore.collection('restricted_zones').doc(zone).get();
      if (zoneData.exists) {
        final data = zoneData.data() as Map<String, dynamic>;
        final zoneLocation = data['location'] as GeoPoint;
        final radius = data['radius'] as double;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          zoneLocation.latitude,
          zoneLocation.longitude,
        );

        if (distance <= radius) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _handleSafeZone(String text) async {
    final currentLocation = await Geolocator.getCurrentPosition();
    final isInSafeZone = await _checkSafeZone(currentLocation);
    await _sendNotification(
      'Safe Zone Status',
      isInSafeZone ? 'You are in a safe zone' : 'You are not in a safe zone'
    );
  }

  Future<void> _handleRestrictedZone(String text) async {
    final currentLocation = await Geolocator.getCurrentPosition();
    final isInRestrictedZone = await _checkRestrictedZone(currentLocation);
    await _sendNotification(
      'Restricted Zone Status',
      isInRestrictedZone ? 'You are in a restricted zone' : 'You are not in a restricted zone'
    );
  }

  Future<void> _handleSpeedCheck(String text) async {
    final currentLocation = await Geolocator.getCurrentPosition();
    final speed = currentLocation.speed * 3.6; // Convert m/s to km/h
    await _sendNotification(
      'Current Speed',
      'You are traveling at ${speed.toStringAsFixed(1)} km/h'
    );
  }

  Future<void> _handleStatus(String text) async {
    final currentLocation = await Geolocator.getCurrentPosition();
    final speed = currentLocation.speed * 3.6;
    final isInSafeZone = await _checkSafeZone(currentLocation);
    final isInRestrictedZone = await _checkRestrictedZone(currentLocation);

    final status = '''
Current Status:
- Speed: ${speed.toStringAsFixed(1)} km/h
- Safe Zone: ${isInSafeZone ? 'Yes' : 'No'}
- Restricted Zone: ${isInRestrictedZone ? 'Yes' : 'No'}
- Last Activity: ${_lastActivityTime?.toString() ?? 'Unknown'}
''';

    await _sendNotification('Safety Status', status);
  }

  Future<void> _handleSafetyCheck(String text) async {
    await _performSafetyChecks();
    await _sendNotification('Safety Check', 'Safety check completed');
  }

  Future<void> _handleAlert(String text) async {
    final currentLocation = await Geolocator.getCurrentPosition();
    await _sendParentAlert(
      'Manual Alert',
      'User has requested an alert. Current location: ${currentLocation.latitude}, ${currentLocation.longitude}'
    );
  }

  Future<void> _sendParentAlert(String title, String message) async {
    try {
      if (_parentContact != null) {
        // Send SMS to parent
        final uri = Uri.parse('sms:$_parentContact?body=$message');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }

        // Send notification to user
        await _sendNotification(title, message);

        // Log alert in Firestore
        if (_auth.currentUser != null) {
          await _firestore.collection('alerts').add({
            'userId': _auth.currentUser!.uid,
            'title': title,
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'location': GeoPoint(
              _lastKnownPosition?.latitude ?? 0,
              _lastKnownPosition?.longitude ?? 0
            ),
          });
        }
      }
    } catch (e) {
      print('Error sending parent alert: $e');
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }
    _isListening = true;
  }

  Future<void> stopListening() async {
    _isListening = false;
  }

  void _onSpeechResult(result) async {
    if (result.finalResult) {
      try {
        final text = result.recognizedWords.toLowerCase();
        
        // Detect language
        final language = await _languageIdentifier.identifyLanguage(text);
        if (language != 'en') {
          await _handleNonEnglishSpeech(text, language);
          return;
        }

        // Process command with context
        await _processCommand(text);
      } catch (e) {
        print('Error processing speech result: $e');
      }
    }
  }

  Future<void> _processCommand(String text) async {
    try {
      final voiceFeatures = await _extractVoiceFeatures();
      if (voiceFeatures != null) {
        final isAuthorized = await isAuthorizedVoice(voiceFeatures);
        
        if (!isAuthorized && _settings['strictVoiceAuth'] == true) {
          print('Unauthorized voice detected');
          await _handleUnauthorizedVoice();
          return;
        }
      }
      
      // Check for emergency keywords
      for (var pattern in _commandPatterns.keys) {
        if (text.contains(pattern)) {
          await _commandPatterns[pattern]!(text);
          return;
        }
      }

      // If no specific pattern is found, analyze context
      await _analyzeContext(text);
    } catch (e) {
      print('Error processing command: $e');
    }
  }

  Future<void> _analyzeContext(String text) async {
    // Get current location for context
    Position position = await Geolocator.getCurrentPosition();
    
    // Log the interaction for AI learning
    await _logInteraction(text, position);
    
    // Check for emergency indicators in the text
    if (_containsEmergencyIndicators(text)) {
      await _handleEmergency(text);
    }
  }

  bool _containsEmergencyIndicators(String text) {
    final emergencyWords = ['scared', 'afraid', 'dangerous', 'unsafe', 'threat'];
    return emergencyWords.any((word) => text.contains(word));
  }

  Future<void> _handleEmergency(String text) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      
      // Send emergency notification
      await _sendNotification(
        'Emergency Alert',
        'Emergency situation detected. Location shared with emergency services.',
      );

      // Log emergency in Firestore
      await _logEmergency(text, position);
      
      // Call emergency services
      await _callEmergency('911');
    } catch (e) {
      print('Error handling emergency: $e');
    }
  }

  Future<void> _handlePolice(String text) async {
    try {
      await _callEmergency('911');
      await _sendNotification('Police Called', 'Emergency services have been notified.');
    } catch (e) {
      print('Error handling police call: $e');
    }
  }

  Future<void> _handleAmbulance(String text) async {
    try {
      await _callEmergency('911');
      await _sendNotification('Ambulance Called', 'Medical emergency services have been notified.');
    } catch (e) {
      print('Error handling ambulance call: $e');
    }
  }

  Future<void> _handleFire(String text) async {
    try {
      await _callEmergency('911');
      await _sendNotification('Fire Department Called', 'Fire emergency services have been notified.');
    } catch (e) {
      print('Error handling fire call: $e');
    }
  }

  Future<void> _handleNavigation(String text) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${position.latitude},${position.longitude}&travelmode=driving'
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      print('Error handling navigation: $e');
    }
  }

  Future<void> _handleLocation(String text) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      await _sendNotification(
        'Location Shared',
        'Your current location: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('Error handling location: $e');
    }
  }

  Future<void> _handleUnsafe(String text) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      await _logIncident('unsafe_situation', text, position);
      await _sendNotification(
        'Safety Alert',
        'Unsafe situation detected. Location and details have been logged.',
      );
    } catch (e) {
      print('Error handling unsafe situation: $e');
    }
  }

  Future<void> _handleSuspicious(String text) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      await _logIncident('suspicious_activity', text, position);
      await _sendNotification(
        'Suspicious Activity',
        'Suspicious activity reported. Details have been logged.',
      );
    } catch (e) {
      print('Error handling suspicious activity: $e');
    }
  }

  Future<void> _handleNonEnglishSpeech(String text, String language) async {
    try {
      await _sendNotification(
        'Language Detected',
        'Detected $language. Please speak in English for emergency services.',
      );
    } catch (e) {
      print('Error handling non-English speech: $e');
    }
  }

  Future<void> _sendNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'safety_alerts',
        'Safety Alerts',
        channelDescription: 'Notifications for safety alerts',
        importance: Importance.high,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _callEmergency(String number) async {
    try {
      final uri = Uri.parse('tel:$number');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      print('Error calling emergency: $e');
    }
  }

  Future<void> _logInteraction(String text, Position position) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore.collection('interactions').add({
          'userId': _auth.currentUser!.uid,
          'text': text,
          'location': GeoPoint(position.latitude, position.longitude),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error logging interaction: $e');
    }
  }

  Future<void> _logEmergency(String text, Position position) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore.collection('emergencies').add({
          'userId': _auth.currentUser!.uid,
          'text': text,
          'location': GeoPoint(position.latitude, position.longitude),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'active',
        });
      }
    } catch (e) {
      print('Error logging emergency: $e');
    }
  }

  Future<void> _logIncident(String type, String text, Position position) async {
    try {
      if (_auth.currentUser != null) {
        await _firestore.collection('incidents').add({
          'userId': _auth.currentUser!.uid,
          'type': type,
          'text': text,
          'location': GeoPoint(position.latitude, position.longitude),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'active',
        });
      }
    } catch (e) {
      print('Error logging incident: $e');
    }
  }

  void setTestMode(bool enabled) {
    _isTestMode = enabled;
    print(_isTestMode ? '🧪 Test mode enabled' : '✅ Test mode disabled');
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    _timetableCheckTimer?.cancel();
    _safetyCheckTimer?.cancel();
    stopListening();
    _languageIdentifier.close();
    _positionStreamSubscription?.cancel();
  }

  Future<void> _handleSchedule(String text) async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday.toString();
      
      if (_userTimetable != null && _userTimetable!.containsKey(currentDay)) {
        final daySchedule = _userTimetable![currentDay] as Map<String, dynamic>;
        final nextActivity = _findNextActivity(daySchedule, now);
        
        if (nextActivity != null) {
          await _sendNotification('Next Activity', 
            'Your next activity is: ${nextActivity['name']} at ${nextActivity['time']}');
        }
      }
    } catch (e) {
      print('Error handling schedule: $e');
    }
  }

  Future<void> _handleTimetable(String text) async {
    try {
      if (_userTimetable != null) {
        final now = DateTime.now();
        final currentDay = now.weekday.toString();
        
        if (_userTimetable!.containsKey(currentDay)) {
          final daySchedule = _userTimetable![currentDay] as Map<String, dynamic>;
          final scheduleMessage = _formatSchedule(daySchedule);
          
          await _sendNotification('Today\'s Schedule', scheduleMessage);
        }
      }
    } catch (e) {
      print('Error handling timetable: $e');
    }
  }

  String _formatSchedule(Map<String, dynamic> schedule) {
    try {
      final activities = schedule.entries
          .map((e) => '${e.key}: ${e.value['name']}')
          .join('\n');
      return activities;
    } catch (e) {
      print('Error formatting schedule: $e');
      return 'Error loading schedule';
    }
  }

  Map<String, dynamic>? _findNextActivity(Map<String, dynamic> schedule, DateTime now) {
    try {
      final currentTime = '${now.hour}:${now.minute}';
      final sortedTimes = schedule.keys.toList()..sort();
      
      for (var time in sortedTimes) {
        if (time.compareTo(currentTime) > 0) {
          return schedule[time];
        }
      }
      return null;
    } catch (e) {
      print('Error finding next activity: $e');
      return null;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      _settings = settings;
      
      // Update Firestore settings
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('settings')
            .doc('ai_settings')
            .set(settings);
      }

      // Update local settings
      _triggerWord = settings['triggerWord']?.toLowerCase() ?? 'help';
      
      // Restart monitoring with new settings
      _startAutomaticMonitoring();
      _startTimetableTracking();
      _startSafetyChecks();
      
      print('Settings updated successfully');
    } catch (e) {
      print('Error updating settings: $e');
      rethrow;
    }
  }

  Future<void> _checkEventAttendance() async {
    try {
      if (_auth.currentUser != null) {
        final now = DateTime.now();
        final events = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('events')
            .where('date', isGreaterThan: now)
            .where('date', isLessThan: now.add(const Duration(minutes: 30)))
            .get();

        for (var event in events.docs) {
          final eventData = event.data();
          if (!eventData['attendanceConfirmed'] && eventData['location'] != null) {
            // Check if user is at event location
            final position = await Geolocator.getCurrentPosition();
            final eventLocation = eventData['location'] as GeoPoint;
            final distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              eventLocation.latitude,
              eventLocation.longitude,
            );

            if (distance > 100) { // If more than 100 meters away
              await _handleMissedEvent(event.id, eventData);
            }
          }
        }
      }
    } catch (e) {
      print('Error checking event attendance: $e');
    }
  }

  Future<void> _handleMissedEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      // Update event status
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('events')
          .doc(eventId)
          .update({'attendanceConfirmed': false});

      // Send notification
      await _showNotification(
        'Event Alert',
        'You have an upcoming event: ${eventData['title']}',
      );

      // If auto emergency call is enabled, notify contacts
      if (_settings['autoCallEnabled']) {
        await _notifyEmergencyContacts(
          'Missed Event Alert',
          'User has not arrived at scheduled event: ${eventData['title']}',
        );
      }
    } catch (e) {
      print('Error handling missed event: $e');
    }
  }

  Future<void> _notifyEmergencyContacts(String title, String message) async {
    try {
      if (_auth.currentUser != null) {
        final contacts = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('contacts')
            .get();

        for (var contact in contacts.docs) {
          final contactData = contact.data();
          if (contactData['phone'] != null) {
            // Send SMS
            final url = Uri.parse('sms:${contactData['phone']}?body=$message');
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            }

            // Make phone call if it's a primary contact
            if (contactData['isPrimary'] == true) {
              final callUrl = Uri.parse('tel:${contactData['phone']}');
              if (await canLaunchUrl(callUrl)) {
                await launchUrl(callUrl);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error notifying contacts: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_safety_channel',
      'AI Safety Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  void _startEventMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _checkEventAttendance();
    });
  }

  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'lastKnownLocation': GeoPoint(
            position.latitude,
            position.longitude,
          ),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating location in Firestore: $e');
    }
  }

  Future<void> trainVoiceModel(String speakerName) async {
    try {
      final features = await _extractVoiceFeatures();
      if (features != null) {
        _voiceProfiles[speakerName] = features;
        _isVoiceModelTrained = true;
        
        // Store voice profile in Firestore
        if (_auth.currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('voice_profiles')
              .doc(speakerName)
              .set({
            'features': features,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error training voice model: $e');
      rethrow;
    }
  }

  Future<List<double>?> _extractVoiceFeatures() async {
    // Simplified voice feature extraction (in real app, use proper voice processing)
    // This is a placeholder implementation
    return List.generate(128, (i) => i.toDouble());
  }

  Future<bool> isAuthorizedVoice(List<double> voiceFeatures) async {
    if (!_isVoiceModelTrained) return false;
    
    for (var profile in _voiceProfiles.values) {
      double similarity = _calculateVoiceSimilarity(voiceFeatures, profile);
      if (similarity >= _voiceMatchThreshold) {
        return true;
      }
    }
    return false;
  }

  double _calculateVoiceSimilarity(List<double> features1, List<double> features2) {
    // Simplified cosine similarity calculation
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < features1.length; i++) {
      dotProduct += features1[i] * features2[i];
      norm1 += features1[i] * features1[i];
      norm2 += features2[i] * features2[i];
    }
    
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  Future<void> analyzeRoutine(Position currentLocation) async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday.toString();
      final currentTime = '${now.hour}:${now.minute}';

      if (_userRoutines.containsKey(currentDay)) {
        final expectedLocation = _userRoutines[currentDay]?[currentTime]?['location'];
        if (expectedLocation != null) {
          final distance = Geolocator.distanceBetween(
            currentLocation.latitude,
            currentLocation.longitude,
            expectedLocation['latitude'],
            expectedLocation['longitude'],
          );

          if (distance > 500) { // More than 500 meters from expected location
            _routineDeviations.add({
              'timestamp': now,
              'expected_location': expectedLocation,
              'actual_location': {
                'latitude': currentLocation.latitude,
                'longitude': currentLocation.longitude,
              },
            });

            if (_routineDeviations.length >= _maxDeviationsBeforeAlert) {
              await _handleRoutineDeviation();
            }
          }
        }
      }
    } catch (e) {
      print('Error analyzing routine: $e');
    }
  }

  Future<void> _handleRoutineDeviation() async {
    try {
      // Notify emergency contacts
      if (_auth.currentUser != null) {
        const message = 'Routine deviation detected. User has deviated from expected schedule multiple times.';
        await _sendEmergencyNotification(message);
        
        // Log deviation
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('routine_deviations')
            .add({
          'deviations': _routineDeviations,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        _routineDeviations.clear();
      }
    } catch (e) {
      print('Error handling routine deviation: $e');
    }
  }

  Future<void> _handleUnauthorizedVoice() async {
    try {
      await _sendEmergencyNotification(
        'Unauthorized voice detected using trigger words. Possible security concern.'
      );
    } catch (e) {
      print('Error handling unauthorized voice: $e');
    }
  }

  Future<void> _sendEmergencyNotification(String message) async {
    try {
      await _sendNotification('Emergency Alert', message);
    } catch (e) {
      print('Error sending emergency notification: $e');
    }
  }
}