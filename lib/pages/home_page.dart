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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late ScrollController _scrollController;
  late AnimationController _appBarAnimationController;
  late Animation<double> _appBarAnimation;
  
  double _lastScrollOffset = 0.0;
  bool _isAppBarVisible = true;
  
  static const double _appBarHeight = 70;
  static const double _appBarExtraGap = 25;
  static const double _scrollThreshold = 5.0; // Reduced threshold for faster response
  
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
    
    // Initialize animation controller for smooth transitions
    _appBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Fast like Instagram
    );
    
    _appBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start with app bar visible
    _appBarAnimationController.value = 1.0;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _appBarAnimationController.dispose();
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
    if (!_scrollController.hasClients) return;
    
    final currentOffset = _scrollController.offset;
    final difference = currentOffset - _lastScrollOffset;
    
    // Show app bar when at the top
    if (currentOffset <= 0) {
      if (!_isAppBarVisible) {
        _showAppBar();
      }
      _lastScrollOffset = currentOffset;
      return;
    }
    
    // Only trigger on meaningful scroll
    if (difference.abs() < _scrollThreshold) {
      return;
    }
    
    // Scrolling down - hide app bar
    if (difference > 0 && _isAppBarVisible) {
      _hideAppBar();
    }
    // Scrolling up - show app bar
    else if (difference < 0 && !_isAppBarVisible) {
      _showAppBar();
    }
    
    _lastScrollOffset = currentOffset;
  }

  void _showAppBar() {
    _isAppBarVisible = true;
    _appBarAnimationController.forward();
  }

  void _hideAppBar() {
    _isAppBarVisible = false;
    _appBarAnimationController.reverse();
  }

  void _onItemTapped(int index) {
    // Reset scroll position and show app bar when changing tabs
    if (_selectedIndex != index) {
      _lastScrollOffset = 0.0;
      _showAppBar();
    }
    
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showGlobalAppBar = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 14, 14, 14),
      appBar: null,
      body: Stack(
        children: [
          // Content underneath with animated padding
          SafeArea(
            top: false,
            child: AnimatedBuilder(
              animation: _appBarAnimation,
              builder: (context, child) {
                final topPadding = showGlobalAppBar 
                    ? (_appBarHeight + _appBarExtraGap) * _appBarAnimation.value 
                    : 0.0;
                
                return Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: _pageFor(_selectedIndex),
                );
              },
            ),
          ),
          // Animated top bar overlay
          if (showGlobalAppBar)
            SafeArea(
              bottom: false,
              child: AnimatedBuilder(
                animation: _appBarAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_appBarHeight * (1 - _appBarAnimation.value)),
                    child: Opacity(
                      opacity: _appBarAnimation.value,
                      child: Container(
                        height: _appBarHeight,
                        color: const Color.fromARGB(255, 14, 14, 14),
                        padding: const EdgeInsets.only(left: 8, bottom: 30),
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
                                    final prefs = await SharedPreferences.getInstance();
                                    final currentUserId = prefs.getString('current_user_uid') ?? '';

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
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 0, left: 0, right: 0),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
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