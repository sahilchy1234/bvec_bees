import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/engagement_service.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../models/conversation_model.dart';
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

  static const double _appBarHeight = 53;
  static const double _appBarExtraGap = 16;

  final AuthService _authService = AuthService();
  late Future<UserModel?> _userFuture;
  final EngagementService _engagementService = EngagementService();
  Timer? _engagementTimer;
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  String? _currentUserIdForBadges;

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
          future: SharedPreferences.getInstance().then(
            (prefs) => prefs.getString('current_user_uid') ?? '',
          ),
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

  Future<void> _loadCurrentUserIdForBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_user_uid');

      if (!mounted) {
        _currentUserIdForBadges = uid;
        return;
      }

      setState(() {
        _currentUserIdForBadges = uid;
      });
    } catch (e) {
      debugPrint('Error loading user id for badges: $e');
    }
  }

  void _startEngagementScheduler() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_user_uid');

      if (uid == null || uid.isEmpty) {
        return;
      }

      _engagementTimer?.cancel();
      _engagementTimer = Timer.periodic(
        const Duration(hours: 4),
        (_) {
          _engagementService.sendEngagementNotification(uid);
        },
      );
    } catch (e) {
      print('Error starting engagement scheduler: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _userFuture = _loadCurrentUser();
    _startEngagementScheduler();
    _loadCurrentUserIdForBadges();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _engagementTimer?.cancel();
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showGlobalAppBar = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      appBar: null,
      body: Stack(
        children: [
          // Content underneath with animated padding
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: showGlobalAppBar ? (_appBarHeight + _appBarExtraGap) : 0.0,
              ),
              child: _pageFor(_selectedIndex),
            ),
          ),
          // Top bar overlay
          if (showGlobalAppBar)
            SafeArea(
              bottom: false,
              child: Container(
                height: _appBarHeight,
                color: const Color.fromARGB(255, 14, 14, 14),
                padding: const EdgeInsets.only(left: 8, bottom: 16),
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
                        if (_currentUserIdForBadges == null || _currentUserIdForBadges!.isEmpty)
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
                          )
                        else
                          StreamBuilder<QuerySnapshot>(
                            stream: _notificationService.getUserNotifications(
                              _currentUserIdForBadges!,
                            ),
                            builder: (context, snapshot) {
                              int unreadCount = 0;
                              if (snapshot.hasData) {
                                for (final doc in snapshot.data!.docs) {
                                  final data =
                                      doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                                  final type = (data['type'] as String?) ?? '';
                                  final isRead = (data['isRead'] as bool?) ?? false;
                                  if (type != 'chat' && !isRead) {
                                    unreadCount++;
                                  }
                                }
                              }

                              final showBadge = unreadCount > 0;
                              final badgeText = unreadCount > 9 ? '9+' : '$unreadCount';

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const FaIcon(FontAwesomeIcons.heart, size: 18),
                                    color: Colors.white,
                                    onPressed: () async {
                                      final prefs = await SharedPreferences.getInstance();
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
                                  if (showBadge)
                                    Positioned(
                                      right: 4,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          badgeText,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        if (_currentUserIdForBadges == null || _currentUserIdForBadges!.isEmpty)
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
                          )
                        else
                          StreamBuilder<List<Conversation>>(
                            stream: _chatService.streamConversations(_currentUserIdForBadges!),
                            builder: (context, snapshot) {
                              int totalUnread = 0;
                              if (snapshot.hasData) {
                                for (final c in snapshot.data!) {
                                  totalUnread +=
                                      c.unreadCounts[_currentUserIdForBadges!] ?? 0;
                                }
                              }

                              final showBadge = totalUnread > 0;
                              final badgeText = totalUnread > 9 ? '9+' : '$totalUnread';

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
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
                                  if (showBadge)
                                    Positioned(
                                      right: 4,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.yellow,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          badgeText,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ],
                ),
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