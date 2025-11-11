import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;

  const CommentsPage({
    super.key,
    required this.postId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  late final Stream<List<Comment>> _commentsStream;
  final ScrollController _listController = ScrollController();
  bool _isPosting = false;
  int _lastCommentCount = 0;

  @override
  void initState() {
    super.initState();
    _commentsStream = _commentService.streamComments(widget.postId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);

    try {
      await _commentService.addComment(
        postId: widget.postId,
        authorId: widget.currentUserId,
        authorName: widget.currentUserName,
        authorImage: widget.currentUserImage,
        content: _commentController.text.trim(),
      );

      _commentController.clear();
      _scheduleScrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      _listController.animateTo(
        _listController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 18}) {
    if (imageUrl.isEmpty) {
      // Show initials if no image
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
      child: imageUrl.isEmpty
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: Colors.black,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comments',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey, height: 1),
                Expanded(
                  child: StreamBuilder<List<Comment>>(
                    stream: _commentsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading comments',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        );
                      }

                      final comments = snapshot.data ?? [];

                      if (comments.length != _lastCommentCount) {
                        _lastCommentCount = comments.length;
                        _scheduleScrollToBottom();
                      }

                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.comment,
                                color: Colors.grey,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to comment!',
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
                        controller: _listController,
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return _buildCommentItem(comment);
                        },
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border(
                      top: BorderSide(color: Colors.grey[800]!, width: 1),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: bottomInset == 0 ? 16 : bottomInset,
                    left: 16,
                    right: 16,
                    top: 12,
                  ),
                  child: Row(
                    children: [
                      _buildUserAvatar(
                        widget.currentUserImage,
                        widget.currentUserName,
                        radius: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.yellow.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Colors.yellow.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: Colors.yellow,
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
                          onSubmitted: (_) => _postComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isPosting ? null : _postComment,
                        icon: _isPosting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.yellow,
                                ),
                              )
                            : const FaIcon(
                                FontAwesomeIcons.paperPlane,
                                color: Colors.yellow,
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final isOwnComment = comment.authorId == widget.currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(comment.authorImage, comment.authorName, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.authorName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isOwnComment)
                            PopupMenuButton(
                              color: Colors.grey[800],
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                  onTap: () async {
                                    try {
                                      await _commentService.deleteComment(
                                        widget.postId,
                                        comment.id,
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Text(
                        _formatTime(comment.timestamp),
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () async {
                          try {
                            if (comment.likedBy.contains(widget.currentUserId)) {
                              await _commentService.unlikeComment(
                                widget.postId,
                                comment.id,
                                widget.currentUserId,
                              );
                            } else {
                              await _commentService.likeComment(
                                widget.postId,
                                comment.id,
                                widget.currentUserId,
                              );
                            }
                          } catch (e) {
                            // Handle error silently
                          }
                        },
                        child: Row(
                          children: [
                            FaIcon(
                              comment.likedBy.contains(widget.currentUserId)
                                  ? FontAwesomeIcons.solidHeart
                                  : FontAwesomeIcons.heart,
                              color: comment.likedBy
                                      .contains(widget.currentUserId)
                                  ? Colors.red
                                  : Colors.grey,
                              size: 12,
                            ),
                            if (comment.likes > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likes}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
