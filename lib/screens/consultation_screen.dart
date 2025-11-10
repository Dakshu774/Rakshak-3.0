import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
const Color kEmerald500 = Color(0xFF10B981);
const Color kRed500 = Color(0xFFEF4444);
const Color kAmber500 = Color(0xFFF59E0B);

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

  final List<String> _categories = ['All', 'Psychologist', 'Doctor', 'Counselor', 'Therapist'];

  @override
  void initState() {
    super.initState();
    _checkAndLoadData();
  }

  // --- SMART DATA LOADING ---
  Future<void> _checkAndLoadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('professionals').get();

      if (snapshot.docs.isEmpty) {
        print("Database empty, creating demo data...");
        await _populateDemoData();
      } else {
        _processSnapshot(snapshot);
      }
    } catch (e) {
      print("Error checking data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _populateDemoData() async {
    final demoDocs = {
      'demo_pro_1': {
        'name': 'Dr. Sarah Wilson',
        'specialization': 'Psychologist',
        'category': 'Psychologist',
        'rating': 4.9,
        'reviews': 124,
        'imageUrl': 'https://i.pravatar.cc/150?img=47',
        'isAvailable': true,
        'phone': '+1234567890'
      },
      'demo_pro_2': {
        'name': 'Dr. James Carter',
        'specialization': 'Counselor',
        'category': 'Counselor',
        'rating': 4.7,
        'reviews': 89,
        'imageUrl': 'https://i.pravatar.cc/150?img=33',
        'isAvailable': false,
        'phone': '+1987654321'
      },
      'demo_pro_3': {
        'name': 'Dr. Emily Chen',
        'specialization': 'Therapist',
        'category': 'Therapist',
        'rating': 5.0,
        'reviews': 56,
        'imageUrl': 'https://i.pravatar.cc/150?img=5',
        'isAvailable': true,
        'phone': '+1122334455'
      },
      'demo_pro_4': {
        'name': 'Crisis Hotline',
        'specialization': 'Emergency',
        'category': 'Doctor',
        'rating': 4.8,
        'reviews': 1024,
        'imageUrl': null,
        'isAvailable': true,
        'phone': '911'
      },
    };

    try {
       for (var entry in demoDocs.entries) {
         await FirebaseFirestore.instance
             .collection('professionals')
             .doc(entry.key)
             .set(entry.value, SetOptions(merge: true));
       }
       await _loadProfessionals();
    } catch (e) {
       print("Error populating data: $e");
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfessionals() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('professionals').get();
      _processSnapshot(snapshot);
    } catch (e) {
      print("Error loading professionals: $e");
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processSnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _professionals = snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
      _filteredProfessionals = _professionals;
      if (_selectedCategory != 'All' || _searchController.text.isNotEmpty) {
         _filterProfessionals(_searchController.text);
      }
      _isLoading = false;
    });
  }

  void _filterProfessionals(String query) {
    setState(() {
      _filteredProfessionals = _professionals.where((professional) {
        final name = (professional['name'] ?? '').toString().toLowerCase();
        final specialization = (professional['specialization'] ?? '').toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || specialization.contains(searchLower);
      }).toList();

      if (_selectedCategory != 'All') {
        _filteredProfessionals = _filteredProfessionals
            .where((pro) =>
                (pro['specialization'] == _selectedCategory) ||
                (pro['category'] == _selectedCategory))
            .toList();
      }
    });
  }

  Future<void> _startChat(Map<String, dynamic> professional) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final chatRoom = await FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: user.uid)
            .get();

        var relevantRooms = chatRoom.docs.where((doc) {
           List<dynamic> participants = doc['participants'];
           return participants.contains(professional['id']);
        }).toList();

        String chatRoomId;
        if (relevantRooms.isEmpty) {
          final newChatRoom = await FirebaseFirestore.instance.collection('chat_rooms').add({
            'participants': [user.uid, professional['id']],
            'professionalId': professional['id'],
            'userId': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': null,
            'lastMessageTime': null,
          });
          chatRoomId = newChatRoom.id;
        } else {
          chatRoomId = relevantRooms.first.id;
        }

        if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e'), backgroundColor: kRed500),
        );
      }
    }
  }

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available'), backgroundColor: kSlate700),
      );
      return;
    }
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make call'), backgroundColor: kRed500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate900.withOpacity(0.8),
        elevation: 0,
        title: const Text('Professional Help',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: kSlate800, height: 1.0)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              color: kSlate900,
              border: Border(bottom: BorderSide(color: kSlate800)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _filterProfessionals,
                  decoration: InputDecoration(
                    hintText: 'Search specialists...',
                    hintStyle: const TextStyle(color: kSlate500),
                    prefixIcon: const Icon(LucideIcons.search, color: kSlate500, size: 20),
                    filled: true,
                    fillColor: kSlate950,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedCategory = category;
                              _filterProfessionals(_searchController.text);
                            });
                          },
                          backgroundColor: kSlate800,
                          selectedColor: kBlue500.withOpacity(0.2),
                          checkmarkColor: kBlue500,
                          labelStyle: TextStyle(
                            color: isSelected ? kBlue500 : kSlate300,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? kBlue500 : kSlate700,
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kBlue500))
                : _filteredProfessionals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.userX, size: 48, color: kSlate800),
                            const SizedBox(height: 16),
                            const Text("No specialists found",
                                style: TextStyle(color: kSlate500, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProfessionals.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildProfessionalCard(_filteredProfessionals[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  Widget _buildProfessionalCard(Map<String, dynamic> pro) {
    final String name = pro['name'] ?? 'Unknown';
    final String type = pro['specialization'] ?? 'Specialist';
    final String? imageUrl = pro['imageUrl'];
    final double rating = (pro['rating'] is int)
        ? (pro['rating'] as int).toDouble()
        : (pro['rating'] as double?) ?? 4.8;
    final int reviews = (pro['reviews'] as int?) ?? 0;
    final bool isAvailable = pro['isAvailable'] ?? true;

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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kSlate800,
              borderRadius: BorderRadius.circular(12),
              image: imageUrl != null
                  ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: imageUrl == null
                ? const Icon(LucideIcons.user, color: kSlate500, size: 24)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(color: kBlue500, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(LucideIcons.star, size: 14, color: kAmber500),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (reviews > 0)
                      Text(
                        ' ($reviews)',
                        style: const TextStyle(color: kSlate500, fontSize: 13),
                      ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAvailable ? kEmerald500.withOpacity(0.1) : kSlate800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isAvailable ? kEmerald500 : kSlate500,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAvailable ? 'Available' : 'Busy',
                            style: TextStyle(
                              color: isAvailable ? kEmerald500 : kSlate500,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              _buildActionButton(
                icon: LucideIcons.messageCircle,
                color: kBlue500,
                onTap: () => _startChat(pro),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: LucideIcons.phone,
                color: kEmerald500,
                onTap: () => _makeCall(pro['phone']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// --- CHAT SCREEN ---
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

  Stream<QuerySnapshot>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.chatRoomId)
            .collection('messages')
            .add({
          'text': messageText,
          'senderId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.chatRoomId)
            .update({
          'lastMessage': messageText,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e'), backgroundColor: kRed500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate900,
        iconTheme: const IconThemeData(color: kSlate200),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kSlate800,
              backgroundImage: widget.professional['imageUrl'] != null
                  ? NetworkImage(widget.professional['imageUrl'])
                  : null,
              child: widget.professional['imageUrl'] == null
                  ? const Icon(LucideIcons.user, size: 16, color: kSlate500)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.professional['name'] ?? 'Chat',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(
                  widget.professional['specialization'] ?? '',
                  style: const TextStyle(color: kSlate400, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong', style: TextStyle(color: kRed500)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kBlue500));
                }

                final docs = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final message = docs[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] ==
                        FirebaseAuth.instance.currentUser?.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? kBlue500 : kSlate800,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 20),
                          ),
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : kSlate200,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: kSlate900,
              border: Border(top: BorderSide(color: kSlate800)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: kSlate500),
                      filled: true,
                      fillColor: kSlate950,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: kBlue500,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}