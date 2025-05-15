// import 'package:flutter/material.dart';
// import 'package:flutter_stripe/flutter_stripe.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;

// class PaymentScreen extends StatefulWidget {
//   final Map<String, dynamic> consultant;

//   const PaymentScreen({super.key, required this.consultant});

//   @override
//   _PaymentScreenState createState() => _PaymentScreenState();
// }

// class _PaymentScreenState extends State<PaymentScreen> {
//   bool _isProcessing = false;

//   Future<void> _processPayment() async {
//     setState(() {
//       _isProcessing = true;
//     });

//     try {
//       // Fetch the current user's ID
//       String userId = FirebaseAuth.instance.currentUser?.uid ?? "unknown_user";

//       // Create Stripe Payment Intent
//       Map<String, dynamic> paymentIntent = await _createPaymentIntent(widget.consultant['price']);

//       // Initialize Stripe Payment
//       await Stripe.instance.initPaymentSheet(
//         paymentSheetParameters: SetupPaymentSheetParameters(
//           paymentIntentClientSecret: paymentIntent['client_secret'],
//           merchantDisplayName: "Women's Safety App",
//         ),
//       );

//       // Show Payment Sheet
//       await Stripe.instance.presentPaymentSheet();

//       // Save payment record in Firestore
//       await FirebaseFirestore.instance.collection('payments').add({
//         'consultantId': widget.consultant['id'],
//         'userId': userId,
//         'amount': widget.consultant['price'],
//         'timestamp': FieldValue.serverTimestamp(),
//         'status': 'success',
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Payment Successful! You can now chat.")),
//       );

//       // Navigate back and signal payment success
//       Navigator.pop(context, true);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Payment failed: ${e.toString()}")),
//       );
//     } finally {
//       setState(() {
//         _isProcessing = false;
//       });
//     }
//   }

//   Future<Map<String, dynamic>> _createPaymentIntent(double amount) async {
//     try {
//       int amountInPaise = (amount * 100).toInt();

//       final response = await http.post(
//         Uri.parse('https://YOUR_BACKEND_URL/create-payment-intent'), // Replace with your backend URL
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'amount': amountInPaise, 'currency': 'INR'}),
//       );

//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       } else {
//         throw Exception('Failed to create payment intent');
//       }
//     } catch (e) {
//       throw Exception('Payment error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Payment for ${widget.consultant['name']}"),
//         backgroundColor: Colors.deepPurple,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               "Consultation Fee: ₹${widget.consultant['price']}",
//               style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             _isProcessing
//                 ? const CircularProgressIndicator()
//                 : ElevatedButton(
//                     onPressed: _processPayment,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
//                       textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     child: const Text("Pay Now"),
//                   ),
//           ],
//         ),
//       ),
//     );
//   }
// }
