import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ConsultationService {
  // Function to send consultation messages to Firebase
  Future<void> sendConsultationMessage(String message) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user logged in");
        return;
      }

      await FirebaseDatabase.instance.ref("consultations/${user.uid}").push().set({
        "message": message,
        "timestamp": DateTime.now().toIso8601String(),
      });

      print("Consultation message sent successfully");
    } catch (e) {
      print("Error sending consultation message: $e");
    }
  }
}
