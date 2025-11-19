import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({Key? key}) : super(key: key);

  @override
  _FakeCallScreenState createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _isCallActive = false;
  bool _isRinging = false;
  Timer? _callTimer;
  int _seconds = 0;
  
  @override
  void dispose() {
    _tts.stop();
    _callTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC ---

  void _scheduleCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Call scheduled in 5 seconds... Lock screen for realism."),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      )
    );
    
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isRinging = true);
      }
    });
  }

  void _answerCall() {
    setState(() {
      _isRinging = false;
      _isCallActive = true;
      _seconds = 0;
    });
    _startTimer();
    _startConversation();
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _seconds++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _startConversation() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.4); // Slightly slower for realism
    await Future.delayed(const Duration(seconds: 1)); // Initial pause
    await _tts.speak("Hello? Where are you? I've been waiting outside for ten minutes. Come out quickly, I have the car running.");
  }

  void _endCall() {
    _tts.stop();
    _callTimer?.cancel();
    setState(() {
      _isCallActive = false;
      _isRinging = false;
    });
    // Navigator.pop(context); // Optional: Close screen after call
  }

  // --- BUILDERS ---

  @override
  Widget build(BuildContext context) {
    if (_isRinging) return _buildIncomingCallUI();
    if (_isCallActive) return _buildActiveCallUI();
    return _buildSetupUI();
  }

  // 1. Setup Screen
  Widget _buildSetupUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text("Fake Call Generator", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.phoneIncoming, size: 60, color: Colors.teal),
            ),
            const SizedBox(height: 30),
            const Text(
              "Escape awkward situations",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _scheduleCall,
              icon: const Icon(LucideIcons.timer),
              label: const Text("Trigger Call (5s Delay)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Incoming Call Screen (Realism Focus)
  Widget _buildIncomingCallUI() {
    return Scaffold(
      // Dark gradient background like real Android
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C3E50), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const CircleAvatar(
                radius: 50, 
                backgroundColor: Colors.grey, 
                child: Icon(Icons.person, size: 60, color: Colors.white)
              ),
              const SizedBox(height: 20),
              const Text("Dad", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300)),
              const SizedBox(height: 10),
              const Text("Mobile +91 98765 43210", style: TextStyle(color: Colors.white70, fontSize: 18)),
              
              const Spacer(),
              const Text("Swipe up to answer", style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 20),
              
              // Answer / Decline Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 60.0, left: 40, right: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCallBtn(Icons.call_end, Colors.red, "Decline", _endCall),
                    _buildCallBtn(Icons.call, Colors.green, "Answer", _answerCall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. Active Call Screen (The Grid Layout)
  Widget _buildActiveCallUI() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2634), Color(0xFF0F151C)], // Slightly lighter than black
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Top Info
              Column(
                children: [
                  const CircleAvatar(
                    radius: 40, 
                    backgroundColor: Colors.grey, 
                    child: Icon(Icons.person, size: 50, color: Colors.white)
                  ),
                  const SizedBox(height: 16),
                  const Text("Dad", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_formatDuration(_seconds), style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1)),
                ],
              ),
              
              const Spacer(),
              
              // The 6-Button Grid
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildGridBtn(LucideIcons.micOff, "Mute"),
                        _buildGridBtn(LucideIcons.layoutGrid, "Keypad"),
                        _buildGridBtn(LucideIcons.volume2, "Speaker"),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildGridBtn(LucideIcons.plus, "Add call"),
                        _buildGridBtn(LucideIcons.video, "Video call"),
                        _buildGridBtn(LucideIcons.bluetooth, "Bluetooth"),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // End Call Button
              Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: FloatingActionButton.large(
                  onPressed: _endCall,
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Incoming Buttons
  Widget _buildCallBtn(IconData icon, Color color, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 32,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  // Helper: Active Grid Buttons
  Widget _buildGridBtn(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}