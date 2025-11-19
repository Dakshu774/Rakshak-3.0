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
  
  void _scheduleCall() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Call scheduled in 5 seconds... lock your screen.")));
    Timer(const Duration(seconds: 5), () {
      setState(() => _isRinging = true);
    });
  }

  void _answerCall() {
    setState(() {
      _isRinging = false;
      _isCallActive = true;
    });
    _startConversation();
  }

  Future<void> _startConversation() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.speak("Hello? Are you okay? I am waiting outside. Come out quickly. I have the car running.");
  }

  void _endCall() {
    _tts.stop();
    setState(() {
      _isCallActive = false;
      _isRinging = false;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRinging) return _buildIncomingCallUI();
    if (_isCallActive) return _buildActiveCallUI();

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text("Fake Call Generator", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _scheduleCall,
          icon: const Icon(LucideIcons.timer),
          label: const Text("Trigger Call (5s Delay)"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingCallUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 60, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 80, color: Colors.white)),
          const SizedBox(height: 20),
          const Text("Dad", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text("Mobile +91 98765 43210", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                onPressed: _endCall,
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
              FloatingActionButton(
                onPressed: _answerCall,
                backgroundColor: Colors.green,
                child: const Icon(LucideIcons.phone, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildActiveCallUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 60, color: Colors.white)),
          const SizedBox(height: 20),
          const Text("Dad", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const Text("00:12", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          FloatingActionButton(
            onPressed: _endCall,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end, color: Colors.white),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}