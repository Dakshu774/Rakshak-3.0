import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- THEME CONSTANTS ---
const Color kSlate950 = Color(0xFF020617);
const Color kSlate900 = Color(0xFF0F172A);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate500 = Color(0xFF64748B);
const Color kBlue500 = Color(0xFF3B82F6);
const Color kRed500 = Color(0xFFEF4444);

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _handleRememberMe();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false); return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': userCredential.user!.displayName ?? googleUser.displayName,
        'email': userCredential.user!.email,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Google sign-in failed');
    } catch (e) {
      _showError('An error occurred during Google sign-in');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
    } else {
      await prefs.remove('saved_email');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kRed500),
    );
  }
// END OF PART 1
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlate950,
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
                  const Icon(LucideIcons.shieldCheck, size: 64, color: kBlue500),
                  const SizedBox(height: 32),
                  const Text('Welcome Back', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  const Text('Sign in to your secure dashboard', textAlign: TextAlign.center, style: TextStyle(color: kSlate500, fontSize: 16)),
                  const SizedBox(height: 48),

                  TextFormField(controller: _emailController, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration('Email', LucideIcons.mail)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('Password', LucideIcons.lock).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye, color: kSlate500),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(value: _rememberMe, activeColor: kBlue500, side: const BorderSide(color: kSlate500), onChanged: (value) => setState(() => _rememberMe = value!)),
                          const Text('Remember me', style: TextStyle(color: kSlate500)),
                        ],
                      ),
                      TextButton(onPressed: () {}, child: const Text('Forgot Password?', style: TextStyle(color: kBlue500, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: kBlue500, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 32),
                  const Row(children: [Expanded(child: Divider(color: kSlate800)), Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('OR CONTINUE WITH', style: TextStyle(color: kSlate500, fontSize: 12, fontWeight: FontWeight.bold))), Expanded(child: Divider(color: kSlate800))]),
                  const SizedBox(height: 32),

                  // GOOGLE BUTTON
                  _buildSocialButton(label: 'Sign in with Google', icon: LucideIcons.chrome, onTap: _googleLogin),

                  const SizedBox(height: 48),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Don't have an account? ", style: TextStyle(color: kSlate500)), GestureDetector(onTap: () => Navigator.pushNamed(context, '/signup'), child: const Text('Sign Up', style: TextStyle(color: kBlue500, fontWeight: FontWeight.bold)))]),
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