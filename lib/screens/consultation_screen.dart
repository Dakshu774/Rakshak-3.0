import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({Key? key}) : super(key: key);

  @override
  _ConsultationScreenState createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isLoading = false;
  List<Map<String, dynamic>> _professionals = [];
  List<Map<String, dynamic>> _filteredProfessionals = [];

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }

  Future<void> _loadProfessionals() async {
    setState(() => _isLoading = true);
    try {
      final professionals = await FirebaseFirestore.instance
          .collection('professionals')
          .get();

      setState(() {
        _professionals = professionals.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _filteredProfessionals = _professionals;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading professionals: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterProfessionals(String query) {
    setState(() {
      _filteredProfessionals = _professionals.where((professional) {
        final name = professional['name'].toString().toLowerCase();
        final specialization = professional['specialization'].toString().toLowerCase();
        final searchLower = query.toLowerCase();
        
        return name.contains(searchLower) || 
               specialization.contains(searchLower);
      }).toList();

      if (_selectedCategory != 'All') {
        _filteredProfessionals = _filteredProfessionals
            .where((professional) => professional['category'] == _selectedCategory)
            .toList();
      }
    });
  }

  Future<void> _startChat(Map<String, dynamic> professional) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Create or get chat room
        final chatRoom = await FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: user.uid)
            .where('professionalId', isEqualTo: professional['id'])
            .get();

        String chatRoomId;
        if (chatRoom.docs.isEmpty) {
          // Create new chat room
          final newChatRoom = await FirebaseFirestore.instance
              .collection('chat_rooms')
              .add({
            'participants': [user.uid, professional['id']],
            'professionalId': professional['id'],
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': null,
            'lastMessageTime': null,
          });
          chatRoomId = newChatRoom.id;
        } else {
          chatRoomId = chatRoom.docs.first.id;
        }

        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatRoomId: chatRoomId,
              professional: professional,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not make call')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Consultation'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search professionals...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: _filterProfessionals,
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('All'),
                      _buildCategoryChip('Psychologist'),
                      _buildCategoryChip('Doctor'),
                      _buildCategoryChip('Counselor'),
                      _buildCategoryChip('Therapist'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredProfessionals.length,
                    itemBuilder: (context, index) {
                      final professional = _filteredProfessionals[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: professional['imageUrl'] != null
                                ? NetworkImage(professional['imageUrl'])
                                : null,
                            child: professional['imageUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(professional['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(professional['specialization']),
                              Text(
                                'Experience: ${professional['experience']} years',
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat),
                                onPressed: () => _startChat(professional),
                              ),
                              IconButton(
                                icon: const Icon(Icons.phone),
                                onPressed: () => _makeCall(professional['phone']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : 'All';
            _filterProfessionals(_searchController.text);
          });
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> professional;

  const ChatScreen({
    Key? key,
    required this.chatRoomId,
    required this.professional,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _messages = messages.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.chatRoomId)
            .collection('messages')
            .add({
          'text': _messageController.text,
          'senderId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.chatRoomId)
            .update({
          'lastMessage': _messageController.text,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

        _messageController.clear();
        await _loadMessages();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.professional['name']),
            Text(
              widget.professional['specialization'],
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['senderId'] ==
                          FirebaseAuth.instance.currentUser?.uid;

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            message['text'],
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 