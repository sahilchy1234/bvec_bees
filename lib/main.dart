import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_completion_page.dart';
import 'pages/home_page.dart';
import 'services/auth_service.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Performance Monitoring
  FirebasePerformance performance = FirebasePerformance.instance;
  await performance.setPerformanceCollectionEnabled(true);
  
  // Set up connectivity monitoring
  Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
    debugPrint('Connectivity changed: $result');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BVEC ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          // Check if user profile is complete
          final user = snapshot.data!;
          return FutureBuilder(
            future: AuthService().getUserProfile(user.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userProfile = profileSnapshot.data;
              if (userProfile == null || !userProfile.isProfileComplete) {
                return ProfileCompletionPage(
                  uid: user.uid,
                  email: user.email!,
                );
              }

              // Navigate to your home page
              return const HomePage();
            },
          );
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}


