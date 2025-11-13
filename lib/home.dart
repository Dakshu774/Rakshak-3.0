import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'screens/home_page.dart';
import 'screens/event_planner_screen.dart';
import 'screens/consultation_screen.dart';
// Standardized Import (Assuming location_tracking_screen.dart is in lib/screens)
import 'screens/location_tracking_screen.dart'; 

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate500 = Color(0xFF64748B);
const Color kBlue500 = Color(0xFF3B82F6);

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomePage(key: ValueKey('home')),
    const LocationTrackingScreen(key: ValueKey('location')),
    const EventPlannerScreen(key: ValueKey('events')),
    const ConsultationScreen(key: ValueKey('consult')),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuart,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kSlate800, width: 1)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: kBlue500.withOpacity(0.1),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBlue500);
              }
              return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kSlate500);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: kBlue500);
              }
              return const IconThemeData(color: kSlate500);
            }),
          ),
          child: NavigationBar(
            height: 65,
            backgroundColor: kSlate900,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: const [
              NavigationDestination(
                  icon: Icon(LucideIcons.home),
                  selectedIcon: Icon(LucideIcons.home, color: kBlue500),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(LucideIcons.mapPin),
                  selectedIcon: Icon(LucideIcons.mapPin, color: kBlue500),
                  label: 'Location'),
              NavigationDestination(
                  icon: Icon(LucideIcons.calendar),
                  selectedIcon: Icon(LucideIcons.calendar, color: kBlue500),
                  label: 'Events'),
              NavigationDestination(
                  icon: Icon(LucideIcons.stethoscope),
                  selectedIcon: Icon(LucideIcons.stethoscope, color: kBlue500),
                  label: 'Consult'),
            ],
          ),
        ),
      ),
    );
  }
}