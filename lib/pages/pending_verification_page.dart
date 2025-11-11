import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verification_complete_page.dart';
import 'package:lottie/lottie.dart';

class PendingVerificationPage extends StatelessWidget {
  const PendingVerificationPage({super.key});

  Future<void> _checkStatus(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRoll = prefs.getString('last_roll');
    if (lastRoll == null) return;
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('rollNo', isEqualTo: lastRoll)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final data = q.docs.first.data();
      final verified = (data['isVerified'] ?? false) as bool;
      if (verified) {
        await prefs.setBool('pending_verification', false);
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerificationCompletePage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const yellowPrimary = Color(0xFFFFC107);
    const yellowAccent = Color(0xFFFFD54F);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus(context);
    });

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
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      const Text(
                        'Profile Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _checkStatus(context),
                        icon: const Icon(Icons.refresh, color: yellowPrimary),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Icon Container
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  yellowPrimary.withOpacity(0.3),
                                  yellowAccent.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2D2D2D),
                                ),
                                child: const Icon(
                                  Icons.hourglass_bottom,
                                  size: 70,
                                  color: yellowPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Title
                          const Text(
                            'Verification Pending',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Description Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2D2D),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade800,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Your profile is under review',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: yellowAccent,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'An administrator will review your details shortly. You will be able to access the app once verified.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Refresh Button
                          Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [yellowPrimary, yellowAccent],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: yellowPrimary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _checkStatus(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.black,
                                size: 22,
                              ),
                              label: const Text(
                                'Check Status',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Info Text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey.shade600,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'This usually takes 24-48 hours',
                                style: TextStyle(
                                  fontSize: 12,
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
          ),
        ],
      ),
    );
  }
}
