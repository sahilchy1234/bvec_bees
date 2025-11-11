import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerificationCompletePage extends StatefulWidget {
  const VerificationCompletePage({super.key});

  @override
  State<VerificationCompletePage> createState() =>
      _VerificationCompletePageState();
}

class _VerificationCompletePageState extends State<VerificationCompletePage> {
  @override
  void initState() {
    super.initState();
    _goHomeAfterDelay();
  }

  Future<void> _goHomeAfterDelay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_verification', false);
    await prefs.setBool('isLoggedIn', true);

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    const yellowPrimary = Color(0xFFFFC107);
    const yellowAccent = Color(0xFFFFD54F);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF2D2D2D),
                  const Color(0xFF1A1A1A),
                ],
              ),
            ),
          ),
          // Glossy overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                    stops: const [0.1, 0.5, 0.9],
                  ),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Animation Container
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            yellowPrimary.withOpacity(0.2),
                            yellowAccent.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Lottie.asset(
                          'assets/lottie/check.json',
                          width: 180,
                          height: 180,
                          repeat: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Success Title
                    const Text(
                      'Verification Completed',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Success Message Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: yellowPrimary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: yellowPrimary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You can now access all features',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade400,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Loading Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: yellowPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Redirecting to home...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
