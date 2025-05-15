import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class VoiceSafetyService {
  static final VoiceSafetyService _instance = VoiceSafetyService._internal();
  factory VoiceSafetyService() => _instance;
  VoiceSafetyService._internal();

  final SpeechToText _speechToText = SpeechToText();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isListening = false;

  Future<void> initialize() async {
    await _requestPermissions();
    await _initializeNotifications();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.notification.request();
    await Permission.location.request();
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _notifications.initialize(initializationSettings);
  }

  Future<void> startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        _isListening = true;
        await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          localeId: 'en_US',
          cancelOnError: true,
        );
      }
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }

  void _onSpeechResult(result) async {
    if (result.finalResult) {
      final text = result.recognizedWords.toLowerCase();
      
      // Direct voice commands
      if (text.contains('call police')) {
        await _callEmergency('911');
      } else if (text.contains('go home')) {
        await _navigateHome();
      } else if (text.contains('help')) {
        await _sendEmergencyAlert();
      }
    }
  }

  Future<void> _callEmergency(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _navigateHome() async {
    // Get current location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
    
    // Launch Google Maps with home navigation
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${position.latitude},${position.longitude}&travelmode=driving'
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmergencyAlert() async {
    // Send local notification
    const androidDetails = AndroidNotificationDetails(
      'emergency_alerts',
      'Emergency Alerts',
      channelDescription: 'Notifications for emergency alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _notifications.show(
      0,
      'Emergency Alert',
      'Emergency alert triggered by voice command',
      notificationDetails,
    );

    // Get location and send to emergency contacts
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
    
    // Send SMS to emergency contacts
    final message = 'EMERGENCY ALERT! Location: ${position.latitude}, ${position.longitude}';
    final uri = Uri.parse('sms:911?body=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> dispose() async {
    await stopListening();
  }
} 