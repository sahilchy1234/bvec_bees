import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../services/match_service.dart';
import '../services/auth_service.dart';
import 'chat_page.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final MatchService _matchService = MatchService();
  final AuthService _authService = AuthService();
  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserImage = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('current_user_uid') ?? '';
      _currentUserName = prefs.getString('current_user_name') ?? 'User';
      _currentUserImage = prefs.getString('current_user_avatar') ?? '';
    });
  }

  Future<void> _openChat(Match match) async {
    try {
      final otherUserId = match.user1Id == _currentUserId ? match.user2Id : match.user1Id;
      final otherUser = await _authService.getUserProfile(otherUserId);

      if (otherUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found')),
          );
        }
        return;
      }

      String conversationId;
      if (match.conversationId != null) {
        conversationId = match.conversationId!;
      } else {
        conversationId = await _matchService.createMatchConversation(
          matchId: match.id,
          user1Id: _currentUserId,
          user1Name: _currentUserName,
          user1Image: _currentUserImage,
          user2Id: otherUser.uid,
          user2Name: otherUser.name ?? 'User',
          user2Image: otherUser.avatarUrl ?? '',
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            currentUserId: _currentUserId,
            currentUserName: _currentUserName,
            currentUserImage: _currentUserImage,
            otherUserId: otherUser.uid,
            otherUserName: otherUser.name ?? 'User',
            otherUserImage: otherUser.avatarUrl ?? '',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    }
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 32}) {
    if (imageUrl.isEmpty) {
      final initials = userName
          .split(' ')
          .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
          .join()
          .substring(0, 1);

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.yellow,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.6,
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
    if (_currentUserId.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.yellow),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Your Matches',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Match>>(
        stream: _matchService.streamMatches(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading matches',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            );
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
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
                    'No matches yet',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start swiping to find matches!',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final otherUserId = match.user1Id == _currentUserId
                  ? match.user2Id
                  : match.user1Id;

              return FutureBuilder<UserModel?>(
                future: _authService.getUserProfile(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final user = userSnapshot.data!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.yellow.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Stack(
                        children: [
                          _buildUserAvatar(
                            user.avatarUrl ?? '',
                            user.name ?? 'User',
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 10,
                                color: Colors.black,
                              ),
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
                      subtitle: Text(
                        'Matched on ${_formatDate(match.matchedAt)}',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _openChat(match),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Chat',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
