import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'ai_safety_hub.dart'; 
import '../services/ai_safety_service.dart';
import 'voice_safety_settings.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kRed500 = Color(0xFFEF4444);
const Color kRed600 = Color(0xFFDC2626);
const Color kEmerald500 = Color(0xFF10B981);
const Color kEmerald600 = Color(0xFF059669);
const Color kPurple500 = Color(0xFFA855F7);
const Color kSlate200 = Color(0xFFE2E8F0);

// --- MOCK DATA ---
final List<Map<String, dynamic>> mockActivity = [
  {'icon': LucideIcons.bellRing, 'color': kRed500, 'title': 'SOS Alert Sent', 'time': '3 min ago'},
  {'icon': LucideIcons.mapPin, 'color': kBlue500, 'title': 'Entered Safe Zone', 'time': '30 min ago'},
  {'icon': LucideIcons.battery, 'color': kEmerald500, 'title': 'Battery 90%', 'time': '1 hour ago'},
];

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final AISafetyService _aiService = AISafetyService();
  
  // --- VOICE VARIABLES ---
  late stt.SpeechToText _speech;
  bool _isListening = false; 
  final String _emergencyNumber = '7973060593'; 
  
  final bool _isSafetyActive = true;
  double _currentSpeed = 0.0;
  Timer? _updateTimer;

  late AnimationController _sosController;
  late Animation<double> _sosScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startMonitoringUpdates();
    
    _speech = stt.SpeechToText();
    _initAndStartSpeech();
  }

  void _initAndStartSpeech() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    bool available = await _speech.initialize(
      onStatus: _onSpeechStatus, 
      onError: (val) => print('Speech Error: $val'),
    );

    if (available && mounted) {
      setState(() => _isListening = true);
      _startListening(); 
    }
  }

  void _toggleContinuousListening() {
    setState(() {
      _isListening = !_isListening;
    });

    if (_isListening) {
      _startListening();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resuming Watch Mode"), backgroundColor: kBlue500));
    } else {
      _speech.stop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Watch Mode Paused"), backgroundColor: kSlate700));
    }
  }

  void _startListening() {
    if (!_isListening) return; 

    _speech.listen(
      onResult: (val) {
        if (val.recognizedWords.isNotEmpty) {
           _scanForTriggerWord(val.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 20), 
      pauseFor: const Duration(seconds: 3),   
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
  }

  void _onSpeechStatus(String status) {
    if ((status == 'done' || status == 'notListening') && _isListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isListening && mounted) {
          _startListening();
        }
      });
    }
  }

  void _scanForTriggerWord(String spokenWords) {
    final words = spokenWords.toLowerCase();
    if (words.contains('help') || words.contains('save me') || words.contains('emergency')) {
      _triggerVoiceSOS();
    }
  }

  void _triggerVoiceSOS() {
    setState(() => _isListening = false);
    _speech.stop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text("VOICE COMMAND DETECTED! CALLING NOW..."), backgroundColor: kRed500, duration: const Duration(seconds: 5))
    );
    
    _makePhoneCall(_emergencyNumber);
  }

  void _initializeAnimations() {
    _sosController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _sosScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));
  }

  void _startMonitoringUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        try {
          final position = await Geolocator.getCurrentPosition();
          setState(() => _currentSpeed = position.speed * 3.6);
        } catch (e) {}
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _sosController.dispose();
    _speech.cancel(); 
    super.dispose();
  }

  Future<void> _handleEmergencyCall() async {
    final Uri launchUri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
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
        title: const Text('Safety Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: kSlate200),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceSafetySettings())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAnimatedEntry(delay: 0, child: _buildStatusCard()),
            const SizedBox(height: 24),
            _buildAnimatedEntry(delay: 100, child: _buildSosButton()),
            const SizedBox(height: 24),
            _buildAnimatedEntry(delay: 200, child: _buildQuickStats()),
            const SizedBox(height: 24),
            _buildAnimatedEntry(delay: 300, child: _buildContactShortcut()),
            const SizedBox(height: 24),
            
            // --- 2. NEW AI HUB BUTTON ---
            _buildAnimatedEntry(delay: 350, child: _buildAIHubCard()),
            const SizedBox(height: 24),

            _buildAnimatedEntry(delay: 400, child: _buildVoiceCommandCard()),
            const SizedBox(height: 24),
            _buildAnimatedEntry(delay: 500, child: _buildRecentActivity()),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // --- NEW WIDGET: AI HUB ENTRY POINT ---
  Widget _buildAIHubCard() {
    return GestureDetector(
      onTap: () {
        // Navigate to the AI Safety Hub
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AISafetyHub()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // A nice purple/blue gradient to signify "AI/Smart" features
          gradient: LinearGradient(
            colors: [kPurple500.withOpacity(0.2), kBlue500.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPurple500.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: kPurple500.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kPurple500, shape: BoxShape.circle),
              child: const Icon(LucideIcons.brainCircuit, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rakshak AI Hub', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Chatbot, Fake Call & Guardian Lens', style: TextStyle(color: kSlate400, fontSize: 13)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: kSlate500),
          ],
        ),
      ),
    );
  }

  Widget _buildContactShortcut() {
    return GestureDetector(
      onTap: () => _makePhoneCall(_emergencyNumber),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kBlue500.withOpacity(0.1), kBlue500.withOpacity(0.05)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlue500.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: kBlue500, shape: BoxShape.circle),
              child: const Icon(LucideIcons.phone, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Parent Quick Call', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Call your primary contact now', style: TextStyle(color: kSlate400, fontSize: 13)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: kSlate500),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCommandCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: kSlate900.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isListening ? kRed500.withOpacity(0.5) : kSlate800)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hands-free Mode', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _isListening 
                ? Row(children: [
                    const SizedBox(
                      width: 12, height: 12, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: kRed500)
                    ),
                    const SizedBox(width: 8),
                    const Text('Listening for "Help"...', style: TextStyle(color: kRed500, fontSize: 14, fontWeight: FontWeight.bold))
                  ])
                : const Text('Tap mic to resume listening', style: TextStyle(color: kSlate400, fontSize: 14)),
            ],
          ),
          GestureDetector(
            onTap: _toggleContinuousListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isListening ? kRed500 : kSlate800,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (_isListening ? kRed500 : Colors.transparent).withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: Icon(_isListening ? LucideIcons.mic : LucideIcons.micOff, color: _isListening ? Colors.white : kSlate400, size: 24),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RECENT ACTIVITY', style: TextStyle(color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: kSlate900, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: mockActivity.map((activity) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Icon(activity['icon'] as IconData, color: activity['color'] as Color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(activity['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                    Text(activity['time'] as String, style: const TextStyle(color: kSlate500, fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: _isSafetyActive ? [kEmerald600, const Color(0xFF0D9488)] : [kSlate800, kSlate900],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: _isSafetyActive ? [BoxShadow(color: kEmerald500.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))] : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isSafetyActive ? 'You are Safe' : 'Monitoring Paused', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Row(children: [Icon(LucideIcons.shieldCheck, color: Colors.white70, size: 16), SizedBox(width: 6), Text('AI Monitoring Active', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500))]),
            ],
          ),
          Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(LucideIcons.check, color: Colors.white, size: 32)),
        ],
      ),
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTap: _handleEmergencyCall,
      child: ScaleTransition(
        scale: _sosScaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kRed600, Color(0xFF991B1B)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: kRed600.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(LucideIcons.shieldAlert, color: kRed600, size: 24)),
              const SizedBox(width: 16),
              const Text('SOS EMERGENCY', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(children: [
      _buildStatusChip(LucideIcons.mapPin, 'Safe Zone', 'Active', kBlue500),
      const SizedBox(width: 12),
      _buildStatusChip(LucideIcons.gauge, 'Speed', '${_currentSpeed.toStringAsFixed(0)} km/h', kEmerald500),
      const SizedBox(width: 12),
      _buildStatusChip(LucideIcons.activity, 'Checks', 'Normal', kPurple500),
    ]);
  }

  Widget _buildStatusChip(IconData icon, String label, String status, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.15), color.withOpacity(0.05)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1.5)), child: Column(children: [Icon(icon, color: color, size: 22), const SizedBox(height: 12), Text(label, style: const TextStyle(color: kSlate400, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)), const SizedBox(height: 4), Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))])));
  }

  Widget _buildAnimatedEntry({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic, builder: (context, value, child) => Opacity(opacity: value, child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child)), child: child);
  }
}