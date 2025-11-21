import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;
  final bool isMatchChat;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
    this.isMatchChat = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  bool _isSending = false;
  List<Message> _cachedMessages = [];
  bool _hasInitialScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.conversationId, widget.currentUserId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderImage: widget.currentUserImage,
        content: _messageController.text.trim(),
        recipientId: widget.otherUserId,
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

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
      return DateFormat('EEE HH:mm').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 18}) {
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
      backgroundImage: CachedNetworkImageProvider(imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMatchChat = widget.isMatchChat;
    final Color primaryColor = isMatchChat ? const Color(0xFFFF4D67) : Colors.yellow;
    final Color secondaryColor = isMatchChat ? const Color(0xFF2A0B18) : Colors.grey[900]!;
    final Color backgroundColor = isMatchChat ? const Color(0xFF12040B) : Colors.black;
    final Gradient? headerGradient = isMatchChat
        ? const LinearGradient(
            colors: [Color(0xFFFF4D67), Color(0xFFFF7F50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: isMatchChat ? 6 : 0,
        flexibleSpace: headerGradient != null
            ? Container(
                decoration: BoxDecoration(
                  gradient: headerGradient,
                ),
              )
            : null,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                _buildUserAvatar(widget.otherUserImage, widget.otherUserName, radius: 18),
                if (isMatchChat)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 16,
                      height: 16,
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
                        color: Color(0xFFFF4D67),
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUserName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isMatchChat)
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'It\'s a match! Start the spark',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (isMatchChat)
              IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.black,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _buildDatePrompt(context, primaryColor),
                  );
                },
                icon: const Icon(Icons.favorite_border, color: Colors.white),
                tooltip: 'Plan something',
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.streamMessages(widget.conversationId),
              builder: (context, snapshot) {
                final bool hasFreshData = snapshot.hasData;
                List<Message> messages;
                if (hasFreshData) {
                  messages = snapshot.data!;
                  _cachedMessages = messages;
                } else {
                  messages = _cachedMessages;
                }

                if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.yellow),
                  );
                }

                if (snapshot.hasError && messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  );
                }

                if (messages.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start the conversation!',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                final listView = ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: isMatchChat ? 32 : 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            _buildUserAvatar(
                              message.senderImage,
                              message.senderName,
                              radius: 16,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? primaryColor
                                        : (isMatchChat ? secondaryColor : Colors.grey[900]),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: isMatchChat
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(isMe ? 0.25 : 0.15),
                                              blurRadius: 18,
                                              offset: const Offset(0, 10),
                                            ),
                                          ]
                                        : null,
                                    border: isMatchChat && !isMe
                                        ? Border.all(color: primaryColor.withOpacity(0.4))
                                        : null,
                                  ),
                                  child: Text(
                                    message.content,
                                    style: GoogleFonts.poppins(
                                      color: isMe
                                          ? Colors.black
                                          : (isMatchChat ? Colors.white : Colors.white),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: GoogleFonts.poppins(
                                    color: isMatchChat
                                        ? Colors.white70
                                        : Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            _buildUserAvatar(
                              message.senderImage,
                              message.senderName,
                              radius: 16,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );

                if (hasFreshData && !_hasInitialScrolledToBottom) {
                  _hasInitialScrolledToBottom = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
                }

                return listView;
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: isMatchChat ? secondaryColor : Colors.grey[900],
                border: Border(
                  top: BorderSide(
                    color: isMatchChat ? primaryColor.withOpacity(0.3) : Colors.grey[800]!,
                    width: 1,
                  ),
                ),
                boxShadow: isMatchChat
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ]
                    : null,
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, isMatchChat ? 24 : 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: isMatchChat ? 'Send something sweet…' : 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          color: isMatchChat ? Colors.white60 : Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: isMatchChat ? Colors.black : Colors.black,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : Icon(
                            isMatchChat ? Icons.favorite : Icons.send,
                            color: primaryColor,
                            size: 24,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePrompt(BuildContext context, Color accentColor) {
    final suggestions = [
      'Plan a coffee date on campus',
      'Suggest a study session together',
      'Go for a walk around the quad',
      'Catch a movie night',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.2), Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Make the first move',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Need inspiration? Try one of these:',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...suggestions.map(
              (suggestion) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department, color: accentColor, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final message = suggestion;
                        Navigator.pop(context);
                        _messageController.text = message;
                        _messageController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _messageController.text.length),
                        );
                      },
                      child: Text('Send', style: GoogleFonts.poppins(color: accentColor)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white70),
              label: Text('Close', style: GoogleFonts.poppins(color: Colors.white70)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
