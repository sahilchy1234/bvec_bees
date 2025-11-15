import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import 'pending_verification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _rollController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService.loginWithRollNo(
        _rollController.text.toLowerCase(),
        _passwordController.text,
      );
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_roll', (user.rollNo ?? '').toLowerCase());
      await prefs.setString('current_user_uid', user.uid);
      await prefs.setString('current_user_name', user.name ?? 'User');
      await prefs.setString('current_user_email', user.email);
      await prefs.setString('current_user_avatar', user.avatarUrl ?? '');
      
      if (user.isVerified) {
        await prefs.setBool('pending_verification', false);
        await prefs.setBool('isLoggedIn', true);  
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        await prefs.setBool('pending_verification', true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingVerificationPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryYellow = const Color(0xFFFFD600); // Bright yellow
    final darkBackground = const Color(0xFF181818);

    return Scaffold(
      backgroundColor: darkBackground,
      body: Stack(
        
        children: [
          // Yellow glow blur background
          Positioned(

            
            top: -60,
            left: -60,

            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryYellow.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          // Glossy blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const SizedBox(),
            ),
          ),
          // Main login content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryYellow.withOpacity(0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        "Welcome back!",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryYellow,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _rollController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: primaryYellow,
                        decoration: InputDecoration(
                          labelText: 'Roll Number',
                          labelStyle: TextStyle(color: primaryYellow),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: primaryYellow, width: 2),
                          ),
                          floatingLabelStyle: TextStyle(
                            color: primaryYellow,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: primaryYellow,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: primaryYellow),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: primaryYellow, width: 2),
                          ),
                          floatingLabelStyle: TextStyle(
                            color: primaryYellow,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 8,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('Login'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                         Navigator.pushNamed(context, '/register');

          //                  Navigator.pushReplacement(
          //   context,
          //   MaterialPageRoute(builder: (_) => const VerificationCompletePage()),
          // );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: primaryYellow,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        child: const Text('Don\'t have an account? Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
