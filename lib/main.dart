import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// simport 'package:firebase_performance/firebase_performance.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/pending_verification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fcm_service.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize FCM
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await FCMService().initialize(currentUser.uid);
  }
  
  // Initialize Performance Monitoring
  // FirebasePerformance performance = FirebasePerformance.instance;
  // sawait performance.setPerformanceCollectionEnabled(true);
  
  // Set up connectivity monitoring
  Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
    debugPrint('Connectivity changed: $result');
  });
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getBool('pending_verification') ?? false;
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;  
  runApp(MyApp(startPending: pending, isLoggedIn: isLoggedIn));  

}

class MyApp extends StatelessWidget {
  final bool startPending;
  final bool isLoggedIn;  
  const MyApp({super.key, required this.startPending, required this.isLoggedIn});  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BVEC ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn 
          ? const HomePage()  
          : (startPending 
              ? const PendingVerificationPage() 
              : const LoginPage()),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/pending': (context) => const PendingVerificationPage(),
      },
    );
  }
}
