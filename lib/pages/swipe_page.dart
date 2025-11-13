import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/hot_not_service.dart';
import '../services/auth_service.dart';
import '../models/match_model.dart';
import 'chat_page.dart';
import 'hotnot_chats_page.dart';
import 'dart:math' as math;
import 'profile_page.dart';

enum _HotNotTab { feed, hotted, matches, leaderboard }

class SwipePage extends StatefulWidget {
  final ScrollController scrollController;
  final String? currentUserId;

  const SwipePage({
    super.key,
    required this.scrollController,
    this.currentUserId,
  });

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> with TickerProviderStateMixin {
  final HotNotService _hotNotService = HotNotService();
  final AuthService _authService = AuthService();
  List<UserModel> _potentialMatches = [];
  List<UserModel> _hottedUsers = [];
  List<Match> _matches = [];
  List<UserModel> _leaderboardUsers = [];
  bool _isLoading = true;
  bool _isLoadingHotted = false;
  bool _isLoadingMatches = false;
  bool _isLoadingLeaderboard = false;
  int _currentIndex = 0;
  String _currentUserId = '';
  UserModel? _currentUser;
  String? _genderFilter;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isAnimating = false;
  bool _showMatchAnimation = false;
  UserModel? _matchedUser;
  _HotNotTab _selectedTab = _HotNotTab.feed;
  final Map<String, UserModel?> _userCache = {};
  StreamSubscription<List<UserModel>>? _hottedSubscription;
  StreamSubscription<List<Match>>? _matchesSubscription;
  bool _hasLoadedHotted = false;
  bool _hasLoadedMatches = false;
  bool _hasLoadedLeaderboard = false;
  final Set<String> _unhottingUserIds = <String>{};

  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId ?? '';
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _loadMatches();
  }

  void _selectTab(_HotNotTab tab) {
    if (tab == _selectedTab) return;
    setState(() => _selectedTab = tab);
    switch (tab) {
      case _HotNotTab.hotted:
        _loadHottedUsers();
        break;
      case _HotNotTab.matches:
        _loadMatchesList();
        break;
      case _HotNotTab.leaderboard:
        _loadLeaderboard();
        break;
      case _HotNotTab.feed:
        _loadMatches();
        break;
    }
  }

  UserModel? _getUserFromCache(String userId) {
    return _userCache[userId];
  }

