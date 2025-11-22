import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import 'profile_page.dart';

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
  Message? _replyToMessage;
  String? _swipeReplyMessageId;
  double _swipeReplyOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.conversationId, widget.currentUserId);
  }

  void _setReplyTo(Message message) {
    setState(() {
      _replyToMessage = message;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final replyTarget = _replyToMessage;

    setState(() {
      _isSending = true;
      _messageController.clear();
      _replyToMessage = null;
    });

    // Immediately jump to the bottom so the user stays at the latest messages
    _jumpToBottom();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderImage: widget.currentUserImage,
        content: text,
        recipientId: widget.otherUserId,
        replyToMessageId: replyTarget?.id,
        replyToSenderName: replyTarget == null
            ? null
            : (replyTarget.senderId == widget.currentUserId
                ? 'You'
                : replyTarget.senderName),
        replyToContent: replyTarget?.content,
      );

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

  // Build a small status icon for the sender's messages, similar to WhatsApp
  Widget _buildStatusIcon(Message message, bool isMe) {
    if (!isMe) return const SizedBox.shrink();

    // We treat messages visible in the stream as delivered; isRead drives blue ticks
    if (message.isRead) {
      return const Icon(
        Icons.done_all,
        size: 14,
        color: Colors.lightBlueAccent,
      );
    }

    return const Icon(
      Icons.done_all,
      size: 14,
      color: Colors.grey,
    );
  }

  String _statusLabel(Message message, bool isMe) {
    if (!isMe) return 'Received';
    if (message.isRead) return 'Read';
    return 'Delivered';
  }

  void _showMessageDetails(Message message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message info',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${_statusLabel(message, isMe)}',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Time: ${DateFormat('MMM d, h:mm a').format(message.timestamp)}',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
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

  Widget _buildMatchBackground(Color primaryColor, Color backgroundColor) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2A0210),
              backgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 60,
              left: 24,
              child: Opacity(
                opacity: 0.25,
                child: Icon(
                  Icons.favorite,
                  color: Colors.redAccent.shade100,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              top: 140,
              right: 32,
              child: Opacity(
                opacity: 0.18,
                child: Icon(
                  Icons.favorite,
                  color: primaryColor,
                  size: 40,
                ),
              ),
            ),
            Positioned(
              top: 220,
              left: 64,
              child: Opacity(
                opacity: 0.15,
                child: Icon(
                  Icons.favorite,
                  color: Colors.redAccent.shade100,
                  size: 26,
                ),
              ),
            ),
            Positioned(
              bottom: 140,
              right: 48,
              child: Opacity(
                opacity: 0.2,
                child: Icon(
                  Icons.favorite,
                  color: primaryColor,
                  size: 30,
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: 32,
              child: Opacity(
                opacity: 0.16,
                child: Icon(
                  Icons.favorite,
                  color: Colors.redAccent.shade100,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _withOpacity(Color color, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255).toInt();
    return Color.fromARGB(alpha, color.red, color.green, color.blue);
  }

  BoxDecoration _matchBubbleDecoration(bool isMe) {
    final Color start = isMe ? const Color(0xFFFF5A76) : const Color(0xFFAE2843);
    final Color end = isMe ? const Color(0xFFB92B3B) : const Color(0xFF7C0B1C);
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [start, end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isMe ? 20 : 20),
        topRight: Radius.circular(isMe ? 20 : 20),
        bottomLeft: Radius.circular(isMe ? 20 : 40),
        bottomRight: Radius.circular(isMe ? 40 : 20),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMatchChat = widget.isMatchChat;
    final Color primaryColor = isMatchChat
        ? const Color(0xFFFF4D67)
        : const Color.fromARGB(255, 255, 221, 54); // my bubble in normal chats (Beezy yellow)
    final Color secondaryColor = isMatchChat
        ? const Color(0xFF2A0B18)
        : const Color(0xFF1F1F1F); // other bubble in normal chats
    final Color backgroundColor = isMatchChat ? const Color(0xFF12040B) : Colors.black;
    final Gradient? headerGradient = isMatchChat
        ? const LinearGradient(
            colors: [Color(0xFF3B0A14), Color(0xFF12040B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
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
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(userId: widget.otherUserId),
              ),
            );
          },
          child: Row(
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
                          const Icon(Icons.local_fire_department,
                              color: Colors.white, size: 14),
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
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
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
      ),
      body: Stack(
        children: [
          if (isMatchChat)
            Positioned.fill(
              child: _buildMatchBackground(primaryColor, backgroundColor),
            ),
          Column(
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

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        messages.isEmpty) {
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
                              constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight),
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

                    final double bubbleWidth = MediaQuery.of(context).size.width * 0.72;
                    final listView = ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
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
                        final bool isSwipingThis =
                            _swipeReplyMessageId == message.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onLongPress: () => _setReplyTo(message),
                            onHorizontalDragStart: (_) {
                              setState(() {
                                _swipeReplyMessageId = message.id;
                                _swipeReplyOffset = 0.0;
                              });
                            },
                            onHorizontalDragUpdate: (details) {
                              if (details.delta.dx > 0) {
                                setState(() {
                                  if (_swipeReplyMessageId == message.id) {
                                    _swipeReplyOffset += details.delta.dx;
                                    _swipeReplyOffset =
                                        _swipeReplyOffset.clamp(0.0, 60.0);
                                  }
                                });
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity ?? 0.0;

                              if (velocity < -300) {
                                _showMessageDetails(message, isMe);
                              }

                              final bool fastLeftToRight = velocity > 300;
                              final bool draggedFarEnough =
                                  _swipeReplyMessageId == message.id &&
                                      _swipeReplyOffset > 20.0;
                              if (fastLeftToRight || draggedFarEnough) {
                                _setReplyTo(message);
                              }

                              setState(() {
                                _swipeReplyMessageId = null;
                                _swipeReplyOffset = 0.0;
                              });
                            },
                            child: Transform.translate(
                              offset: Offset(
                                  isSwipingThis ? _swipeReplyOffset : 0.0, 0),
                              child: Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFE94F5D),
                                            const Color(0xFFB11E2B),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.6),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                  ],
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        ConstrainedBox(
                                          constraints:
                                              BoxConstraints(maxWidth: bubbleWidth),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 14,
                                            ),
                                            decoration: isMatchChat
                                                ? _matchBubbleDecoration(isMe)
                                                : BoxDecoration(
                                                    color: isMe
                                                        ? primaryColor
                                                        : secondaryColor,
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                    boxShadow: null,
                                                  ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (message.replyToContent != null &&
                                                    (message.replyToContent!
                                                        .isNotEmpty))
                                                  Container(
                                                    margin: const EdgeInsets.only(
                                                        bottom: 6),
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: isMe
                                                          ? _withOpacity(
                                                              Colors.black, 0.05)
                                                          : _withOpacity(
                                                              Colors.black, 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 3,
                                                          height: 28,
                                                          margin:
                                                              const EdgeInsets.only(
                                                                  right: 8),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? Colors.black54
                                                                : primaryColor,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    999),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              if (message.replyToSenderName !=
                                                                  null)
                                                                Text(
                                                                  message.replyToSenderName!,
                                                                  style:
                                                                      GoogleFonts.poppins(
                                                                    color: isMe
                                                                        ? Colors.black87
                                                                        : primaryColor,
                                                                    fontWeight:
                                                                        FontWeight.w600,
                                                                    fontSize: 11,
                                                                  ),
                                                                ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                message.replyToContent!,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow.ellipsis,
                                                                style:
                                                                    GoogleFonts.poppins(
                                                                  color: isMe
                                                                      ? Colors.black87
                                                                      : Colors.white,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                Text(
                                                  message.content,
                                                  style: GoogleFonts.poppins(
                                                    color: isMatchChat
                                                        ? (isMe
                                                            ? Colors.black
                                                            : Colors.white)
                                                        : (isMe
                                                            ? Colors.black
                                                            : Colors.white),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTime(message.timestamp),
                                              style: GoogleFonts.poppins(
                                                color: isMatchChat
                                                    ? Colors.white70
                                                    : Colors.grey,
                                                fontSize: 11,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              _buildStatusIcon(message, isMe),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox.shrink(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    if (hasFreshData && !_hasInitialScrolledToBottom) {
                      _hasInitialScrolledToBottom = true;
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _jumpToBottom());
                    }

                    return listView;
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: isMatchChat
                        ? secondaryColor
                        : Colors.grey[900],
                    border: Border(
                      top: BorderSide(
                        color: isMatchChat
                            ? _withOpacity(primaryColor, 0.3)
                            : Colors.grey[800]!,
                        width: 1,
                      ),
                    ),
                    boxShadow: null,
                  ),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, isMatchChat ? 24 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyToMessage != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _withOpacity(primaryColor, 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 32,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _replyToMessage!.senderId ==
                                              widget.currentUserId
                                          ? 'You'
                                          : _replyToMessage!.senderName,
                                      style: GoogleFonts.poppins(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _replyToMessage!.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _replyToMessage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: GoogleFonts.poppins(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: isMatchChat
                                    ? 'Send something sweet…'
                                    : 'Type a message...',
                                hintStyle: GoogleFonts.poppins(
                                  color: isMatchChat ? Colors.white60 : Colors.grey,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: _withOpacity(primaryColor, 0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: _withOpacity(primaryColor, 0.3),
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
                                fillColor: Colors.black,
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isSending ? null : _sendMessage,
                            icon: Icon(
                              Icons.send,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
          colors: [_withOpacity(accentColor, 0.2), Colors.black],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _withOpacity(Colors.white, 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _withOpacity(accentColor, 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        color: accentColor, size: 18),
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
                        _messageController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: _messageController.text.length),
                        );
                      },
                      child: Text('Send',
                          style: GoogleFonts.poppins(color: accentColor)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white70),
              label:
                  Text('Close', style: GoogleFonts.poppins(color: Colors.white70)),
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
