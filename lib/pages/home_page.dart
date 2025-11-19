import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'feed_page.dart';
import 'profile_page.dart';
import 'search_page.dart';
import 'conversations_page.dart';
import 'notifications_page.dart';
import 'swipe_page.dart';
import 'rumor_feed_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late ScrollController _scrollController;
  bool _showAppBar = true;
  double _lastOffset = 0.0;
  double _accumulatedDelta = 0.0;
  static const double _toggleThreshold = 24.0; // pixels
  final AuthService _authService = AuthService();
  late Future<UserModel?> _userFuture;

  Widget _pageFor(int index) {
    switch (index) {
      case 0:
        return FutureBuilder<UserModel?>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }

            final profile = snapshot.data;

            final userId = profile?.uid ?? 'unknown';
            final userName = profile?.name ?? 'User';
            final userImage = profile?.avatarUrl ?? '';
            final userEmail = profile?.email ?? '';

            return FeedPage(
              scrollController: _scrollController,
              currentUserId: userId,
              currentUserName: userName,
              currentUserImage: userImage,
              currentUserEmail: userEmail,
              onRefreshUser: () {
                setState(() {
                  _userFuture = _loadCurrentUser();
                });
              },
            );
          },
        );
      case 1:
        return RumorFeedPage(scrollController: _scrollController);
      case 2:
        return SwipePage(scrollController: _scrollController);
      case 3:
      default:
        return FutureBuilder<String>(
          future: SharedPreferences.getInstance().then((prefs) => 
            prefs.getString('current_user_uid') ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }
            return ProfilePage(
              userId: snapshot.data ?? '',
            );
          },
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _userFuture = _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<UserModel?> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_user_uid');
      
      if (uid == null || uid.isEmpty) {
        print('No user UID found in SharedPreferences');
        return null;
      }

      print('Loading user profile for UID: $uid');
      final profile = await _authService.getUserProfile(uid);
      
      if (profile != null) {
        print('Profile loaded successfully: ${profile.name}');
        return profile;
      }

      print('No profile found in Firestore, using cached data');
      // Fallback to cached data from SharedPreferences
      return UserModel(
        uid: uid,
        email: prefs.getString('current_user_email') ?? '',
        name: prefs.getString('current_user_name') ?? 'User',
        avatarUrl: prefs.getString('current_user_avatar'),
        idCardUrl: null,
        rollNo: prefs.getString('last_roll'),
        semester: null,
        branch: null,
        birthdate: null,
        gender: null,
        isVerified: prefs.getBool('isLoggedIn') ?? false,
        password: null,
      );
    } catch (e) {
      print('Error loading user: $e');
      return null;
    }
  }

  void _onScroll() {
    final current = _scrollController.position.pixels;
    final delta = current - _lastOffset;

    // Accumulate scroll delta with direction. Positive = scrolling down, Negative = up
    if (delta > 0) {
      _accumulatedDelta = (_accumulatedDelta + delta).clamp(-_toggleThreshold, 4 * _toggleThreshold);
      if (_accumulatedDelta > _toggleThreshold && _showAppBar) {
        setState(() {
          _showAppBar = false;
          _accumulatedDelta = 0;
        });
      }
    } else if (delta < 0) {
      _accumulatedDelta = (_accumulatedDelta + delta).clamp(-4 * _toggleThreshold, _toggleThreshold);
      if (_accumulatedDelta < -_toggleThreshold && !_showAppBar) {
        setState(() {
          _showAppBar = true;
          _accumulatedDelta = 0;
        });
      }
    }

    _lastOffset = current;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showGlobalAppBar = _selectedIndex != 2;
    const double appBarGap = 25;
    final double topPadding = showGlobalAppBar ? (70 + appBarGap) : 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: null,
      body: Stack(
        children: [
          // Content underneath
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: _pageFor(_selectedIndex),
            ),
          ),
          // Animated top bar overlay
          if (showGlobalAppBar)
            SafeArea(
              bottom: false,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: _showAppBar ? const Offset(0, 0) : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: _showAppBar ? 1 : 0,
                  child: Container(
                    height: 70,
                    color: const Color.fromARGB(255, 14, 14, 14),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Beezy',
                            style: GoogleFonts.dancingScript(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search, size: 25),
                              color: Colors.white,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SearchPage(),
                                  ),
                                );
                              },
                              tooltip: 'Search',
                            ),
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.heart, size: 18),
                              color: Colors.white,
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final currentUserId =
                                    prefs.getString('current_user_uid') ?? '';

                                if (currentUserId.isEmpty) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NotificationsPage(
                                      currentUserId: currentUserId,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Activity',
                            ),
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.comment, size: 18),
                              color: Colors.white,
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                final currentUserId = prefs.getString('current_user_uid') ?? '';
                                final currentUserName = prefs.getString('current_user_name') ?? 'User';
                                final currentUserImage = prefs.getString('current_user_avatar') ?? '';

                                if (currentUserId.isEmpty) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ConversationsPage(
                                      currentUserId: currentUserId,
                                      currentUserName: currentUserName,
                                      currentUserImage: currentUserImage,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Messages',
                            ),
                            
                            const SizedBox(width: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 0, left: 0, right: 0), // Padding outside nav bar
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03), // Transparent glass effect
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: const Border(
                  top: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white54,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                items: [
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                      child: FaIcon(
                        _selectedIndex == 0 ? FontAwesomeIcons.houseChimney : FontAwesomeIcons.house,
                        color: _selectedIndex == 0 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                    label: 'Feed',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FaIcon(
                        _selectedIndex == 1 ? FontAwesomeIcons.fire : FontAwesomeIcons.fire,
                        color: _selectedIndex == 1 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                    label: 'Rumors',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        _selectedIndex == 2 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                        color: _selectedIndex == 2 ? Colors.white : Colors.white54,
                        size: 24,
                      ),
                    ),
                    label: 'Hot & Not',
                  ),
                  BottomNavigationBarItem(
                    icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FaIcon(
                        _selectedIndex == 3 ? FontAwesomeIcons.solidUser : FontAwesomeIcons.user,
                        color: _selectedIndex == 3 ? Colors.white : Colors.white54,
                        size: 20,
                      ),
                    ),
                    label: 'Profile',
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