  void _openMatchChat(Match match) {
    if (_currentUser == null) return;
    final otherUserId = match.user1Id == _currentUserId
        ? match.user2Id
        : match.user1Id;
    final otherUser = _getUserFromCache(otherUserId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: match.conversationId ?? '',
          currentUserId: _currentUserId,
          currentUserName: _currentUser!.name ?? 'You',
          currentUserImage: _currentUser!.avatarUrl ?? '',
          otherUserId: otherUserId,
          otherUserName: otherUser?.name ?? 'Match',
          otherUserImage: otherUser?.avatarUrl ?? '',
          isMatchChat: true,
        ),
      ),
    );
  }

  Future<void> _loadHottedUsers() async {
    if (_currentUserId.isEmpty || _hasLoadedHotted) return;
    setState(() => _isLoadingHotted = true);
    _hasLoadedHotted = true;
    _hottedSubscription?.cancel();
    try {
      _hottedSubscription = _hotNotService
          .streamHottedUsers(_currentUserId)
          .listen((users) {
        if (!mounted) return;
        setState(() {
          _hottedUsers = users;
          _isLoadingHotted = false;
        });
      }, onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoadingHotted = false;
          _hasLoadedHotted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hotted users: $error')),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHotted = false;
        _hasLoadedHotted = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading hotted users: $e')),
      );
    }
  }

  Future<void> _loadMatchesList() async {
    if (_currentUserId.isEmpty || _hasLoadedMatches) return;
    setState(() => _isLoadingMatches = true);
    _hasLoadedMatches = true;
    _matchesSubscription?.cancel();
    try {
      _matchesSubscription = _hotNotService
          .streamMatches(_currentUserId)
          .listen((matchList) async {
        if (!mounted) return;
        final updatedMatches = <Match>[];
        for (final match in matchList) {
          final otherUserId = match.user1Id == _currentUserId
              ? match.user2Id
              : match.user1Id;
          if (!_userCache.containsKey(otherUserId)) {
            _userCache[otherUserId] = await _authService.getUserProfile(otherUserId);
          }
          updatedMatches.add(match);
        }
        if (!mounted) return;
        setState(() {
          _matches = updatedMatches;
          _isLoadingMatches = false;
        });
      }, onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoadingMatches = false;
          _hasLoadedMatches = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matches: $error')),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMatches = false;
        _hasLoadedMatches = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading matches: $e')),
      );
    }
  }

  Future<void> _loadLeaderboard() async {
    if (_currentUserId.isEmpty || _hasLoadedLeaderboard) return;
    setState(() => _isLoadingLeaderboard = true);
    _hasLoadedLeaderboard = true;
    try {
      final topUsers = await _hotNotService.getLeaderboard();
      if (!mounted) return;
      setState(() {
        _leaderboardUsers = topUsers;
        _isLoadingLeaderboard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLeaderboard = false;
        _hasLoadedLeaderboard = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading leaderboard: $e')),
      );
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _scaleController.dispose();
    _hottedSubscription?.cancel();
    _matchesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      if (_currentUserId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _currentUserId = prefs.getString('current_user_uid') ?? '';
      }

      if (_currentUserId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Load current user profile
      _currentUser = await _authService.getUserProfile(_currentUserId);

      if (_currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Preload other sections
      _loadHottedUsers();
      _loadMatchesList();
      _loadLeaderboard();

      // Get feed using Hot & Not algorithm
      final feedUsers = await _hotNotService.getFeed(
        currentUserId: _currentUserId,
        currentUserGender: _currentUser!.gender,
        lookingFor: _currentUser!.lookingFor,
        genderFilter: _genderFilter,
      );

      setState(() {
        _potentialMatches = feedUsers;
        _currentIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed: $e')),
        );
      }
    }
  }

  void _handleDragStart() {
    if (_isAnimating) return;
    _isDragging = true;
    _isAnimating = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    final width = MediaQuery.of(context).size.width;
    setState(() {
      final dx = details.delta.dx / width;
      final dy = details.delta.dy / 400;
      final updated = _dragOffset + Offset(dx, dy);
      _dragOffset = Offset(
        updated.dx.clamp(-1.5, 1.5),
        updated.dy.clamp(-0.5, 0.5),
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final threshold = 0.25;
    final velocityX = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.dx > threshold || velocityX > 800) {
      _triggerSwipe(true);
    } else if (_dragOffset.dx < -threshold || velocityX < -800) {
      _triggerSwipe(false);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
      });
    }
  }

  void _triggerSwipe(bool isHot) {
    if (_isAnimating) return;
    final startOffset = _dragOffset;
    setState(() {
      _isDragging = false;
      _isAnimating = true;
    });
    _vote(isHot, startOffset: startOffset);
  }

  Future<void> _vote(bool isHot, {Offset startOffset = Offset.zero}) async {
    if (_currentIndex >= _potentialMatches.length) return;

    final targetUser = _potentialMatches[_currentIndex];

    try {
      // Animate swipe
      _swipeAnimation = Tween<Offset>(
        begin: startOffset,
        end: Offset(isHot ? 1.5 : -1.5, startOffset.dy),
      ).animate(CurvedAnimation(
        parent: _swipeController,
        curve: Curves.easeOut,
      ));

      final animationFuture = _swipeController.forward();

      // Use Hot & Not service for voting
      final isMatchFuture = _hotNotService.castVote(
        voterId: _currentUserId,
        targetId: targetUser.uid,
        isHot: isHot,
      );

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        animationFuture,
        isMatchFuture,
      ]);
      final isMatch = results[1] as bool;

      _swipeController.reset();

      if (!mounted) return;

      // Show match animation if it's a match
      if (isMatch && isHot) {
        _showMatchDialog(targetUser);
      }

      setState(() {
        _dragOffset = Offset.zero;
        _isAnimating = false;
        _currentIndex++;
        if (_currentIndex >= _potentialMatches.length) {
          _loadMatches();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voting: $e')),
        );
        _swipeController.reset();
        setState(() {
          _dragOffset = Offset.zero;
          _isAnimating = false;
        });
      }
    }
  }

  void _showMatchDialog(UserModel matchedUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellow, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite,
                color: Colors.yellow,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'It\'s a Match!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You and ${matchedUser.name ?? 'User'} liked each other',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Keep Swiping', style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _selectTab(_HotNotTab.matches);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                      ),
                      child: Text('View Matches', style: GoogleFonts.poppins()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset _computeActiveOffset() {
    if (_isAnimating) {
      return _swipeAnimation.value;
    }
    return _dragOffset;
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 100}) {
    if (imageUrl.isEmpty) {
      final initials = userName
          .split(' ')
          .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
          .join()
          .substring(0, math.min(2, userName.length));

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.yellow,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.5,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[900],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  void _showGenderFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Gender Filter',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All', 'all'),
            _buildFilterOption('Male', 'male'),
            _buildFilterOption('Female', 'female'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label, style: GoogleFonts.poppins(color: Colors.white)),
      value: value,
      groupValue: _genderFilter ?? 'all',
      activeColor: Colors.yellow,
      onChanged: (newValue) {
        setState(() {
          _genderFilter = newValue == 'all' ? null : newValue;
        });
        Navigator.pop(context);
        _loadMatches();
      },
    );
  }

  Widget _buildTabButton(String label, _HotNotTab tab) {
    final bool isActive = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.yellow : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Hot & Not',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Match Chats',
            icon: const Icon(Icons.chat, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HotNotChatsPage(currentUserId: _currentUserId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showGenderFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                _buildTabButton('Feed', _HotNotTab.feed),
                _buildTabButton('Hotted', _HotNotTab.hotted),
                _buildTabButton('Matches', _HotNotTab.matches),
                _buildTabButton('Top 10', _HotNotTab.leaderboard),
              ],
            ),
          ),

          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case _HotNotTab.feed:
        return _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _buildFeedContent();
      case _HotNotTab.hotted:
        return _isLoadingHotted
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _buildHottedContent();
      case _HotNotTab.matches:
        return _isLoadingMatches
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _buildMatchesContent();
      case _HotNotTab.leaderboard:
        return _isLoadingLeaderboard
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _buildLeaderboardContent();
    }
  }

  Widget _buildHottedContent() {
    if (_currentUserId.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.local_fire_department_outlined,
        title: 'Please login to view your hotted list',
        subtitle: 'Sign in to continue swiping!',
      );
    }

    if (_hottedUsers.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.local_fire_department_outlined,
        title: 'No hotted users yet',
        subtitle: 'Tap Hot on profiles you love and see them here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hottedUsers.length,
      itemBuilder: (context, index) {
        final user = _hottedUsers[index];
        final isProcessing = _unhottingUserIds.contains(user.uid);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: user.uid),
                ),
              );
            },
            leading: Stack(
              children: [
                _buildUserAvatar(user.avatarUrl ?? '', user.name ?? 'User', radius: 30),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.local_fire_department, size: 12, color: Colors.black),
                  ),
                ),
              ],
            ),
            title: Text(
              user.name ?? 'Unknown',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.rollNo != null)
                  Text(
                    user.rollNo!,
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                  ),
                if (user.branch != null)
                  Text(
                    user.branch!,
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: isProcessing ? null : () => _handleUnhot(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Unhot', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchesContent() {
    if (_currentUserId.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.favorite_border,
        title: 'Please login to see your matches',
        subtitle: 'Sign in and keep swiping to meet people.',
      );
    }

    if (_matches.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.favorite_border,
        title: 'No matches yet',
        subtitle: 'Swipe Hot to increase your chances!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final otherUserId = match.user1Id == _currentUserId ? match.user2Id : match.user1Id;
        final otherUser = _getUserFromCache(otherUserId);

        return InkWell(
          onTap: () => _openMatchChat(match),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                _buildUserAvatar(
                  otherUser?.avatarUrl ?? '',
                  otherUser?.name ?? 'Match',
                  radius: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            otherUser?.name ?? 'Match',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.favorite, size: 12, color: Colors.pinkAccent),
                                SizedBox(width: 4),
                                Text('Match', style: TextStyle(color: Colors.pinkAccent, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Matched ${DateFormat('MMM d, h:mm a').format(match.matchedAt)}',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                      ),
                      if (match.lastMessageAt != null)
                        Text(
                          'Last chat ${DateFormat('MMM d, h:mm a').format(match.lastMessageAt!)}',
                          style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardContent() {
    if (_leaderboardUsers.isEmpty) {
      return _buildPlaceholder(
        icon: Icons.emoji_events_outlined,
        title: 'Leaderboard coming soon',
        subtitle: 'Be the first to make it to the Top 10!',
      );
    }

    final maxHot = (_leaderboardUsers.first.hotCount).clamp(1, 1 << 31);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_leaderboardUsers.length >= 3)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.yellow.withOpacity(0.12), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.yellow.withOpacity(0.25)),
              color: Colors.grey[900],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPodiumTile(2),
                _buildPodiumTile(0, highlight: true),
                _buildPodiumTile(1),
              ],
            ),
          ),
        if (_leaderboardUsers.length < 3)
          const SizedBox.shrink()
        else
          const SizedBox(height: 16),
        ...List.generate(_leaderboardUsers.length, (index) {
          return _buildLeaderboardRow(index, maxHot);
        }),
      ],
    );
  }

  Widget _buildPodiumTile(int index, {bool highlight = false}) {
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: highlight ? 86 : 74,
              height: highlight ? 86 : 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [base.withOpacity(0.35), Colors.transparent],
                ),
              ),
            ),
            _buildUserAvatar(user.avatarUrl ?? '', user.name ?? 'User', radius: highlight ? 36 : 32),
            Positioned(
              bottom: 4,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('#$rank', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user.name ?? 'Unknown',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: highlight ? 14 : 13),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          width: 70,
          height: height * 0.2,
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(color: base.withOpacity(0.35)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 14, color: base),
              const SizedBox(width: 4),
              Text('${user.hotCount}', style: GoogleFonts.poppins(color: base, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildLeaderboardRow(int index, int maxHot) {
  final user = _leaderboardUsers[index];
  final rank = index + 1;
  final Color badgeColor = rank == 1
      ? Colors.yellow
      : rank == 2
          ? Colors.grey[400]!
          : rank == 3
              ? Colors.brown[300]!
              : Colors.grey[800]!;

  final progress = ((user.hotCount) / maxHot).clamp(0.0, 1.0);

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePage(userId: user.uid),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                color: rank <= 3 ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildUserAvatar(user.avatarUrl ?? '', user.name ?? 'User', radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name ?? 'Unknown',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.boostUntil != null && user.boostUntil!.isAfter(DateTime.now()))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bolt, size: 12, color: Colors.purpleAccent),
                            SizedBox(width: 4),
                            Text('Boost', style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
                if (user.branch != null)
                  Text(user.branch!, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 8,
                    backgroundColor: Colors.grey[850],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rank == 1
                          ? Colors.yellow
                          : rank == 2
                              ? Colors.grey[400]!
                              : rank == 3
                                  ? Colors.brown[300]!
                                  : Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text('${user.hotCount}', style: GoogleFonts.poppins(color: Colors.yellow, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 2),
              Text('hot votes', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ... rest of your code ...
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnhot(UserModel user) async {
    if (_unhottingUserIds.contains(user.uid)) return;
    setState(() => _unhottingUserIds.add(user.uid));
    try {
      await _hotNotService.unhotUser(
        voterId: _currentUserId,
        targetId: user.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${user.name ?? 'User'} from your hotted list'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unhot user: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _unhottingUserIds.remove(user.uid));
      }
    }
  }

  Widget _buildFeedContent() {
    if (_currentUserId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Please login to use this feature',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_potentialMatches.isEmpty || _currentIndex >= _potentialMatches.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No more profiles',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later!',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMatches,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Refresh',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final currentUser = _potentialMatches[_currentIndex];

    return Stack(
      children: [
        // Background card (next user preview)
        if (_currentIndex + 1 < _potentialMatches.length)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildProfileCard(_potentialMatches[_currentIndex + 1], isBackground: true),
            ),
          ),

        // Current card with gesture handling
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: _swipeController,
              builder: (context, child) {
                final width = MediaQuery.of(context).size.width;
                final activeOffset = _computeActiveOffset();
                return Transform.translate(
                  offset: Offset(activeOffset.dx * width, activeOffset.dy * 200),
                  child: Transform.rotate(
                    angle: activeOffset.dx * 0.3,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onPanStart: (_) => _handleDragStart(),
                onPanUpdate: _handleDragUpdate,
                onPanEnd: _handleDragEnd,
                child: _buildProfileCard(currentUser),
              ),
            ),
          ),
        ),

        // Action buttons
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _swipeController,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              final activeOffset = _computeActiveOffset();
              final dx = activeOffset.dx * width;
              final dy = activeOffset.dy * 120;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: Icons.close,
                  color: Colors.redAccent,
                  label: 'Not',
                  onPressed: () => _triggerSwipe(false),
                ),
                const SizedBox(width: 40),
                _buildActionButton(
                  icon: Icons.local_fire_department,
                  color: Colors.greenAccent,
                  label: 'Hot',
                  onPressed: () => _triggerSwipe(true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(UserModel user, {bool isBackground = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBackground ? Colors.grey[800]! : Colors.yellow.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: _buildUserAvatar(
                    user.avatarUrl ?? '',
                    user.name ?? 'User',
                    radius: 120,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user.rollNo != null)
                      Text(
                        user.rollNo!,
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (user.branch != null)
                      Text(
                        user.branch!,
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    if (user.semester != null)
                      Text(
                        'Semester ${user.semester}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        onPressed();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.black,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
