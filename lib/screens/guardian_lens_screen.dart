import 'dart:io';
import 'dart:async'; // Required for Timer
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lucide_icons/lucide_icons.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kEmerald500 = Color(0xFF10B981);
const Color kPurple500 = Color(0xFFA855F7);
const Color kSlate500 = Color(0xFF64748B);

class GuardianLensScreen extends StatefulWidget {
  const GuardianLensScreen({Key? key}) : super(key: key);

  @override
  _GuardianLensScreenState createState() => _GuardianLensScreenState();
}

class _GuardianLensScreenState extends State<GuardianLensScreen> {
  File? _image;
  String _scannedRawText = "";
  bool _isScanning = false;
  
  // To store the "Fetched" vehicle details
  Map<String, String>? _vehicleDetails;
  bool _isFetchingDetails = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isScanning = true;
        _vehicleDetails = null; // Reset previous details
        _scannedRawText = "";
      });
      _processImage(_image!);
    }
  }

  Future<void> _processImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer();
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // 1. Get the raw text
      String fullText = recognizedText.text;
      
      // 2. CLEANUP LOGIC: Try to find a pattern that looks like a number plate
      // Removes spaces, newlines, and special chars to standardize
      String cleanedText = fullText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      
      // Simple heuristic: If it contains "IND" or standard state codes like "MH", "DL", "KA"
      // This is where we extract the specific plate number.
      String detectedPlate = _extractPlateNumber(cleanedText);

      setState(() {
        _scannedRawText = detectedPlate.isNotEmpty ? detectedPlate : "No clear number plate found";
        _isScanning = false;
      });

      if (detectedPlate.isNotEmpty) {
        _fetchVehicleInfo(detectedPlate);
      }

    } catch (e) {
      setState(() {
        _scannedRawText = "Error scanning image";
        _isScanning = false;
      });
    } finally {
      textRecognizer.close();
    }
  }

  // Helper to extract plate number from messy text
  String _extractPlateNumber(String text) {
    // Regex for standard Indian plates (e.g., MH12AB1234 or KA05NM9999)
    // Looks for: 2 letters + 2 numbers + 1-3 letters + 4 numbers
    RegExp plateRegex = RegExp(r'[A-Z]{2}[0-9]{2}[A-Z]{1,3}[0-9]{4}');
    
    Match? match = plateRegex.firstMatch(text);
    if (match != null) {
      return match.group(0)!;
    }
    return text; // Return raw text if regex fails, user can edit manually if needed
  }

  // --- SIMULATED API CALL ---
  // In a real app, you would use http.get() to an RTO API here.
  Future<void> _fetchVehicleInfo(String plateNumber) async {
    setState(() => _isFetchingDetails = true);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isFetchingDetails = false;
      
      // MOCK DATA - This simulates what an RTO API returns
      _vehicleDetails = {
        "Registration No": plateNumber,
        "Owner Name": "RAJESH KUMAR VERMA", // Hidden for privacy usually
        "Vehicle Class": "Motor Car (LMV)",
        "Fuel Type": "PETROL / CNG",
        "Model": "SWIFT DZIRE VXI",
        "RC Status": "ACTIVE",
        "Insurance Valid": "YES (Till Oct 2026)",
        "PUC Valid": "YES",
        "Registering Authority": "PUNE RTO (MH-12)"
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        title: const Text("Guardian Lens", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kSlate900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. IMAGE PREVIEW
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: kSlate800,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kPurple500.withOpacity(0.5)),
              ),
              child: _image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.scanLine, size: 60, color: kSlate500.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        const Text("Scan Number Plate", style: TextStyle(color: Colors.grey))
                      ],
                    )
                  : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_image!, fit: BoxFit.cover)),
            ),
            
            const SizedBox(height: 24),

            // 2. CAMERA BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(LucideIcons.camera, "Camera", () => _pickImage(ImageSource.camera)),
                const SizedBox(width: 16),
                _buildActionButton(LucideIcons.image, "Gallery", () => _pickImage(ImageSource.gallery)),
              ],
            ),

            const SizedBox(height: 32),

            // 3. STATUS OR RESULTS
            if (_isScanning)
              const Center(child: CircularProgressIndicator(color: kPurple500))
            else if (_isFetchingDetails)
               Column(
                 children: [
                   const CircularProgressIndicator(color: kBlue500),
                   const SizedBox(height: 16),
                   Text("Fetching RTO Details for $_scannedRawText...", style: const TextStyle(color: kBlue500))
                 ],
               )
            else if (_vehicleDetails != null)
              _buildVehicleDetailCard()
            else if (_scannedRawText.isNotEmpty)
               Center(child: Text("Scanned: $_scannedRawText", style: const TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: kSlate800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: kPurple500.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildVehicleDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSlate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kEmerald500.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: kEmerald500.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("VEHICLE DETAILS", style: TextStyle(color: kEmerald500, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Icon(LucideIcons.shieldCheck, color: kEmerald500, size: 20)
            ],
          ),
          const Divider(color: kSlate800, height: 24),
          
          _detailRow("Registration", _vehicleDetails!["Registration No"]!, isBold: true),
          _detailRow("Owner Name", _vehicleDetails!["Owner Name"]!),
          _detailRow("Car Model", _vehicleDetails!["Model"]!),
          _detailRow("Fuel Type", _vehicleDetails!["Fuel Type"]!),
          _detailRow("RC Status", _vehicleDetails!["RC Status"]!, color: kEmerald500),
          _detailRow("Insurance", _vehicleDetails!["Insurance Valid"]!),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value, 
            style: TextStyle(
              color: color ?? Colors.white, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 15
            )
          ),
        ],
      ),
    );
  }
}