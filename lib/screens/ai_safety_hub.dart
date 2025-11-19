import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'ai_chatbot_screen.dart';
import 'guardian_lens_screen.dart';
import 'fake_call_screen.dart';

const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kPurple500 = Color(0xFFA855F7);
const Color kEmerald500 = Color(0xFF10B981);

class AISafetyHub extends StatelessWidget {
  const AISafetyHub({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate950,
        title: const Text("Rakshak AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select an AI Tool", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            
            // 1. AI Chatbot
            _buildAICard(
              context, 
              "Rakshak Assistant", 
              "Ask for legal, medical, or safety advice instantly.", 
              LucideIcons.bot, 
              kBlue500,
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AIChatbotScreen()))
            ),

            const SizedBox(height: 16),

            // 2. Guardian Lens
            _buildAICard(
              context, 
              "Guardian Lens", 
              "Scan Taxi plates or Signs to check safety.", 
              LucideIcons.scanLine, 
              kPurple500,
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GuardianLensScreen()))
            ),

            const SizedBox(height: 16),

            // 3. Fake Call
            _buildAICard(
              context, 
              "AI Fake Call", 
              "Schedule a realistic call to escape awkward situations.", 
              LucideIcons.phoneIncoming, 
              kEmerald500,
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FakeCallScreen()))
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAICard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSlate900,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}