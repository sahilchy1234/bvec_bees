import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/hot_not_service.dart';
import '../services/auth_service.dart';
import '../models/match_model.dart';
import '../widgets/cached_network_image_widget.dart';
import 'chat_page.dart';
import 'hotnot_chats_page.dart';
import 'dart:math' as math;
import 'profile_page.dart';

enum _HotNotTab { feed, hotted, matches, leaderboard }

enum _LeaderboardFilter { all, male, female }

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
  final List<UserModel> _prefetchedMatches = [];
  List<UserModel> _hottedUsers = [];
  List<Match> _matches = [];
  List<UserModel> _leaderboardUsers = [];
  List<UserModel> _leaderboardAll = [];
  List<UserModel> _leaderboardMale = [];
  List<UserModel> _leaderboardFemale = [];
  bool _isLoading = true;
  bool _isPrefetching = false;
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
  final bool _showMatchAnimation = false;
  UserModel? _matchedUser;
  _HotNotTab _selectedTab = _HotNotTab.feed;
  final Map<String, UserModel?> _userCache = {};
  final Set<String> _seenUserIds = <String>{};
  StreamSubscription<List<UserModel>>? _hottedSubscription;
  StreamSubscription<List<Match>>? _matchesSubscription;
  bool _hasLoadedHotted = false;
  bool _hasLoadedMatches = false;
  bool _hasLoadedLeaderboard = false;
  final Set<String> _unhottingUserIds = <String>{};
  static const int _prefetchThreshold = 5;
  _LeaderboardFilter _leaderboardFilter = _LeaderboardFilter.all;

  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadMatches();

    // After the first frame, check if this is the user's first time
    // opening Hot & Not. If so, automatically show the settings panel
    // (gender filter dialog) and remember that we've shown it locally.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSettingsOnFirstOpen();
    });
  }

  void _precacheUserAvatars(List<UserModel> users) {
    for (final user in users) {
      final url = user.avatarUrl;
      if (url != null && url.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
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

  Future<void> _maybeShowSettingsOnFirstOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasShown = prefs.getBool('hotnot_settings_shown') ?? false;
      if (hasShown || !mounted) return;

      await prefs.setBool('hotnot_settings_shown', true);
      if (!mounted) return;
      _showGenderFilterDialog();
    } catch (_) {
      // If anything goes wrong, just skip the auto-show; core flow should continue.
    }
  }

  Future<void> _saveGenderFilter(String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value == 'all') {
        await prefs.remove('hotnot_gender_filter');
      } else {
        await prefs.setString('hotnot_gender_filter', value);
      }
    } catch (_) {
      // Ignore persistence errors; they shouldn't block swiping.
    }
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
      final all = await _hotNotService.getLeaderboard();
      final male = await _hotNotService.getLeaderboard(genderFilter: 'Male');
      final female = await _hotNotService.getLeaderboard(genderFilter: 'Female');
      if (!mounted) return;
      setState(() {
        _leaderboardAll = all;
        _leaderboardMale = male;
        _leaderboardFemale = female;
        _applyLeaderboardFilter();
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

  void _applyLeaderboardFilter() {
    switch (_leaderboardFilter) {
      case _LeaderboardFilter.all:
        _leaderboardUsers = _leaderboardAll;
        break;
      case _LeaderboardFilter.male:
        _leaderboardUsers = _leaderboardMale;
        break;
      case _LeaderboardFilter.female:
        _leaderboardUsers = _leaderboardFemale;
        break;
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _hottedSubscription?.cancel();
    _matchesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId.isEmpty) {
        _currentUserId = prefs.getString('current_user_uid') ?? '';
      }

      if (_currentUserId.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Load current user profile
      _currentUser = await _authService.getUserProfile(_currentUserId);

      if (_currentUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Restore persisted gender filter (if any) so it sticks across launches
      try {
        final savedFilter = prefs.getString('hotnot_gender_filter');
        if (savedFilter != null && savedFilter.isNotEmpty && savedFilter != 'all') {
          _genderFilter = savedFilter;
        } else {
          _genderFilter = null;
        }
      } catch (_) {
        // If loading fails, fall back to in-memory value / default.
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

      if (!mounted) return;
      setState(() {
        _potentialMatches = feedUsers;
        _currentIndex = 0;
        _isLoading = false;
        _seenUserIds
          ..clear()
          ..addAll(feedUsers.map((u) => u.uid));
        _prefetchedMatches.clear();
      });

      if (mounted && _potentialMatches.isNotEmpty) {
        _precacheUserAvatars(
          _potentialMatches.length > 5
              ? _potentialMatches.sublist(0, 5)
              : _potentialMatches,
        );
      }

      // Warm up the next batch in the background so swiping stays instant
      await _prefetchNextFeed();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading feed: $e')),
      );
    }
  }

  Future<void> _prefetchNextFeed() async {
    if (!mounted) return;
    if (_isPrefetching) return;
    if (_currentUserId.isEmpty || _currentUser == null) return;

    setState(() {
      _isPrefetching = true;
    });

    try {
      final feedUsers = await _hotNotService.getFeed(
        currentUserId: _currentUserId,
        currentUserGender: _currentUser!.gender,
        lookingFor: _currentUser!.lookingFor,
        genderFilter: _genderFilter,
      );

      if (!mounted) return;

      // Filter out users we've already seen in this session
      final newUsers = feedUsers
          .where((user) => !_seenUserIds.contains(user.uid))
          .toList();

      if (newUsers.isEmpty) {
        setState(() {
          _prefetchedMatches.clear();
        });
        return;
      }

      setState(() {
        _prefetchedMatches
          ..clear()
          ..addAll(newUsers);
        _seenUserIds.addAll(newUsers.map((u) => u.uid));
      });

      if (mounted && _prefetchedMatches.isNotEmpty) {
        _precacheUserAvatars(
          _prefetchedMatches.length > 5
              ? _prefetchedMatches.sublist(0, 5)
              : _prefetchedMatches,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prefetchedMatches.clear();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isPrefetching = false;
      });
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
          if (_prefetchedMatches.isNotEmpty) {
            _potentialMatches.addAll(_prefetchedMatches);
            _prefetchedMatches.clear();

            // Ensure index is still in range after extending the list
            if (_currentIndex >= _potentialMatches.length) {
              _currentIndex = _potentialMatches.isEmpty
                  ? 0
                  : _potentialMatches.length - 1;
            }

            // Start prefetching the next batch when we roll over
            _prefetchNextFeed();
          } else {
            _loadMatches();
          }
        } else if (_potentialMatches.length - _currentIndex <= _prefetchThreshold) {
          // When we are close to the end of the current stack, start prefetching
          _prefetchNextFeed();
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
    final currentUser = _currentUser;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Widget buildHeartParticle({
          required Alignment alignment,
          required Duration duration,
          double startYOffset = 40,
          double maxRise = 80,
          double size = 22,
          Color color = Colors.pinkAccent,
        }) {
          return Align(
            alignment: alignment,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final opacity = (1 - value).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, startYOffset - (maxRise * value)),
                    child: Transform.scale(
                      scale: 0.7 + (0.5 * value),
                      child: child,
                    ),
                  ),
                );
              },
              child: Icon(
                Icons.favorite,
                color: color.withOpacity(0.9),
                size: size,
              ),
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      buildHeartParticle(
                        alignment: const Alignment(-0.8, 0.2),
                        duration: const Duration(milliseconds: 1100),
                        startYOffset: 50,
                        maxRise: 90,
                        size: 20,
                      ),
                      buildHeartParticle(
                        alignment: const Alignment(-0.3, 0.1),
                        duration: const Duration(milliseconds: 900),
                        startYOffset: 60,
                        maxRise: 80,
                        size: 18,
                        color: Colors.pinkAccent,
                      ),
                      buildHeartParticle(
                        alignment: const Alignment(0.3, 0.15),
                        duration: const Duration(milliseconds: 1000),
                        startYOffset: 55,
                        maxRise: 85,
                        size: 24,
                        color: Colors.redAccent,
                      ),
                      buildHeartParticle(
                        alignment: const Alignment(0.8, 0.25),
                        duration: const Duration(milliseconds: 1200),
                        startYOffset: 65,
                        maxRise: 95,
                        size: 20,
                        color: Colors.pinkAccent,
                      ),
                      buildHeartParticle(
                        alignment: const Alignment(0.0, -0.1),
                        duration: const Duration(milliseconds: 1300),
                        startYOffset: 45,
                        maxRise: 100,
                        size: 18,
                        color: Colors.purpleAccent,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1C0F2E),
                      Color(0xFF050509),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.yellow, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withOpacity(0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.3 * value),
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.pinkAccent, Colors.orangeAccent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pinkAccent.withOpacity(0.7),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "It's a Match!",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You and ${matchedUser.name ?? 'User'} liked each other',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[300],
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (currentUser != null)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 16 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildUserAvatar(
                              currentUser.avatarUrl ?? '',
                              currentUser.name ?? 'You',
                              radius: 34,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                Icons.favorite,
                                color: Colors.pinkAccent[200],
                                size: 26,
                              ),
                            ),
                            _buildUserAvatar(
                              matchedUser.avatarUrl ?? '',
                              matchedUser.name ?? 'User',
                              radius: 34,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Keep Swiping',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'View Matches',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Offset _computeActiveOffset() {
    if (_isAnimating) {
      return _swipeAnimation.value;
    }
    return _dragOffset;
  }

  Widget _buildSwipeIndicatorOverlay() {
    final activeOffset = _computeActiveOffset();
    final dx = activeOffset.dx;

    if (dx.abs() < 0.05) {
      return const SizedBox.shrink();
    }

    const swipeThreshold = 0.25;
    final intensity = (dx.abs() / swipeThreshold).clamp(0.0, 1.0);

    final bool isHotDirection = dx > 0;
    final Color color = isHotDirection ? Colors.yellow : Colors.red;
    final String label = isHotDirection ? 'HOT' : 'NOT';

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: intensity,
        duration: const Duration(milliseconds: 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.35 * intensity),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isHotDirection ? Icons.local_fire_department : Icons.close,
                    color: color,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

    return CachedCircleAvatar(
      imageUrl: imageUrl,
      displayName: userName,
      radius: radius,
      backgroundColor: Colors.grey[900],
      textColor: Colors.black,
    );
  }

  void _showGenderFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Which gender do you want to swipe on?',
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
        final effective = newValue ?? 'all';
        setState(() {
          _genderFilter = effective == 'all' ? null : effective;
        });
        _saveGenderFilter(effective);
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
            icon: const Icon(Icons.settings, color: Colors.white),
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

          Expanded(
            child: RefreshIndicator(
              color: Colors.yellow,
              backgroundColor: Colors.black,
              onRefresh: _refreshCurrentTab,
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case _HotNotTab.feed:
        return _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _wrapFillRemaining(_buildFeedContent());
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
      return _wrapScrollable(_buildPlaceholder(
        icon: Icons.local_fire_department_outlined,
        title: 'Please login to view your hotted list',
        subtitle: 'Sign in to continue swiping!',
      ));
    }

    if (_hottedUsers.isEmpty) {
      return _wrapScrollable(_buildPlaceholder(
        icon: Icons.local_fire_department_outlined,
        title: 'No hotted users yet',
        subtitle: 'Tap Hot on profiles you love and see them here.',
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
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
      return _wrapScrollable(_buildPlaceholder(
        icon: Icons.favorite_border,
        title: 'Please login to see your matches',
        subtitle: 'Sign in and keep swiping to meet people.',
      ));
    }

    if (_matches.isEmpty) {
      return _wrapScrollable(_buildPlaceholder(
        icon: Icons.favorite_border,
        title: 'No matches yet',
        subtitle: 'Swipe Hot to increase your chances!',
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
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
                          Expanded(
                            child: Text(
                              otherUser?.name ?? 'Match',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
      return _wrapScrollable(_buildPlaceholder(
        icon: Icons.emoji_events_outlined,
        title: 'Leaderboard coming soon',
        subtitle: 'Be the first to make it to the Top 10!',
      ));
    }

    final maxHot = (_leaderboardUsers.first.hotCount).clamp(1, 1 << 31);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLeaderboardFilterChip('All', _LeaderboardFilter.all),
            const SizedBox(width: 8),
            _buildLeaderboardFilterChip('Male', _LeaderboardFilter.male),
            const SizedBox(width: 8),
            _buildLeaderboardFilterChip('Female', _LeaderboardFilter.female),
          ],
        ),
        const SizedBox(height: 16),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPodiumTile(2),
                const SizedBox(width: 4),
                _buildPodiumTile(0, highlight: true),
                const SizedBox(width: 4),
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

  Widget _buildLeaderboardFilterChip(String label, _LeaderboardFilter filter) {
    final bool isActive = _leaderboardFilter == filter;
    return GestureDetector(
      onTap: () {
        if (_leaderboardFilter == filter) return;
        setState(() {
          _leaderboardFilter = filter;
          _applyLeaderboardFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.yellow : Colors.grey[700]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumTile(int index, {bool highlight = false}) {
    final user = _leaderboardUsers[index];
    final heights = [120.0, 100.0, 80.0];
    final rank = index + 1;
    final height = highlight ? 140.0 : heights[index == 0 ? 0 : (index == 1 ? 1 : 2)];
    final Color base = rank == 1
        ? Colors.yellow
        : rank == 2
            ? Colors.grey[400]!
            : Colors.brown[300]!;

    final double tileWidth = highlight ? 110 : 90;

    return SizedBox(
      width: tileWidth,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(userId: user.uid),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user.name ?? 'Unknown',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: highlight ? 14 : 13,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
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
                  Text(
                    '${user.hotCount}',
                    style: GoogleFonts.poppins(
                      color: base,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

Widget _buildPlaceholder({
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      _buildProfileCard(currentUser),
                      _buildSwipeIndicatorOverlay(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Action buttons removed for cleaner UI - swiping still works
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
            // Top image / avatar section with subtle gradient
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF111111),
                      Colors.black,
                    ],
                  ),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.yellow.withOpacity(0.22),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      _buildUserAvatar(
                        user.avatarUrl ?? '',
                        user.name ?? 'User',
                        radius: 120,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Info section
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[900]!,
                      const Color(0xFF151515),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                user.name ?? 'Unknown',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.yellow.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.yellow.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 14,
                                    color: Colors.yellow,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Hot & Not',
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (user.branch != null && user.branch!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.school,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.branch!,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (user.semester != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timeline,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Semester ${user.semester}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          height: 1,
                          color: Colors.white10,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Swipe left for Not',
                              style: GoogleFonts.poppins(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Swipe right for Hot',
                              style: GoogleFonts.poppins(
                                color: Colors.yellow.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
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


  Future<void> _refreshCurrentTab() async {
    switch (_selectedTab) {
      case _HotNotTab.feed:
        await _loadMatches();
        break;
      case _HotNotTab.hotted:
        setState(() {
          _hasLoadedHotted = false;
        });
        await _loadHottedUsers();
        break;
      case _HotNotTab.matches:
        setState(() {
          _hasLoadedMatches = false;
        });
        await _loadMatchesList();
        break;
      case _HotNotTab.leaderboard:
        setState(() {
          _hasLoadedLeaderboard = false;
        });
        await _loadLeaderboard();
        break;
    }
  }

  Widget _wrapScrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _wrapFillRemaining(Widget child) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: child,
        ),
      ],
    );
  }
}
