import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Auth & Core
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'emergency_listening_page.dart';
import 'consultancy_tab.dart';

// Standard Features
import 'screens/event_planner_screen.dart';
import 'screens/location_tracking_screen.dart'; 
import 'screens/voice_safety_settings.dart'; 

// AI & Advanced Safety Features
import 'screens/ai_safety_hub.dart';
import 'screens/ai_chatbot_screen.dart';
import 'screens/guardian_lens_screen.dart';
import 'screens/fake_call_screen.dart';// ✅ Added/ ✅ Added

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load API Keys
    await dotenv.load(fileName: ".env"); 
    
    await Firebase.initializeApp();
    print('✅ Firebase & Environment Initialized successfully!');
    
    runApp(const MyApp());
  } catch (e) {
    print("🔥 Error initializing app: $e");
    runApp(MaterialApp(
      home: ErrorScreen(message: 'Error initializing app: $e'),
    ));
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Error")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rakshak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
      
      // ROUTE TABLE
      onGenerateRoute: (settings) {
        switch (settings.name) {
          // Auth
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());
          
          // Core
          case '/home':
            return MaterialPageRoute(builder: (_) => const Home());
          
          // Core Features
          case '/emergency':
            return MaterialPageRoute(builder: (_) => const EmergencyListeningPage());
          case '/consultancy':
             return MaterialPageRoute(builder: (_) => const ConsultancyTab());
          case '/event_planner':
            return MaterialPageRoute(builder: (_) => const EventPlannerScreen());
          case '/location_tracking':
            return MaterialPageRoute(builder: (_) => const LocationTrackingScreen());
          
          // AI Features
          case '/ai_hub':
            return MaterialPageRoute(builder: (_) => const AISafetyHub());
          case '/ai_chatbot':
            return MaterialPageRoute(builder: (_) => const AIChatbotScreen());
          case '/guardian_lens':
            return MaterialPageRoute(builder: (_) => const GuardianLensScreen());
          case '/fake_call':
            return MaterialPageRoute(builder: (_) => const FakeCallScreen());

          default:
            return _errorRoute();
        }
      },
    );
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Page not found")),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return ErrorScreen(message: 'Authentication error: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          return const Home();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}