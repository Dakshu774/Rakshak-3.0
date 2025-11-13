import 'package:flutter/material.dart';
import '../services/ai_safety_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kRed500 = Color(0xFFEF4444);
const Color kEmerald500 = Color(0xFF10B981);

class VoiceSafetySettings extends StatefulWidget {
  const VoiceSafetySettings({Key? key}) : super(key: key);

  @override
  _VoiceSafetySettingsState createState() => _VoiceSafetySettingsState();
}

class _VoiceSafetySettingsState extends State<VoiceSafetySettings> {
  final _aiService = AISafetyService();
  final _maxSpeedController = TextEditingController();
  bool _isServiceActive = false;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _statusCheckTimer;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startStatusChecks();
  }

  @override
  void dispose() {
    _maxSpeedController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusChecks() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkServiceStatus();
    });
  }

  Future<void> _checkServiceStatus() async {
    try {
      final isInitialized = await _aiService.initialize();
      if (mounted) setState(() => _isServiceActive = isInitialized);
    } catch (e) {
      if (mounted) setState(() => _isServiceActive = false);
    }
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      await _aiService.initialize();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          _maxSpeedController.text = (data['max_speed'] ?? 120.0).toString();
          if (mounted) setState(() => _isServiceActive = true);
        }

        final contactsSnapshot = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).collection('emergency_contacts').get();

        if (mounted) {
          setState(() {
            _emergencyContacts = contactsSnapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList();
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'max_speed': double.tryParse(_maxSpeedController.text) ?? 120.0,
          'last_updated': FieldValue.serverTimestamp(),
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved'), backgroundColor: kEmerald500),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kRed500),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContact(String contactId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('emergency_contacts').doc(contactId).delete();
      _loadSettings();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact removed'), backgroundColor: kRed500));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save contact: $e'), backgroundColor: kRed500));
    }
  }

  // --- ADDED: FUNCTION TO MAKE CALL (THIS WAS MISSING) ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''), 
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $phoneNumber'), backgroundColor: kRed500),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initiating call: $e'), backgroundColor: kRed500),
      );
    }
  }
  
  Future<void> _pickContact() async {
    PermissionStatus status = await Permission.contacts.request();
    if (status.isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        String? phoneNumber;
        if (contact.phones.isNotEmpty) {
          phoneNumber = contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
        }
        if (phoneNumber != null && mounted) {
          _showAddContactDialog(initialName: contact.displayName, initialPhone: phoneNumber);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact has no valid phone number.'), backgroundColor: kRed500));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact permission denied.'), backgroundColor: kRed500));
    }
  }


  Future<void> _showAddContactDialog({Map<String, dynamic>? contact, String? initialName, String? initialPhone}) async {
    final isEditing = contact != null;
    final nameController = TextEditingController(text: contact?['name'] ?? initialName);
    final phoneController = TextEditingController(text: contact?['phone'] ?? initialPhone);

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSlate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kSlate800)),
        title: Text(isEditing ? 'Edit Contact' : 'Add New Contact', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isEditing) 
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); 
                    _pickContact();        
                  },
                  icon: const Icon(LucideIcons.contact, size: 20),
                  label: const Text('Select from Contacts'),
                  style: OutlinedButton.styleFrom(foregroundColor: kBlue500, side: const BorderSide(color: kBlue500), padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            
            _buildDialogTextField(controller: nameController, label: 'Name', icon: LucideIcons.user),
            const SizedBox(height: 12),
            _buildDialogTextField(controller: phoneController, label: 'Phone', icon: LucideIcons.phone, keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kSlate400))),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                Navigator.pop(context, {'name': nameController.text, 'phone': phoneController.text});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kEmerald500),
            child: Text(isEditing ? 'Save' : 'Add', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result is Map) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final contactData = {'name': result['name'], 'phone': result['phone']};

      try {
        if (isEditing) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('emergency_contacts').doc(contact['id']).update(contactData);
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('emergency_contacts').add(contactData);
        }
        _loadSettings();
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save contact: $e'), backgroundColor: kRed500));
      }
    }
  }


  Future<void> _startVoiceTraining() async {
    try {
      await _aiService.trainVoiceModel('user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice model trained successfully'), backgroundColor: kEmerald500),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error training voice model: $e'), backgroundColor: kRed500),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e'), backgroundColor: kRed500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate950,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Safety Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(LucideIcons.refreshCw, color: kSlate400, size: 20), onPressed: _loadSettings, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kBlue500))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: kRed500.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kRed500.withOpacity(0.3))),
                        child: Text(_errorMessage!, style: const TextStyle(color: kRed500)),
                      ),

                    // --- STATUS CARD ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isServiceActive ? kEmerald500.withOpacity(0.1) : kRed500.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isServiceActive ? kEmerald500.withOpacity(0.3) : kRed500.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(_isServiceActive ? LucideIcons.shieldCheck : LucideIcons.shieldAlert, color: _isServiceActive ? kEmerald500 : kRed500),
                          const SizedBox(width: 12),
                          Text(_isServiceActive ? 'AI Safety Service Active' : 'Service Inactive', style: TextStyle(color: _isServiceActive ? kEmerald500 : kRed500, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- EMERGENCY CONTACTS LIST ---
                    const Text("EMERGENCY CIRCLE", style: TextStyle(color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(color: kSlate900, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          ..._emergencyContacts.map((contact) => _buildContactItem(contact)).toList(),

                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => _showAddContactDialog(),
                              icon: const Icon(LucideIcons.plusCircle, size: 20),
                              label: const Text('Add Emergency Contact'),
                              style: TextButton.styleFrom(foregroundColor: kBlue500, padding: const EdgeInsets.all(16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- SAFETY THRESHOLDS ---
                    const Text("SAFETY THRESHOLDS", style: TextStyle(color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _maxSpeedController, label: 'Max Speed Limit (km/h)', icon: LucideIcons.gauge, isNumber: true),
                    const SizedBox(height: 24),

                    // --- VOICE SETTINGS ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: kSlate900, borderRadius: BorderRadius.circular(16), border: Border.all(color: kSlate800)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Voice Recognition Model', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Train the AI to recognize your distress keywords more accurately.', style: TextStyle(color: kSlate400, fontSize: 13)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _startVoiceTraining(),
                              icon: const Icon(LucideIcons.mic),
                              label: const Text('Retrain Voice Model'),
                              style: OutlinedButton.styleFrom(foregroundColor: kBlue500, side: const BorderSide(color: kBlue500), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- SAVE BUTTON ---
                    ElevatedButton(
                      onPressed: _updateSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kEmerald500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Save All Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),

                    const SizedBox(height: 40),
                    const Divider(color: kSlate800),
                    const SizedBox(height: 24),

                    // --- SIGN OUT BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _signOut,
                        style: TextButton.styleFrom(
                          foregroundColor: kRed500,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: kRed500.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(LucideIcons.logOut),
                        label: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

Widget _buildContactItem(Map<String, dynamic> contact) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(LucideIcons.userCheck, color: kEmerald500),
          title: Text(contact['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          subtitle: Text(contact['phone'], style: const TextStyle(color: kSlate400)),
          // The trailing container width is now slightly smaller to prevent overflow
          trailing: SizedBox(
            width: 100, // Reduced width to ensure icons fit
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. CALL BUTTON
                IconButton(
                    icon: const Icon(LucideIcons.phone, color: kEmerald500, size: 20),
                    onPressed: () => _makePhoneCall(contact['phone']),
                    tooltip: 'Call ${contact['name']}',
                ),
                // 2. EDIT BUTTON REMOVED (The 'pen logo')
                // 3. TRASH BUTTON
                IconButton(icon: const Icon(LucideIcons.trash2, color: kRed500, size: 20), onPressed: () => _deleteContact(contact['id'])),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: kSlate800, indent: 60, endIndent: 16),
      ],
    );
  }

Widget _buildDialogTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSlate500),
        prefixIcon: Icon(icon, color: kSlate500, size: 20),
        filled: true,
        fillColor: kSlate800,
        // CORRECTED BORDER SIDE
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent, width: 0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kBlue500),
        ),
      ),
      validator: (value) => value != null && value.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSlate500),
        prefixIcon: Icon(icon, color: kSlate500, size: 20),
        filled: true,
        fillColor: kSlate900,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kSlate800)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBlue500)),
      ),
      validator: (value) => value != null && value.isEmpty ? 'Required' : null,
    );
  }
}