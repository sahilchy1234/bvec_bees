import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';
import '../services/user_directory_cache_service.dart';
import 'profile_page.dart';

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
  String? _replyingToCommentId;
  String? _replyingToAuthor;
  final FocusNode _commentFocusNode = FocusNode();
  final Set<String> _expandedCommentIds = {};
  
  // Mention autocomplete
  final LayerLink _mentionLayerLink = LayerLink();
  final GlobalKey _commentFieldKey = GlobalKey();
  OverlayEntry? _mentionOverlay;
  List<UserModel> _mentionSuggestions = [];
  String _currentMentionQuery = '';
  Timer? _mentionDebounce;
  List<UserModel> _mentionUserCache = [];
  bool _mentionUsersLoaded = false;
  bool _isLoadingMentionUsers = false;

  @override
  void initState() {
    super.initState();
    _commentsStream = _commentService.streamComments(widget.postId);
    _commentController.addListener(_onCommentTextChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _listController.dispose();
    _commentFocusNode.dispose();
    _mentionDebounce?.cancel();
    _removeMentionOverlay();
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
        parentCommentId: _replyingToCommentId,
      );

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToAuthor = null;
      });
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

  String _mentionTokenFor(UserModel user) {
    final rawName = user.name?.trim();
    if (rawName != null && rawName.isNotEmpty) {
      var sanitized = rawName.replaceAll(RegExp(r'\s+'), '_');
      sanitized = sanitized.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
      if (sanitized.isNotEmpty) {
        return '@$sanitized';
      }
    }

    final roll = user.rollNo?.trim();
    if (roll != null && roll.isNotEmpty) {
      var sanitizedRoll = roll.replaceAll(RegExp(r'\s+'), '');
      sanitizedRoll = sanitizedRoll.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
      if (sanitizedRoll.isNotEmpty) {
        return '@${sanitizedRoll.toLowerCase()}';
      }
    }

    return '@user';
  }

  void _onCommentTextChanged() {
    final text = _commentController.text;
    final cursorPos = _commentController.selection.baseOffset;

    if (cursorPos < 0) return;

    int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atIndex = i;
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') {
        break;
      }
    }

    if (atIndex >= 0) {
      final query = text.substring(atIndex + 1, cursorPos);
      if (query.isNotEmpty && query.length >= 2) {
        if (query == _currentMentionQuery) {
          return;
        }
        _mentionDebounce?.cancel();
        _mentionDebounce = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _searchUsers(query);
        });
      } else {
        _mentionDebounce?.cancel();
        _removeMentionOverlay();
      }
    } else {
      _mentionDebounce?.cancel();
      _removeMentionOverlay();
    }
  }

  Future<void> _ensureMentionUsersLoaded() async {
    if (_mentionUsersLoaded || _isLoadingMentionUsers) return;
    _isLoadingMentionUsers = true;
    try {
      // Try cached users first
      final cached = await UserDirectoryCacheService.instance.getCachedUsers();
      if (cached != null && cached.isNotEmpty) {
        _mentionUserCache = cached;
        _mentionUsersLoaded = true;
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .limit(500)
          .get();

      final users = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['uid'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();

      _mentionUserCache = users;
      _mentionUsersLoaded = true;
      await UserDirectoryCacheService.instance.cacheUsers(users);
    } catch (_) {
    } finally {
      _isLoadingMentionUsers = false;
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      await _ensureMentionUsersLoaded();

      if (!_mentionUsersLoaded || _mentionUserCache.isEmpty) {
        _removeMentionOverlay();
        return;
      }

      final q = query.toLowerCase();
      final users = _mentionUserCache
          .where((user) {
            final name = (user.name ?? '').toLowerCase();
            final roll = (user.rollNo ?? '').toLowerCase();
            final nameMatches = name.contains(q);
            final rollMatches = roll.contains(q);
            return nameMatches || rollMatches;
          })
          .toList();

      if (users.isNotEmpty) {
        setState(() {
          _mentionSuggestions = users;
          _currentMentionQuery = query;
        });
        _showMentionOverlay();
      } else {
        _removeMentionOverlay();
      }
    } catch (_) {
      _removeMentionOverlay();
    }
  }

  void _showMentionOverlay() {
    _removeMentionOverlay(clearSuggestions: false);
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = screenWidth - 32; // match horizontal padding

    _mentionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 72,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: overlayWidth,
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _mentionSuggestions.length,
              itemBuilder: (context, index) {
                final user = _mentionSuggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    backgroundColor: Colors.yellow,
                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                        ? Text(
                            (user.name ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    user.name ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _mentionTokenFor(user),
                    style: GoogleFonts.poppins(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => _insertMention(user),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(_mentionOverlay!);
  }

  void _insertMention(UserModel user) {
    final text = _commentController.text;
    final cursorPos = _commentController.selection.baseOffset;

    int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atIndex = i;
        break;
      }
    }

    if (atIndex >= 0) {
      final before = text.substring(0, atIndex);
      final after = text.substring(cursorPos);
      final mention = _mentionTokenFor(user);

      _commentController.text = '$before$mention $after';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: before.length + mention.length + 1),
      );
    }

    _removeMentionOverlay();
  }

  void _removeMentionOverlay({bool clearSuggestions = true}) {
    _mentionOverlay?.remove();
    _mentionOverlay = null;
    if (clearSuggestions) {
      setState(() {
        _mentionSuggestions = [];
      });
    }
  }

  Widget _buildContentWithMentions(String text) {
    final spans = <InlineSpan>[];
    final combinedPattern = RegExp(r'(#\w+|@\w+)');
    int lastMatchEnd = 0;

    for (final match in combinedPattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        ));
      }

      final matchText = match.group(0)!;
      final isHashtag = matchText.startsWith('#');
      final isMention = matchText.startsWith('@');

      if (isHashtag) {
        spans.add(TextSpan(
          text: matchText,
          style: GoogleFonts.poppins(
            color: Colors.yellow,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (isMention) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () async {
                final token = matchText.substring(1);
                try {
                  // Prefer local cache of verified users to avoid extra reads
                  await _ensureMentionUsersLoaded();

                  UserModel? targetUser;
                  if (_mentionUserCache.isNotEmpty) {
                    final lowerToken = token.toLowerCase();
                    targetUser = _mentionUserCache.firstWhere(
                      (u) => (u.rollNo?.toLowerCase() == lowerToken),
                      orElse: () {
                        final mentionName = token.replaceAll('_', ' ').toLowerCase();
                        return _mentionUserCache.firstWhere(
                          (u) => (u.name ?? '').trim().toLowerCase() == mentionName,
                          orElse: () => UserModel(
                            uid: '',
                            email: '',
                          ),
                        );
                      },
                    );

                    if (targetUser.uid.isEmpty) {
                      targetUser = null;
                    }
                  }

                  // Fallback to Firestore lookup only if not found in cache
                  if (targetUser == null) {
                    var qs = await FirebaseFirestore.instance
                        .collection('users')
                        .where('rollNo', isEqualTo: token.toLowerCase())
                        .limit(1)
                        .get();

                    if (qs.docs.isEmpty) {
                      final mentionName = token.replaceAll('_', ' ');
                      qs = await FirebaseFirestore.instance
                          .collection('users')
                          .where('name', isEqualTo: mentionName)
                          .limit(1)
                          .get();
                    }

                    if (qs.docs.isNotEmpty) {
                      final data = qs.docs.first.data() as Map<String, dynamic>;
                      data['uid'] = qs.docs.first.id;
                      targetUser = UserModel.fromMap(data);
                    }
                  }

                  if (targetUser != null && targetUser.uid.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: targetUser!.uid),
                      ),
                    );
                  }
                } catch (e) {
                  // Silently ignore navigation errors; tapping mention is best-effort.
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  matchText,
                  style: GoogleFonts.poppins(
                    color: Colors.yellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 13,
          height: 1.4,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.start,
      softWrap: true,
    );
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_replyingToCommentId != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.reply,
                                      color: Colors.yellow,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Replying to ${_replyingToAuthor ?? ''}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.yellow,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _replyingToCommentId = null;
                                          _replyingToAuthor = null;
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.yellow,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            CompositedTransformTarget(
                              link: _mentionLayerLink,
                              child: Container(
                                key: _commentFieldKey,
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _commentFocusNode,
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
                            ),
                          ],
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
    final isExpanded = _expandedCommentIds.contains(comment.id);

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
                      _buildContentWithMentions(comment.content),
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
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyingToCommentId = comment.id;
                            _replyingToAuthor = comment.authorName;
                          });
                          _commentFocusNode.requestFocus();
                        },
                        child: Text(
                          'Reply',
                          style: GoogleFonts.poppins(
                            color: Colors.yellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (comment.replyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedCommentIds.remove(comment.id);
                              } else {
                                _expandedCommentIds.add(comment.id);
                              }
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedRotation(
                                duration: const Duration(milliseconds: 200),
                                turns: isExpanded ? 0.5 : 0.0,
                                child: const Icon(
                                  Icons.expand_more,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpanded
                                    ? 'Hide ${comment.replyCount} ${comment.replyCount == 1 ? 'reply' : 'replies'}'
                                    : 'View ${comment.replyCount} ${comment.replyCount == 1 ? 'reply' : 'replies'}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(left: 24, top: 6),
                            child: StreamBuilder<List<Comment>>(
                              stream: _commentService.streamReplies(
                                widget.postId,
                                comment.id,
                              ),
                              builder: (context, snapshot) {
                                final replies = snapshot.data ?? [];
                                if (replies.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: replies
                                      .map((reply) => _buildReplyItem(reply))
                                      .toList(),
                                );
                              },
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

  Widget _buildReplyItem(Comment reply) {
    final isOwnReply = reply.authorId == widget.currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(reply.authorImage, reply.authorName, radius: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reply.authorName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (isOwnReply)
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
                                        reply.id,
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
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _buildContentWithMentions(reply.content),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatTime(reply.timestamp),
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        try {
                          if (reply.likedBy.contains(widget.currentUserId)) {
                            await _commentService.unlikeComment(
                              widget.postId,
                              reply.id,
                              widget.currentUserId,
                            );
                          } else {
                            await _commentService.likeComment(
                              widget.postId,
                              reply.id,
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
                            reply.likedBy.contains(widget.currentUserId)
                                ? FontAwesomeIcons.solidHeart
                                : FontAwesomeIcons.heart,
                            color: reply.likedBy
                                    .contains(widget.currentUserId)
                                ? Colors.red
                                : Colors.grey,
                            size: 11,
                          ),
                          if (reply.likes > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '${reply.likes}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
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
  }
}
