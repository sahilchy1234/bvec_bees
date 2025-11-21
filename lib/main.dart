import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// simport 'package:firebase_performance/firebase_performance.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/pending_verification_page.dart';
import 'pages/post_detail_page.dart';
import 'pages/rumor_detail_page.dart';
import 'services/fcm_service.dart';

import 'firebase_options.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _initializeFCMForCurrentUser() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await FCMService().initialize(currentUser.uid);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: const Color.fromARGB(255, 0, 0, 0),
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize FCM for any already signed-in user
  await _initializeFCMForCurrentUser();

  // Keep FCM in sync with auth state changes
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      FCMService().initialize(user.uid);
    }
  });
  
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

  // Initialize FCM using custom auth user id from SharedPreferences
  if (isLoggedIn) {
    final storedUid = prefs.getString('current_user_uid');
    if (storedUid != null && storedUid.isNotEmpty) {
      await FCMService().initialize(storedUid);
    }
  }

  runApp(MyApp(startPending: pending, isLoggedIn: isLoggedIn));

}

class MyApp extends StatefulWidget {
  final bool startPending;
  final bool isLoggedIn;  
  const MyApp({super.key, required this.startPending, required this.isLoggedIn});  

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initDynamicLinks();
  }

  Future<void> _initDynamicLinks() async {
    try {
      final instance = FirebaseDynamicLinks.instance;

      final initialData = await instance.getInitialLink();
      if (initialData != null) {
        _handleDeepLink(initialData.link);
      }

      instance.onLink.listen((PendingDynamicLinkData data) {
        _handleDeepLink(data.link);
      }).onError((Object error) {
        debugPrint('Dynamic link error: $error');
      });
    } catch (e) {
      debugPrint('Failed to initialize dynamic links: $e');
    }
  }

  void _handleDeepLink(Uri link) {
    if (link.host != 'getbeezy.app') {
      return;
    }
    if (link.pathSegments.isEmpty) {
      return;
    }

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    final first = link.pathSegments.first;
    if (first == 'post' && link.pathSegments.length >= 2) {
      final postId = link.pathSegments[1];
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(postId: postId),
        ),
      );
    } else if (first == 'rumor' && link.pathSegments.length >= 2) {
      final rumorId = link.pathSegments[1];
      navigator.push(
        MaterialPageRoute(
          builder: (_) => RumorDetailPage(rumorId: rumorId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'BVEC ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.windows: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.linux: NoAnimationPageTransitionsBuilder(),
          },
        ),
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color.fromARGB(255, 14, 14, 14),
          ),
        ),
      ),
      home: widget.isLoggedIn 
          ? const HomePage()  
          : (widget.startPending 
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

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
