import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'emergency_listening_page.dart';
import 'consultancy_tab.dart';
import 'screens/event_planner_screen.dart';
import 'screens/location_tracking_screen.dart'; // Ensure this import is correct!

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print('✅ Firebase Initialized successfully!');
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
      title: 'AI Safety Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617), // kSlate950
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6), // kBlue500
          secondary: Color(0xFF10B981), // kEmerald500
          surface: Color(0xFF1E293B), // kSlate800
          background: Color(0xFF020617), // kSlate950
        ),
      ),
      themeMode: ThemeMode.dark, // Forces dark mode for your new UI
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());
          case '/home':
            return MaterialPageRoute(builder: (_) => const Home());
          case '/emergency':
            return MaterialPageRoute(builder: (_) => const EmergencyListeningPage());
          case '/consultancy':
             return MaterialPageRoute(builder: (_) => const ConsultancyTab());
          case '/event_planner':
            return MaterialPageRoute(builder: (_) => const EventPlannerScreen());
          case '/location_tracking':
            return MaterialPageRoute(builder: (_) => const LocationTrackingScreen());
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
        // While waiting for auth state, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // If there's an error, show it
        if (snapshot.hasError) {
          return ErrorScreen(message: 'Authentication error: ${snapshot.error}');
        }
        // If user is logged in, go to Home. Otherwise, go to Login.
        if (snapshot.hasData) {
          return const Home();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}