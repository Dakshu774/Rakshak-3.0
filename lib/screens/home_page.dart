import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_safety_service.dart';
import 'voice_safety_settings.dart';
// Make sure this import matches where you actually saved the file!
import 'location_tracking_screen.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kSlate300 = Color(0xFFCBD5E1);
const Color kSlate200 = Color(0xFFE2E8F0);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kRed500 = Color(0xFFEF4444);
const Color kRed600 = Color(0xFFDC2626);
const Color kEmerald500 = Color(0xFF10B981);
const Color kEmerald600 = Color(0xFF059669);
const Color kPurple500 = Color(0xFFA855F7);

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final AISafetyService _aiService = AISafetyService();
  bool _isListening = false;
  bool _isSafetyActive = true;
  double _currentSpeed = 0.0;
  Timer? _updateTimer;

  late AnimationController _sosController;
  late Animation<double> _sosScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeService();
  }

  void _initializeAnimations() {
    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _sosScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _sosController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeService() async {
    _startMonitoringUpdates();
  }

  void _startMonitoringUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        try {
          final position = await Geolocator.getCurrentPosition();
          setState(() {
            _currentSpeed = position.speed * 3.6;
          });
        } catch (e) {
          // Handle error
        }
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _sosController.dispose();
    super.dispose();
  }

  Future<void> _handleEmergencyCall() async {
    final Uri launchUri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate950,
        elevation: 0,
        title: const Text('Safety Assistant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: kSlate200),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceSafetySettings()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAnimatedEntry(
              delay: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: _isSafetyActive
                        ? [kEmerald600, const Color(0xFF0D9488)]
                        : [kSlate800, kSlate900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: _isSafetyActive
                      ? [BoxShadow(color: kEmerald500.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSafetyActive ? 'You are Safe' : 'Monitoring Paused',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.shieldCheck, color: Colors.white.withOpacity(0.8), size: 16),
                            const SizedBox(width: 6),
                            Text('AI Monitoring Active',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.check, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildAnimatedEntry(
              delay: 100,
              child: GestureDetector(
                onTap: _handleEmergencyCall,
                child: ScaleTransition(
                  scale: _sosScaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [kRed600, Color(0xFF991B1B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: kRed600.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.shieldAlert, color: kRed600, size: 24)),
                        const SizedBox(width: 16),
                        const Text('SOS EMERGENCY',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildAnimatedEntry(
              delay: 200,
              child: Row(
                children: [
                  _buildStatusChip(LucideIcons.mapPin, 'Safe Zone', 'Active', kBlue500),
                  const SizedBox(width: 12),
                  _buildStatusChip(LucideIcons.gauge, 'Speed', '${_currentSpeed.toStringAsFixed(0)} km/h', kEmerald500),
                  const SizedBox(width: 12),
                  _buildStatusChip(LucideIcons.activity, 'Checks', 'Normal', kPurple500),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildAnimatedEntry(
              delay: 300,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: kSlate900.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kSlate800)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Voice Command', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                            SizedBox(height: 4),
                            Text('Say "Help" for instant alert', style: TextStyle(color: kSlate400, fontSize: 14)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isListening = !_isListening),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isListening ? kRed500 : kBlue500,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: (_isListening ? kRed500 : kBlue500).withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Icon(_isListening ? LucideIcons.micOff : LucideIcons.mic, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                        color: kSlate900.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kSlate800)),
                    child: Column(
                      children: [
                        // --- UPDATED CALL SITE FOR LOCATION TRACKING ---
                        _buildToggleRow(
                          'Location Tracking',
                          LucideIcons.mapPin,
                          true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LocationTrackingScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1, color: kSlate800, indent: 60),
                        _buildToggleRow('Parent Alerts', LucideIcons.bellRing, true),
                        const Divider(height: 1, color: kSlate800, indent: 60),
                        _buildToggleRow('Speed Monitoring', LucideIcons.gauge, false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedEntry({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildStatusChip(IconData icon, String label, String status, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: kSlate400, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(String label, IconData icon, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kSlate800, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: kSlate400, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
            Switch.adaptive(
              value: isActive,
              onChanged: (v) {},
              activeColor: kEmerald500,
              inactiveTrackColor: kSlate800,
            ),
          ],
        ),
      ),
    );
  }
}