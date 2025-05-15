import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class EmergencyService {
  // Firebase Authentication instance to get current user
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Speech recognition instance
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Method to start listening for emergency commands
  void startListeningForEmergency() async {
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(onResult: (val) {
        if (val.recognizedWords == "help" || val.recognizedWords == "emergency") {
          sendEmergencyNotification();
        }
      });
    }
  }

  // Method to send emergency notification with location and user info
  void sendEmergencyNotification() async {
    try {
      // Get the current user
      User? user = _auth.currentUser;
      if (user == null) {
        print("User not logged in");
        return;
      }

      // Get the current location
      Position userLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send the emergency notification to Firebase
      FirebaseDatabase.instance.ref("emergencies").push().set({
        "user": user.uid,
        "location": {
          "latitude": userLocation.latitude,
          "longitude": userLocation.longitude,
        },
        "timestamp": DateTime.now().toIso8601String(),
      });

      print("Emergency notification sent successfully");

    } catch (e) {
      print("Error sending emergency notification: $e");
    }
  }
}

