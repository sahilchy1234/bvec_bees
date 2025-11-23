import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// simport 'package:firebase_performance/firebase_performance.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/pending_verification_page.dart';
import 'pages/suspended_page.dart';
import 'utils/suspension_utils.dart';
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
    const SystemUiOverlayStyle(
      statusBarColor: Color.fromARGB(255, 14, 14, 14),
      statusBarIconBrightness: Brightness.light, // White icons/text
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
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
  final isSuspended = prefs.getBool('isSuspended') ?? false;
  final storedNote = prefs.getString(SuspensionUtils.prefSuspensionNoteKey);
  final storedUntilRaw = prefs.getString(SuspensionUtils.prefSuspensionUntilKey);
  final storedUntil = SuspensionUtils.parseStoredUntil(storedUntilRaw);

  // Initialize FCM using custom auth user id from SharedPreferences
  if (isLoggedIn) {
    final storedUid = prefs.getString('current_user_uid');
    if (storedUid != null && storedUid.isNotEmpty) {
      await FCMService().initialize(storedUid);
    }
  }

  runApp(MyApp(
    startPending: pending,
    isLoggedIn: isLoggedIn,
    startSuspended: isSuspended,
    initialSuspensionNote: storedNote,
    initialSuspensionUntil: storedUntil,
  ));

}

class MyApp extends StatefulWidget {
  final bool startPending;
  final bool isLoggedIn;  
  final bool startSuspended;
  final String? initialSuspensionNote;
  final DateTime? initialSuspensionUntil;
  const MyApp({
    super.key,
    required this.startPending,
    required this.isLoggedIn,
    required this.startSuspended,
    this.initialSuspensionNote,
    this.initialSuspensionUntil,
  });  

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDynamicLinks();
  }

  Future<void> _initDynamicLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      _appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      }, onError: (Object error) {
        debugPrint('Deep link stream error: $error');
      });
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }

  void _handleDeepLink(Uri link) {
    if (link.host != 'link.getbeezy.app') {
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
      home: widget.startSuspended
          ? SuspendedPage(
              note: widget.initialSuspensionNote,
              until: widget.initialSuspensionUntil,
            )
          : widget.isLoggedIn 
              ? const HomePage()  
              : (widget.startPending 
                  ? const PendingVerificationPage() 
                  : const LoginPage()),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/pending': (context) => const PendingVerificationPage(),
        '/suspended': (context) => SuspendedPage(
              note: widget.initialSuspensionNote,
              until: widget.initialSuspensionUntil,
            ),
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
