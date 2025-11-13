import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/conversation_model.dart';
import '../models/match_model.dart';
import '../services/chat_service.dart';
import '../services/hot_not_service.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;

  const ConversationsPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
  });

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final ChatService _chatService = ChatService();
  final HotNotService _hotNotService = HotNotService();

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 24}) {
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
            fontSize: radius * 0.8,
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<Match>>(
        stream: _hotNotService.streamMatches(widget.currentUserId),
        builder: (context, matchSnapshot) {
          final matchConversations = <String>{};
          if (matchSnapshot.hasData) {
            for (final match in matchSnapshot.data!) {
              if (match.conversationId != null && match.conversationId!.isNotEmpty) {
                matchConversations.add(match.conversationId!);
              }
            }
          }

          return StreamBuilder<List<Conversation>>(
            stream: _chatService.streamConversations(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.yellow),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading conversations',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                );
              }

              final conversations = snapshot.data ?? [];

              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with someone!',
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
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final otherUserName =
                      conversation.getOtherParticipantName(widget.currentUserId);
                  final otherUserImage =
                      conversation.getOtherParticipantImage(widget.currentUserId);
                  final otherUserId =
                      conversation.getOtherParticipantId(widget.currentUserId);
                  final unreadCount =
                      conversation.unreadCounts[widget.currentUserId] ?? 0;
                  final isUnread = unreadCount > 0;
                  final isMatchChat = matchConversations.contains(conversation.id);

                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            conversationId: conversation.id,
                            currentUserId: widget.currentUserId,
                            currentUserName: widget.currentUserName,
                            currentUserImage: widget.currentUserImage,
                            otherUserId: otherUserId,
                            otherUserName: otherUserName,
                            otherUserImage: otherUserImage,
                            isMatchChat: isMatchChat,
                          ),
                        ),
                      );
                    },
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildUserAvatar(otherUserImage, otherUserName),
                        if (isMatchChat)
                          Positioned(
                            bottom: -2,
                            left: -2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 12,
                                color: Color(0xFFFF4D67),
                              ),
                            ),
                          ),
                        if (isUnread)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.yellow,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isMatchChat)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D67).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFF4D67).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, size: 12, color: Color(0xFFFF4D67)),
                                const SizedBox(width: 4),
                                Text(
                                  'Match',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFF4D67),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      conversation.lastMessage.isEmpty
                          ? 'No messages yet'
                          : conversation.lastMessage,
                      style: GoogleFonts.poppins(
                        color: isUnread ? Colors.white : Colors.grey,
                        fontSize: 13,
                        fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(conversation.lastMessageTime),
                          style: GoogleFonts.poppins(
                            color: isUnread ? Colors.yellow : Colors.grey,
                            fontSize: 12,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
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
}
