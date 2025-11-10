import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate600 = Color(0xFF475569);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kSlate300 = Color(0xFFCBD5E1);
const Color kSlate200 = Color(0xFFE2E8F0);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kRed500 = Color(0xFFEF4444);

class EventPlannerScreen extends StatefulWidget {
  const EventPlannerScreen({Key? key}) : super(key: key);

  @override
  _EventPlannerScreenState createState() => _EventPlannerScreenState();
}

class _EventPlannerScreenState extends State<EventPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  LatLng? _selectedLocation;
  bool _isSearching = false;
  List<Location> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final events = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('events')
            .orderBy('date')
            .get();

        if (mounted) {
          setState(() {
            _events = events.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList();
          });
        }
      }
    } catch (e) {
      // Handle error silently or add a small debug print
      print("Error loading events: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      if (mounted) {
        setState(() {
          _searchResults = locations;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kBlue500,
              onPrimary: Colors.white,
              surface: kSlate800,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: kSlate900,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kBlue500,
              onPrimary: Colors.white,
              surface: kSlate800,
              onSurface: Colors.white,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: kSlate900,
              dialHandColor: kBlue500,
              dialBackgroundColor: kSlate800,
              hourMinuteTextColor: Colors.white,
              dayPeriodTextColor: Colors.white,
              entryModeIconColor: kBlue500,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationPickerScreen(initialLocation: _selectedLocation),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _selectedLocation = result;
      });
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = [
            place.name,
            place.thoroughfare,
            place.locality,
          ].where((element) => element != null && element.isNotEmpty).join(', ');

          if (address.isEmpty) {
            address =
                "${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}";
          }
          _locationController.text = address;
        }
      } catch (e) {
        _locationController.text =
            "${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}";
      }
    }
  }

  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select date and time'),
            backgroundColor: kRed500),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final eventDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('events')
            .add({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'date': eventDateTime,
          if (_selectedLocation != null)
            'location': GeoPoint(
              _selectedLocation!.latitude,
              _selectedLocation!.longitude,
            ),
          'locationName': _locationController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _titleController.clear();
        _descriptionController.clear();
        _locationController.clear();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _selectedLocation = null;
        });

        await _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Event added successfully'),
                backgroundColor: kBlue500),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding event: $e'), backgroundColor: kRed500),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      border: Border.all(color: kSlate800),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ADD NEW EVENT',
                            style: TextStyle(
                                color: kBlue500,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _titleController,
                            label: 'Event Title',
                            icon: LucideIcons.type,
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please enter a title'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: LucideIcons.alignLeft,
                            maxLines: 3,
                            alignLabelWithHint: true, // Keeps label at top
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateTimeButton(
                                  context: context,
                                  icon: LucideIcons.calendar,
                                  label: _selectedDate == null
                                      ? 'Select Date'
                                      : DateFormat('MMM dd, yyyy')
                                          .format(_selectedDate!),
                                  onTap: () => _selectDate(context),
                                  isSelected: _selectedDate != null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDateTimeButton(
                                  context: context,
                                  icon: LucideIcons.clock,
                                  label: _selectedTime == null
                                      ? 'Select Time'
                                      : _selectedTime!.format(context),
                                  onTap: () => _selectTime(context),
                                  isSelected: _selectedTime != null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLocationField(),
                          if (_searchResults.isNotEmpty) _buildSearchResults(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kBlue500,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: kBlue500.withOpacity(0.5),
                              ),
                              child: const Text(
                                'Create Event',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
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
                        const Text(
                          'UPCOMING EVENTS',
                          style: TextStyle(
                              color: kSlate400,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1),
                        ),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(color: kSlate800, borderRadius: BorderRadius.circular(12)),
                           child: Text('${_events.length}', style: const TextStyle(color: kSlate300, fontSize: 12, fontWeight: FontWeight.bold))
                         )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_events.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(LucideIcons.calendarX, size: 48, color: kSlate800),
                            SizedBox(height: 16),
                            Text("No upcoming events", style: TextStyle(color: kSlate500, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    )
                  else
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
                  const SizedBox(height: 60), // Extra scrolling space
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool alignLabelWithHint = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: alignLabelWithHint,
        labelStyle: const TextStyle(color: kSlate400, fontWeight: FontWeight.normal),
        floatingLabelStyle: const TextStyle(color: kBlue500, fontWeight: FontWeight.w600),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 12, right: 8, bottom: alignLabelWithHint ? (24.0 * (maxLines - 1)) : 0),
          child: Icon(icon, color: kSlate500, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
        filled: true,
        fillColor: kSlate950,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSlate800, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed500, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed500, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildDateTimeButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: kSlate900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? kBlue500 : kSlate800,
              width: isSelected ? 2 : 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? kBlue500 : kSlate400, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : kSlate400,
                  fontWeight: FontWeight.w600,
                  fontSize: 13
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: 'Location',
        labelStyle: const TextStyle(color: kSlate400),
        floatingLabelStyle: const TextStyle(color: kBlue500, fontWeight: FontWeight.w600),
        hintText: 'Enter address...',
        hintStyle: TextStyle(color: kSlate500.withOpacity(0.5)),
        prefixIcon: const Icon(LucideIcons.mapPin, color: kSlate500, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kBlue500)),
              )
            else
              IconButton(
                icon: const Icon(LucideIcons.search, color: kSlate400),
                onPressed: () => _searchLocation(_locationController.text),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: kSlate800, borderRadius: BorderRadius.circular(8)),
              child: IconButton(
                icon: const Icon(LucideIcons.map, color: kBlue500, size: 20),
                onPressed: _openLocationPicker,
                tooltip: 'Pick on map',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        filled: true,
        fillColor: kSlate950,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kSlate800, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue500, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: (value) {
        if (value.length > 3) {
           _searchLocation(value);
        }
      },
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: kSlate900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBlue500.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0,4))]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length > 3 ? 3 : _searchResults.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: kSlate800),
          itemBuilder: (context, index) {
            final location = _searchResults[index];
            return ListTile(
              dense: true,
              leading:
                  const Icon(LucideIcons.mapPin, color: kBlue500, size: 16),
              title: Text(
                '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                style: const TextStyle(color: kSlate200, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              tileColor: kSlate900,
              onTap: () {
                setState(() {
                  _selectedLocation =
                      LatLng(location.latitude, location.longitude);
                  _locationController.text =
                      '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
                  _searchResults = [];
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final date = (event['date'] as Timestamp).toDate();
    final timeString = DateFormat('h:mm a').format(date);
    final dateString = DateFormat('MMM dd').format(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSlate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSlate800),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: kSlate800, borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dateString.split(' ')[1], // Day number
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text(dateString.split(' ')[0].toUpperCase(), // Month
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Expanded(
                       child: Text(
                        event['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                                           ),
                     ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: kBlue500.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                      child: Text(timeString, style: const TextStyle(color: kBlue500, fontSize: 11, fontWeight: FontWeight.w600))
                    )
                  ],
                ),

                if (event['locationName'] != null &&
                    (event['locationName'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          color: kSlate500, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event['locationName'],
                          style: const TextStyle(
                              color: kSlate400, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
           const SizedBox(width: 8),
           IconButton(
             icon: const Icon(LucideIcons.moreVertical, color: kSlate600, size: 20),
             padding: EdgeInsets.zero,
             constraints: const BoxConstraints(),
             onPressed: () => _showEventOptions(context, event['id']),
           )
        ],
      ),
    );
  }

   void _showEventOptions(BuildContext context, String eventId) {
     showModalBottomSheet(
       context: context,
       backgroundColor: kSlate900,
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
       builder: (context) => SafeArea(
         child: Wrap(
           children: [
             ListTile(
               leading: const Icon(LucideIcons.trash2, color: kRed500),
               title: const Text('Delete Event', style: TextStyle(color: kRed500, fontWeight: FontWeight.w500)),
               onTap: () {
                 Navigator.pop(context);
                 _deleteEvent(eventId);
               },
             ),
           ],
         ),
       ),
     );
   }

  Future<void> _deleteEvent(String eventId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('events')
            .doc(eventId)
            .delete();
        await _loadEvents();
      }
    } catch (e) {
       print("Error deleting event: $e");
    }
  }
}

// --- LOCATION PICKER SCREEN ---
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const LocationPickerScreen({Key? key, this.initialLocation})
      : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Set<Marker> _markers = {};
  bool _isMapLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation;
      _updateMarker(_selectedLocation!);
      if (mounted) setState(() => _isMapLoading = false);
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isMapLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isMapLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isMapLoading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _updateMarker(_selectedLocation!);
        _isMapLoading = false;
      });
    }
  }

  void _updateMarker(LatLng location) {
    _markers = {
      Marker(
        markerId: const MarkerId('selected'),
        position: location,
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate900,
        title:
            const Text('Pick Location', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: kSlate200),
        actions: [
          TextButton(
            onPressed: _selectedLocation == null
                ? null
                : () => Navigator.pop(context, _selectedLocation),
            child: Text('Confirm',
                style: TextStyle(
                    color: _selectedLocation == null ? kSlate500 : kBlue500,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isMapLoading)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? const LatLng(0, 0),
                zoom: 15,
              ),
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_selectedLocation != null) {
                  controller.animateCamera(
                      CameraUpdate.newLatLng(_selectedLocation!));
                }
              },
              onTap: (location) {
                setState(() {
                  _selectedLocation = location;
                  _updateMarker(location);
                });
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          if (_isMapLoading)
            const Center(child: CircularProgressIndicator(color: kBlue500)),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSlate900.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kSlate800),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: kBlue500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedLocation == null
                          ? 'Tap map to select location'
                          : '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}