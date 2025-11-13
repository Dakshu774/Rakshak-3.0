import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

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
const Color kEmerald500 = Color(0xFF10B981);
const Color kOrange500 = Color(0xFFF97316);

class EventPlannerScreen extends StatefulWidget {
  const EventPlannerScreen({Key? key}) : super(key: key);

  @override
  _EventPlannerScreenState createState() => _EventPlannerScreenState();
}

class _EventPlannerScreenState extends State<EventPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  LatLng? _selectedLocation;
  bool _isSearching = false;
  List<Location> _searchResults = [];

  bool _isCheckinRequired = false;
  Timer? _checkinTimer;

  @override
  void initState() {
    super.initState();
    _loadEvents(); 
    _startCheckinTimer();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _checkinTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .orderBy('startTime')
          .get();

      if (mounted) {
        setState(() {
          _events = eventsSnapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error loading data: $e'), backgroundColor: kRed500));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startCheckinTimer() {
    _checkinTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkMissedCheckins();
    });
  }

  Future<String?> _getFirstEmergencyContact() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final contactsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('emergency_contacts')
          .limit(1)
          .get();

      if (contactsSnapshot.docs.isNotEmpty) {
        return contactsSnapshot.docs.first.data()['phone'];
      }
      return null;
    } catch (e) {
      print("Error fetching first contact: $e");
      return null;
    }
  }

  void _checkMissedCheckins() {
    final now = DateTime.now();
    for (var event in _events) {
      if (event['endTime'] == null) continue;

      final endTime = (event['endTime'] as Timestamp).toDate();
      final isCheckinRequired = event['isCheckinRequired'] ?? false;
      final isCheckedIn = event['isCheckedIn'] ?? false;
      final String alertState = event['alertState'] ?? 'none';

      if (!isCheckinRequired || isCheckedIn) continue;

      final bool is10MinOverdue =
          endTime.isBefore(now.subtract(const Duration(minutes: 10)));
      if (is10MinOverdue && alertState == 'sms_sent') {
        print('MISSED 10 MIN CHECK-IN: ${event['title']} - Triggering CALL');
        _triggerPhoneCall(); // Use new helper
        _markEventAsAlerted(event['id'], 'call_sent');
      }

      final bool is5MinOverdue =
          endTime.isBefore(now.subtract(const Duration(minutes: 5)));
      if (is5MinOverdue && alertState == 'none') {
        print('MISSED 5 MIN CHECK-IN: ${event['title']} - Sending SMS');
        _triggerSmsAlert(event['title']); // Use new helper
        _markEventAsAlerted(event['id'], 'sms_sent');
      }
    }
  }

  Future<void> _triggerSmsAlert(String eventTitle) async {
    String? parentNumber = await _getFirstEmergencyContact();
    if (parentNumber == null || parentNumber.isEmpty) {
      print("No parent contact number found to send alert.");
      return;
    }

    final String message =
        "Safety Alert: Missed check-in for event: '$eventTitle'. Possible concern (5 min overdue).";
    final Uri launchUri = Uri(
        scheme: 'sms', path: parentNumber, queryParameters: {'body': message});

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        print("Could not launch SMS app.");
      }
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }

  Future<void> _triggerPhoneCall() async {
    String? parentNumber = await _getFirstEmergencyContact();
    if (parentNumber == null || parentNumber.isEmpty) {
      print("No parent contact number found to make call.");
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: parentNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      print("Error making call: $e");
    }
  }

  Future<void> _markEventAsAlerted(String eventId, String state) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc(eventId)
          .update({'alertState': state});
      _loadEvents();
    } catch (e) {
      print("Error marking event as alerted: $e");
    }
  }

  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select date, start, and end time'),
          backgroundColor: kRed500));
      return;
    }

    final DateTime startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute);
    final DateTime endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _endTime!.hour,
        _endTime!.minute);

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: kRed500));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('events')
            .add({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'startTime': Timestamp.fromDate(startDateTime),
          'endTime': Timestamp.fromDate(endDateTime),
          'locationName': _locationController.text,
          'isCheckinRequired': _isCheckinRequired,
          'isCheckedIn': false,
          'alertState': 'none',
          'createdAt': FieldValue.serverTimestamp(),
          if (_selectedLocation != null)
            'location': GeoPoint(
                _selectedLocation!.latitude, _selectedLocation!.longitude),
        });

        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        setState(() {
          _selectedDate = null;
          _startTime = null;
          _endTime = null;
          _selectedLocation = null;
          _isCheckinRequired = false;
        });

        await _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Event added successfully'),
              backgroundColor: kBlue500));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error adding event: $e'), backgroundColor: kRed500));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markEventAsCheckedIn(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc(eventId)
          .update({'isCheckedIn': true, 'alertState': 'checked_in'});
      _loadEvents();
    } catch (e) {
      print("Error marking event as checked in: $e");
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (mounted)
        setState(() {
          _searchResults = locations;
          _isSearching = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
    }
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: kBlue500,
                  onPrimary: Colors.white,
                  surface: kSlate800,
                  onSurface: Colors.white),
              dialogBackgroundColor: kSlate900),
          child: child!),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
    return picked;
  }

  Future<TimeOfDay?> _selectTime(BuildContext context,
      {TimeOfDay? initialTime}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: kBlue500,
                  onPrimary: Colors.white,
                  surface: kSlate800,
                  onSurface: Colors.white),
              timePickerTheme: TimePickerThemeData(
                  backgroundColor: kSlate900,
                  dialHandColor: kBlue500,
                  dialBackgroundColor: kSlate800,
                  hourMinuteTextColor: Colors.white,
                  dayPeriodTextColor: Colors.white,
                  entryModeIconColor: kBlue500)),
          child: child!),
    );
    return picked;
  }

  Future<void> _openLocationPicker() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Opening Map Picker...'), backgroundColor: kBlue500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate900.withOpacity(0.8),
        elevation: 0,
        title: const Text('Event Planner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: kSlate800, height: 1.0)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kBlue500))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: kSlate900,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: kSlate800)),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ADD NEW EVENT',
                              style: TextStyle(
                                  color: kBlue500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 20),
                          _buildTextField(
                              controller: _titleController,
                              label: 'Event Title',
                              icon: LucideIcons.type,
                              validator: (val) =>
                                  val!.isEmpty ? 'Title required' : null),
                          const SizedBox(height: 16),
                          _buildTextField(
                              controller: _descriptionController,
                              label: 'Description',
                              icon: LucideIcons.alignLeft,
                              maxLines: 3,
                              alignLabelWithHint: true),
                          const SizedBox(height: 16),
                          _buildDateTimeButton(
                              context: context,
                              icon: LucideIcons.calendar,
                              label: _selectedDate == null
                                  ? 'Select Date'
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_selectedDate!),
                              onTap: () async {
                                final date = await _selectDate(context);
                                if (date != null) {
                                  setState(() => _selectedDate = date);
                                }
                              },
                              isSelected: _selectedDate != null),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildDateTimeButton(
                                      context: context,
                                      icon: LucideIcons.clock,
                                      label: _startTime == null
                                          ? 'Start Time'
                                          : _startTime!.format(context),
                                      onTap: () async {
                                        final time = await _selectTime(context,
                                            initialTime: _startTime);
                                        if (time != null) {
                                          setState(() => _startTime = time);
                                        }
                                      },
                                      isSelected: _startTime != null)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _buildDateTimeButton(
                                      context: context,
                                      icon: LucideIcons.timer,
                                      label: _endTime == null
                                          ? 'End Time'
                                          : _endTime!.format(context),
                                      onTap: () async {
                                        final time = await _selectTime(context,
                                            initialTime: _endTime);
                                        if (time != null) {
                                          setState(() => _endTime = time);
                                        }
                                      },
                                      isSelected: _endTime != null)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLocationField(),
                          if (_searchResults.isNotEmpty) _buildSearchResults(),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                                color: kSlate950,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: kSlate800, width: 1.5)),
                            child: SwitchListTile.adaptive(
                              title: const Text('Require Safety Check-in',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                              subtitle: const Text(
                                  'Triggers an SMS alert if check-in is missed by 5 minutes',
                                  style: TextStyle(
                                      color: kSlate400, fontSize: 12)),
                              value: _isCheckinRequired,
                              onChanged: (bool value) =>
                                  setState(() => _isCheckinRequired = value),
                              activeColor: kEmerald500,
                              inactiveTrackColor: kSlate700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addEvent,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: kBlue500,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                  shadowColor: kBlue500.withOpacity(0.5)),
                              child: const Text('Create Event',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('UPCOMING EVENTS',
                            style: TextStyle(
                                color: kSlate400,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: kSlate800,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('${_events.length}',
                                style: const TextStyle(
                                    color: kSlate300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)))
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_events.isEmpty)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(children: [
                              Icon(LucideIcons.calendarX,
                                  size: 48, color: kSlate800),
                              const SizedBox(height: 16),
                              const Text("No upcoming events",
                                  style: TextStyle(
                                      color: kSlate500,
                                      fontWeight: FontWeight.w500))
                            ]))),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _events.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildEventCard(context, event);
                    },
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    if (event['startTime'] == null || event['endTime'] == null)
      return Container();

    final startTime = (event['startTime'] as Timestamp).toDate();
    final endTime = (event['endTime'] as Timestamp).toDate();

    final timeString =
        "${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}";
    final dateString = DateFormat('MMM dd').format(startTime);

    final bool requiresCheckin = event['isCheckinRequired'] ?? false;
    final bool isCheckedIn = event['isCheckedIn'] ?? false;
    final String alertState = event['alertState'] ?? 'none';
    final bool isEventOver = endTime.isBefore(DateTime.now());

    Widget statusPill;
    if (requiresCheckin) {
      if (isCheckedIn) {
        statusPill = _buildStatusPill('CHECKED IN', kEmerald500);
      } else if (isEventOver && alertState == 'call_sent') {
        statusPill = _buildStatusPill('OVERDUE - CALL ALERTED', kRed500);
      } else if (isEventOver && alertState == 'sms_sent') {
        statusPill = _buildStatusPill('OVERDUE - SMS SENT', kOrange500);
      } else if (isEventOver) {
        statusPill = _buildStatusPill('OVERDUE - MISSED', kRed500);
      } else {
        statusPill = _buildStatusPill('PENDING CHECK-IN', kBlue500);
      }
    } else {
      statusPill = Container();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: kSlate900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kSlate800)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: kSlate800, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dateString.split(' ')[1],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    Text(dateString.split(' ')[0].toUpperCase(),
                        style: const TextStyle(
                            color: kBlue500,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: kBlue500.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(99)),
                        child: Text(timeString,
                            style: const TextStyle(
                                color: kBlue500,
                                fontSize: 11,
                                fontWeight: FontWeight.w600))),
                    if (event['locationName'] != null &&
                        (event['locationName'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(LucideIcons.mapPin,
                            color: kSlate500, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(event['locationName'],
                                style: const TextStyle(
                                    color: kSlate400, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis))
                      ]),
                    ],
                    if (requiresCheckin) ...[
                      const SizedBox(height: 8),
                      statusPill,
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.moreVertical, color: kSlate700, size: 20),
            ],
          ),
          if (requiresCheckin && !isCheckedIn && !isEventOver)
            Column(
              children: [
                const Divider(color: kSlate800, height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markEventAsCheckedIn(event['id']),
                    icon: const Icon(LucideIcons.check, size: 20),
                    label: const Text('Safety Check-in'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kEmerald500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      int maxLines = 1,
      bool alignLabelWithHint = false,
      String? Function(String?)? validator}) {
    return TextFormField(
        controller: controller,
        maxLines: maxLines,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: alignLabelWithHint,
            labelStyle: const TextStyle(
                color: kSlate400, fontWeight: FontWeight.normal),
            floatingLabelStyle:
                const TextStyle(color: kBlue500, fontWeight: FontWeight.w600),
            prefixIcon: Padding(
                padding: EdgeInsets.only(
                    left: 12,
                    right: 8,
                    bottom: alignLabelWithHint ? (24.0 * (maxLines - 1)) : 0),
                child: Icon(icon, color: kSlate500, size: 20)),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 48),
            filled: true,
            fillColor: kSlate950,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSlate800, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBlue500, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kRed500, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kRed500, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        validator: validator);
  }

  Widget _buildDateTimeButton(
      {required BuildContext context,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      required bool isSelected}) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
                color: kSlate950,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected ? kBlue500 : kSlate800,
                    width: isSelected ? 2 : 1.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: isSelected ? kBlue500 : kSlate400, size: 18),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(label,
                      style: TextStyle(
                          color: isSelected ? Colors.white : kSlate400,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis))
            ])));
  }

  Widget _buildLocationField() {
    return TextFormField(
        controller: _locationController,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
            labelText: 'Location',
            labelStyle: const TextStyle(color: kSlate400),
            floatingLabelStyle:
                const TextStyle(color: kBlue500, fontWeight: FontWeight.w600),
            hintText: 'Enter address...',
            hintStyle: TextStyle(color: kSlate500.withOpacity(0.5)),
            prefixIcon:
                const Icon(LucideIcons.mapPin, color: kSlate500, size: 20),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_isSearching)
                const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kBlue500)))
              else
                IconButton(
                    icon: const Icon(LucideIcons.search, color: kSlate400),
                    onPressed: () => _searchLocation(_locationController.text)),
              Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: kSlate800, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                      icon: const Icon(LucideIcons.map,
                          color: kBlue500, size: 20),
                      onPressed: _openLocationPicker,
                      tooltip: 'Pick on map',
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero))
            ]),
            filled: true,
            fillColor: kSlate950,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSlate800, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBlue500, width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        onChanged: (value) {
          if (value.length > 3) _searchLocation(value);
        });
  }

  Widget _buildSearchResults() {
    return Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
            color: kSlate900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBlue500.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    _searchResults.length > 3 ? 3 : _searchResults.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: kSlate800),
                itemBuilder: (context, index) {
                  final location = _searchResults[index];
                  return ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.mapPin,
                          color: kBlue500, size: 16),
                      title: Text(
                          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                              color: kSlate200,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      tileColor: kSlate900,
                      onTap: () {
                        setState(() {
                          _selectedLocation =
                              LatLng(location.latitude, location.longitude);
                          _locationController.text =
                              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
                          _searchResults = [];
                        });
                      });
                })));
  }
}
