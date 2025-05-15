import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Make sure this is imported for Firestore usage
import 'event.dart'; // Your event model

class EventPlannerScreen extends StatefulWidget {
  const EventPlannerScreen({super.key});

  @override
  _EventPlannerScreenState createState() => _EventPlannerScreenState();
}

class _EventPlannerScreenState extends State<EventPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventTitleController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _eventTimeController = TextEditingController();
  final _eventDescriptionController = TextEditingController();

  // Add event to Firestore
  Future<void> _addEvent() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Create event data
      final event = Event(
        title: _eventTitleController.text,
        date: _eventDateController.text,
        time: _eventTimeController.text,
        description: _eventDescriptionController.text,
      );

      // Save event to Firestore
      try {
        await FirebaseFirestore.instance.collection('events').add({
          'title': event.title,
          'date': event.date,
          'time': event.time,
          'description': event.description,
          'created_at': FieldValue.serverTimestamp(),
        });
        // Clear the form fields
        _eventTitleController.clear();
        _eventDateController.clear();
        _eventTimeController.clear();
        _eventDescriptionController.clear();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event added successfully!')),
        );
      } catch (e) {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Title Field
              TextFormField(
                controller: _eventTitleController,
                decoration: const InputDecoration(labelText: 'Event Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              
              // Event Date Field
              TextFormField(
                controller: _eventDateController,
                decoration: const InputDecoration(labelText: 'Event Date'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Event Time Field
              TextFormField(
                controller: _eventTimeController,
                decoration: const InputDecoration(labelText: 'Event Time'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event time';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Event Description Field
              TextFormField(
                controller: _eventDescriptionController,
                decoration: const InputDecoration(labelText: 'Event Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Add Event Button
              ElevatedButton(
                onPressed: _addEvent,
                child: const Text('Add Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
