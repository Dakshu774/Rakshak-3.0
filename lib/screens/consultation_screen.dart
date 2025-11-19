import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kSlate300 = Color(0xFFCBD5E1);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kEmerald500 = Color(0xFF10B981);
const Color kRed500 = Color(0xFFEF4444);
const Color kAmber500 = Color(0xFFF59E0B);
const Color kSlate200 = Color(0xFFE2E8F0);

class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({Key? key}) : super(key: key);

  @override
  _ConsultationScreenState createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isLoading = false;
  
  // Data Lists
  List<Map<String, dynamic>> _professionals = [];
  List<Map<String, dynamic>> _filteredProfessionals = [];
  final List<String> _categories = ['All', 'Psychologist', 'Doctor', 'Counselor', 'Therapist'];

  // Razorpay Variables
  late Razorpay _razorpay;
  VoidCallback? _onPaymentSuccessAction; 

  @override
  void initState() {
    super.initState();
    
    // 1. Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // 2. Load Data
    _checkAndLoadData();
  }

  @override
  void dispose() {
    _razorpay.clear(); 
    _searchController.dispose();
    super.dispose();
  }

  // --- RAZORPAY HANDLERS ---
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment Successful: ${response.paymentId}"), backgroundColor: kEmerald500),
      );
    }
    if (_onPaymentSuccessAction != null) {
      _onPaymentSuccessAction!();
      _onPaymentSuccessAction = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment Failed: ${response.message}"), backgroundColor: kRed500),
      );
    }
    _onPaymentSuccessAction = null;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("External Wallet: ${response.walletName}")),
      );
    }
  }

  void _openRazorpayCheckout(int amount, String doctorName, String phone, VoidCallback onSuccess) {
    _onPaymentSuccessAction = onSuccess;
    var options = {
      'key': 'rzp_test_RhYYUi0QAJoIjR', 
      'amount': amount * 100,
      'name': 'Consultation App',
      'description': 'Consultation with $doctorName',
      'prefill': {'contact': '9876543210', 'email': 'user@example.com'},
      'external': {'wallets': ['paytm']}
    };
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }

  // --- DATA LOGIC (UPDATED) ---

  Future<void> _checkAndLoadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Check if ANY data exists in Firebase
      final snapshot = await FirebaseFirestore.instance.collection('professionals').get();

      // 2. ONLY if database is empty, add demo data.
      // Otherwise, we assume you have your own data there.
      if (snapshot.docs.isEmpty) {
        print("Database empty. Seeding demo data...");
        await _populateDemoData();
        // Fetch again after seeding
        await _loadProfessionals(); 
      } else {
        print("Data found in Firebase. Loading...");
        _processSnapshot(snapshot);
      }
    } catch (e) {
      print("Error checking data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _populateDemoData() async {
    // This list is only used if your database is completely empty
    final demoDocs = {
      'demo_pro_1': {
        'name': 'Dr. Sarah Wilson',
        'specialization': 'Psychologist',
        'category': 'Psychologist',
        'rating': 4.9,
        'reviews': 124,
        'imageUrl': 'https://i.pravatar.cc/150?img=47',
        'isAvailable': true,
        'phone': '+1234567890',
        'fee': 1500,
      },
      'demo_pro_2': {
        'name': 'Dr. James Carter',
        'specialization': 'Counselor',
        'category': 'Counselor',
        'rating': 4.7,
        'reviews': 89,
        'imageUrl': 'https://i.pravatar.cc/150?img=33',
        'isAvailable': false,
        'phone': '+1987654321',
        'fee': 800,
      },
      'demo_pro_3': {
        'name': 'Dr. Emily Chen',
        'specialization': 'Therapist',
        'category': 'Therapist',
        'rating': 5.0,
        'reviews': 56,
        'imageUrl': 'https://i.pravatar.cc/150?img=5',
        'isAvailable': true,
        'phone': '+1122334455',
        'fee': 1200,
      },
      'demo_pro_4': {
        'name': 'Crisis Hotline',
        'specialization': 'Emergency',
        'category': 'Doctor',
        'rating': 4.8,
        'reviews': 1024,
        'imageUrl': null,
        'isAvailable': true,
        'phone': '911',
        'fee': 0,
      },
    };

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('professionals');

      for (var entry in demoDocs.entries) {
        final docRef = collection.doc(entry.key);
        batch.set(docRef, entry.value);
      }
      await batch.commit();
    } catch (e) {
      print("Error seeding data: $e");
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
    
    final rawList = snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();

    setState(() {
      _professionals = rawList;
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

  // --- ACTION LOGIC ---

  void _handleConsultationRequest(Map<String, dynamic> professional, String actionType) {
    final int fee = professional['fee'] ?? 0;

    if (fee == 0) {
      if (actionType == 'chat') _startChat(professional);
      if (actionType == 'call') _makeCall(professional['phone']);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: kSlate900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: kSlate800)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kSlate700, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kBlue500.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(actionType == 'chat' ? LucideIcons.messageCircle : LucideIcons.phone, color: kBlue500),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Consultation Fee", style: TextStyle(color: kSlate400, fontSize: 14)),
                      Text("₹$fee", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text("You are about to consult with:", style: TextStyle(color: kSlate400)),
            const SizedBox(height: 8),
            Text(professional['name'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                _openRazorpayCheckout(
                  fee, 
                  professional['name'], 
                  professional['phone'] ?? '',
                  () {
                    if (actionType == 'chat') _startChat(professional);
                    if (actionType == 'call') _makeCall(professional['phone']);
                  }
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmerald500,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Pay with Razorpay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: kSlate500)),
            ),
          ],
        ),
      ),
    );
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

  // --- UI BUILDING ---
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
          // Search and Filter Section
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
          // List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kBlue500))
                : _filteredProfessionals.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.userX, size: 48, color: kSlate800),
                            SizedBox(height: 16),
                            Text("No specialists found",
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
    final int fee = pro['fee'] ?? 0; 

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSlate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSlate800),
      ),
      child: Column(
        children: [
          Row(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: fee == 0 ? kBlue500.withOpacity(0.1) : kEmerald500.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: fee == 0 ? kBlue500.withOpacity(0.3) : kEmerald500.withOpacity(0.3)),
                          ),
                          child: Text(
                            fee == 0 ? 'Free' : '₹$fee',
                            style: TextStyle(
                              color: fee == 0 ? kBlue500 : kEmerald500, 
                              fontSize: 12, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        )
                      ],
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: LucideIcons.messageCircle,
                  label: "Chat",
                  color: kBlue500,
                  onTap: () => _handleConsultationRequest(pro, 'chat'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: LucideIcons.phone,
                  label: "Call",
                  color: kEmerald500,
                  onTap: () => _handleConsultationRequest(pro, 'call'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))
          ],
        ),
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