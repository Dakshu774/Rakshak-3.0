import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_safety_service.dart';
import '../theme.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({Key? key}) : super(key: key);

  @override
  _AISettingsScreenState createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final AISafetyService _aiService = AISafetyService();
  final _formKey = GlobalKey<FormState>();
  final _triggerWordController = TextEditingController();
  final _contactController = TextEditingController();
  final _contactTypeController = TextEditingController();
  final _smtpServerController = TextEditingController();
  final _smtpUsernameController = TextEditingController();
  final _smtpPasswordController = TextEditingController();
  
  bool _isTestMode = false;
  bool _enableSMS = true;
  bool _enableEmail = true;
  bool _enablePushNotifications = true;
  List<String> _emergencyContacts = [];
  Map<String, String> _contactTypes = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _triggerWordController.text = prefs.getString('trigger_word') ?? 'help';
      _emergencyContacts = prefs.getStringList('emergency_contacts') ?? [];
      final contactTypesString = prefs.getString('contact_types');
      if (contactTypesString != null) {
        _contactTypes = Map<String, String>.from(
          contactTypesString.split(',').fold<Map<String, String>>({}, (map, element) {
            final parts = element.split(':');
            if (parts.length == 2) {
              map[parts[0]] = parts[1];
            }
            return map;
          })
        );
      } else {
        _contactTypes = {};
      }
      _enableSMS = prefs.getBool('enable_sms') ?? true;
      _enableEmail = prefs.getBool('enable_email') ?? true;
      _enablePushNotifications = prefs.getBool('enable_push') ?? true;
      _smtpServerController.text = prefs.getString('smtp_server') ?? '';
      _smtpUsernameController.text = prefs.getString('smtp_username') ?? '';
      _smtpPasswordController.text = prefs.getString('smtp_password') ?? '';
      _isTestMode = prefs.getBool('test_mode') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState?.validate() ?? false) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trigger_word', _triggerWordController.text);
      await prefs.setStringList('emergency_contacts', _emergencyContacts);
      await prefs.setString('contact_types', _contactTypes.entries
          .map((e) => '${e.key}:${e.value}')
          .join(','));
      await prefs.setBool('enable_sms', _enableSMS);
      await prefs.setBool('enable_email', _enableEmail);
      await prefs.setBool('enable_push', _enablePushNotifications);
      await prefs.setString('smtp_server', _smtpServerController.text);
      await prefs.setString('smtp_username', _smtpUsernameController.text);
      await prefs.setString('smtp_password', _smtpPasswordController.text);
      await prefs.setBool('test_mode', _isTestMode);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  void _addContact() {
    if (_contactController.text.isNotEmpty) {
      setState(() {
        _emergencyContacts.add(_contactController.text);
        _contactTypes[_contactController.text] = _contactTypeController.text;
        _contactController.clear();
        _contactTypeController.clear();
      });
    }
  }

  void _removeContact(String contact) {
    setState(() {
      _emergencyContacts.remove(contact);
      _contactTypes.remove(contact);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Safety Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trigger Word', style: AppTheme.titleLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _triggerWordController,
                      decoration: const InputDecoration(
                        hintText: 'Enter trigger word (e.g., help)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter a trigger word';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Emergency Contacts', style: AppTheme.titleLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _contactController,
                            decoration: const InputDecoration(
                              hintText: 'Contact (email/phone)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _contactTypeController,
                            decoration: const InputDecoration(
                              hintText: 'Type (email/phone)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addContact,
                          icon: const Icon(Icons.add),
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._emergencyContacts.map((contact) => ListTile(
                      title: Text(contact),
                      subtitle: Text(_contactTypes[contact] ?? 'Unknown type'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeContact(contact),
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert Settings', style: AppTheme.titleLarge),
                    SwitchListTile(
                      title: const Text('Enable SMS Alerts'),
                      value: _enableSMS,
                      onChanged: (value) => setState(() => _enableSMS = value),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Email Alerts'),
                      value: _enableEmail,
                      onChanged: (value) => setState(() => _enableEmail = value),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Push Notifications'),
                      value: _enablePushNotifications,
                      onChanged: (value) => setState(() => _enablePushNotifications = value),
                    ),
                  ],
                ),
              ),
            ),
            if (_enableEmail) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email Settings', style: AppTheme.titleLarge),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _smtpServerController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Server',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _smtpUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _smtpPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Mode', style: AppTheme.titleLarge),
                    SwitchListTile(
                      title: const Text('Enable Test Mode'),
                      subtitle: const Text('Simulates alerts without sending them'),
                      value: _isTestMode,
                      onChanged: (value) => setState(() => _isTestMode = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _triggerWordController.dispose();
    _contactController.dispose();
    _contactTypeController.dispose();
    _smtpServerController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }
} 