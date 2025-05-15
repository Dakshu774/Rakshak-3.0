import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'signup.dart';
import 'home.dart';
import 'emergency_listening_page.dart';
import 'consultancy_tab.dart';
import 'screens/voice_safety_settings.dart';
import 'screens/consultation_screen.dart';
import 'screens/ai_monitoring_screen.dart';
import 'screens/event_planner_screen.dart';
import 'services/ai_safety_service.dart';
// Event model

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase Initialized successfully!');

    // Initialize Stripe after Firebase
    // initializeStripe();

    // Run the app with AuthGate (Properly Wrapped)
    runApp(const MyApp());
  } catch (e) {
    print("🔥 Error initializing app: $e");

    // Ensure MaterialApp wraps ErrorScreen
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent, brightness: Brightness.dark),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupPage());
          case '/emergency':
            return MaterialPageRoute(builder: (_) => const EmergencyListeningPage());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomePage());
          case '/consultancy':
            return MaterialPageRoute(builder: (_) => const ConsultancyTab());
          case '/event_planner':  // New route for EventPlannerScreen
            return MaterialPageRoute(builder: (_) => const EventPlannerScreen());
          case '/voice_safety_settings':
            return MaterialPageRoute(builder: (_) => const VoiceSafetySettings());
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
    return StreamBuilder<User?>(  // Listen for the user's authentication state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator())); // Show loading spinner while waiting
        }
        if (snapshot.hasError) {
          return ErrorScreen(message: 'Authentication error: ${snapshot.error}'); // Show error message if any
        }
        if (snapshot.hasData) {
          return const HomePage(); // If user is logged in, go to HomePage
        } else {
          return const LoginPage(); // Otherwise, go to LoginPage
        }
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _aiService = AISafetyService();

  final List<Widget> _screens = [
    const HomePage(),
    const EventPlannerScreen(),
    const AIMonitoringScreen(),
    const VoiceSafetySettings(),
    const ConsultationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _aiService.initialize();
    } catch (e) {
      print('Error initializing AI service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology),
            label: 'AI Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Consult',
          ),
        ],
      ),
    );
  }
}
