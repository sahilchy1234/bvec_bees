import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../services/hot_not_service.dart';
import '../services/auth_service.dart';
import '../widgets/cached_network_image_widget.dart';
import 'chat_page.dart';

class HotNotChatsPage extends StatefulWidget {
  final String? currentUserId;

  const HotNotChatsPage({super.key, this.currentUserId});

  @override
  State<HotNotChatsPage> createState() => _HotNotChatsPageState();
}

class _HotNotChatsPageState extends State<HotNotChatsPage> {
  final HotNotService _hotNotService = HotNotService();
  final AuthService _authService = AuthService();

  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserImage = '';
  final Map<String, UserModel?> _userCache = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUserId = widget.currentUserId ?? '';
    if (_currentUserId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('current_user_uid') ?? '';
      _currentUserName = prefs.getString('current_user_name') ?? 'You';
      _currentUserImage = prefs.getString('current_user_avatar') ?? '';
    } else {
      final profile = await _authService.getUserProfile(_currentUserId);
      _currentUserName = profile?.name ?? 'You';
      _currentUserImage = profile?.avatarUrl ?? '';
    }
    if (mounted) setState(() {});
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 28}) {
    if (imageUrl.isEmpty) {
      final initial = (userName.isNotEmpty ? userName[0] : 'U').toUpperCase();
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.pinkAccent,
        child: Text(
          initial,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.9,
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

  Future<void> _openChat(Match match) async {
    final otherUserId = match.user1Id == _currentUserId ? match.user2Id : match.user1Id;
    if (!_userCache.containsKey(otherUserId)) {
      _userCache[otherUserId] = await _authService.getUserProfile(otherUserId);
    }
    final otherUser = _userCache[otherUserId];
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: match.conversationId ?? '',
          currentUserId: _currentUserId,
          currentUserName: _currentUserName,
          currentUserImage: _currentUserImage,
          otherUserId: otherUserId,
          otherUserName: otherUser?.name ?? 'Match',
          otherUserImage: otherUser?.avatarUrl ?? '',
          isMatchChat: true,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.pinkAccent),
            const SizedBox(width: 8),
            Text(
              'Hot & Not Chats',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: _currentUserId.isEmpty
          // While current user info is loading, show a single loader
          ? const Center(
              child: CircularProgressIndicator(color: Colors.pinkAccent),
            )
          : StreamBuilder<List<Match>>(
              stream: _hotNotService.streamMatches(_currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load matches', style: GoogleFonts.poppins(color: Colors.white)),
                  );
                }
                final matches = snapshot.data ?? [];
                if (matches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text('No love chats yet', style: GoogleFonts.poppins(color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text('Swipe Hot to start a conversation', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    final otherUserId = match.user1Id == _currentUserId ? match.user2Id : match.user1Id;
                    // Kick off cache fetch without blocking tile build
                    if (!_userCache.containsKey(otherUserId)) {
                      _authService.getUserProfile(otherUserId).then((u) {
                        if (mounted) setState(() => _userCache[otherUserId] = u);
                      });
                    }
                    final otherUser = _userCache[otherUserId];
                    // While the other user's profile is still loading, skip rendering this row
                    if (otherUser == null) {
                      return const SizedBox.shrink();
                    }
                    return InkWell(
                      onTap: () => _openChat(match),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF4D67).withOpacity(0.12),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF4D67).withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            _buildUserAvatar(otherUser.avatarUrl ?? '', otherUser.name ?? 'Match', radius: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          otherUser.name ?? 'Match',
                                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF4D67).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFFF4D67).withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.favorite, size: 12, color: Color(0xFFFF4D67)),
                                            SizedBox(width: 4),
                                            Text('Love', style: TextStyle(color: Color(0xFFFF4D67), fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    match.lastMessageAt != null
                                        ? 'Last chat ${DateFormat('MMM d, h:mm a').format(match.lastMessageAt!)}'
                                        : 'Matched ${DateFormat('MMM d, h:mm a').format(match.matchedAt)}',
                                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
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
              },
            ),
    );
  }
}
