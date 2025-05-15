class Event {
  final String title;
  final String date;
  final String time;
  final String description;

  Event({
    required this.title,
    required this.date,
    required this.time,
    required this.description,
  });

  // Convert event to Map (for storing in Firestore)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': date,
      'time': time,
      'description': description,
    };
  }

  // Convert Firestore data to Event
  factory Event.fromFirestore(Map<String, dynamic> firestoreData) {
    return Event(
      title: firestoreData['title'],
      date: firestoreData['date'],
      time: firestoreData['time'],
      description: firestoreData['description'],
    );
  }
}
