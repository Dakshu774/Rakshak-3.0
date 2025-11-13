import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate500 = Color(0xFF64748B);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kRed500 = Color(0xFFEF4444);

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- STANDARD EMAIL SIGNUP ---
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Create initial Firestore document for the user
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Active',
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context); // Go back to login/home screen
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Signup failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE SIGN-UP ---
  Future<void> _googleSignup() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Create/Update Firestore document
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': userCredential.user!.displayName ?? googleUser.displayName,
        'email': userCredential.user!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Active',
      }, SetOptions(merge: true));

      if (mounted) Navigator.pop(context); // Go back to login/home screen
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Google sign-up failed');
    } catch (e) {
      _showError('An error occurred during Google sign-up');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kRed500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
      appBar: AppBar(
        backgroundColor: kSlate950,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.chevronLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Account', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  const Text('Start your safety journey today', textAlign: TextAlign.center, style: TextStyle(color: kSlate500, fontSize: 16)),
                  const SizedBox(height: 32),

                  // GOOGLE SIGN UP BUTTON
                  _buildSocialButton(label: 'Sign up with Google', icon: LucideIcons.chrome, onTap: _googleSignup),
                  const SizedBox(height: 32),

                  const Row(children: [Expanded(child: Divider(color: kSlate800)), Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('OR USE EMAIL', style: TextStyle(color: kSlate500, fontSize: 12, fontWeight: FontWeight.bold))), Expanded(child: Divider(color: kSlate800))]),
                  const SizedBox(height: 32),

                  TextFormField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('Full Name', LucideIcons.user), validator: (value) => value != null && value.isNotEmpty ? null : 'Name required'),
                  const SizedBox(height: 16),
                  TextFormField(controller: _emailController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration('Email', LucideIcons.mail), validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email'),
                  const SizedBox(height: 16),
                  TextFormField(controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('Password', LucideIcons.lock), validator: (value) => value != null && value.length >= 6 ? null : 'Min 6 characters'),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(backgroundColor: kBlue500, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: kSlate800), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: Colors.white),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, labelStyle: const TextStyle(color: kSlate500), prefixIcon: Icon(icon, color: kSlate500, size: 20), filled: true, fillColor: kSlate900, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kSlate800)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBlue500)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kRed500)));
  }
}