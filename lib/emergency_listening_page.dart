import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class EmergencyListeningPage extends StatefulWidget {
  const EmergencyListeningPage({Key? key}) : super(key: key);

  @override
  _EmergencyListeningPageState createState() => _EmergencyListeningPageState();
}

class _EmergencyListeningPageState extends State<EmergencyListeningPage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _status = 'Ready to listen';
  String _triggerWord = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeSpeech();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _triggerWord = prefs.getString('trigger_word') ?? 'help';
    });
  }

  Future<void> _initializeSpeech() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      bool available = await _speechToText.initialize();
      if (!available) {
        setState(() {
          _status = 'Speech recognition not available';
        });
      }
    } else {
      setState(() {
        _status = 'Microphone permission denied';
      });
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _status = 'Listening...';
        });
        await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      setState(() {
        _isListening = false;
        _status = 'Stopped listening';
      });
    }
  }

  void _onSpeechResult(result) {
    setState(() {
      if (result.finalResult) {
        String text = result.recognizedWords.toLowerCase();
        if (text.contains(_triggerWord.toLowerCase())) {
          _status = 'Trigger word detected!';
          // TODO: Implement emergency response
        } else {
          _status = 'Listening...';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Listening'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              style: AppTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Trigger word: $_triggerWord',
              style: AppTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _startListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? AppTheme.errorColor : AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                _isListening ? 'Stop Listening' : 'Start Listening',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
