import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/match_service.dart';
import 'dart:math' as math;

class SwipePage extends StatefulWidget {
  final ScrollController scrollController;

  const SwipePage({
    super.key,
    required this.scrollController,
  });

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> with TickerProviderStateMixin {
  final MatchService _matchService = MatchService();
  List<UserModel> _potentialMatches = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  String _currentUserId = '';
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isAnimating = false;
  
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _swipeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('current_user_uid') ?? '';

      if (_currentUserId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final matches = await _matchService.getPotentialMatches(_currentUserId);
      setState(() {
        _potentialMatches = matches;
        _currentIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matches: $e')),
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

      final voteFuture = _matchService.castVote(
        voterId: _currentUserId,
        targetId: targetUser.uid,
        isHot: isHot,
      );

      await Future.wait([animationFuture, voteFuture]);

      _swipeController.reset();

      if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      );
    }

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
