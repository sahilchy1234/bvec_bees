import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import '../models/rumor_model.dart';
import '../models/rumor_comment_model.dart';
import '../models/user_model.dart';
import '../services/rumor_service.dart';
import '../services/user_directory_cache_service.dart';
import '../widgets/cached_network_image_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_page.dart';

class RumorDiscussionPage extends StatefulWidget {
  final RumorModel rumor;

  const RumorDiscussionPage({
    super.key,
    required this.rumor,
  });

  @override
  State<RumorDiscussionPage> createState() => _RumorDiscussionPageState();
}

class _RumorDiscussionPageState extends State<RumorDiscussionPage> {
  final RumorService _rumorService = RumorService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late String _currentUserId;
  String? _replyingToCommentId;
  String? _replyingToAuthor;
  
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
    _loadCurrentUserId();
    _commentController.addListener(_onCommentTextChanged);
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('current_user_uid') ?? '';
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _commentController.removeListener(_onCommentTextChanged);
    _mentionDebounce?.cancel();
    _removeMentionOverlay();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final authorName = prefs.getString('current_user_name') ?? 'User';
      final authorImage = prefs.getString('current_user_avatar') ?? '';

      await _rumorService.addComment(
        widget.rumor.id,
        _commentController.text.trim(),
        authorId: _currentUserId,
        authorName: authorName,
        authorImage: authorImage,
        parentCommentId: _replyingToCommentId,
      );

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToAuthor = null;
      });
    } catch (e) {
      // Silently ignore UI feedback here; error could be logged if desired.
    }
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
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
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
                    radius: 18,
                    backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    backgroundColor: Colors.amber,
                    child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                        ? Text(
                            (user.name ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    user.name ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _mentionTokenFor(user),
                    style: const TextStyle(
                      color: Colors.amber,
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const FaIcon(
                FontAwesomeIcons.fire,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Discussion',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Comments Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            // border: Border.all(
                            //   color: Colors.amber.withOpacity(0.3),
                            // ),
                          ),
                          child: Row(
                            children: [
                              const FaIcon(
                                FontAwesomeIcons.comments,
                                color: Colors.amber,
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.rumor.commentCount} Comments',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Comments Stream
                StreamBuilder<List<RumorCommentModel>>(
                  stream: _rumorService.getCommentsStream(widget.rumor.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: FaIcon(
                                    FontAwesomeIcons.commentSlash,
                                    color: Colors.amber.withOpacity(0.5),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Be the first to share your thoughts!',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final comment = snapshot.data![index];
                          return _CommentThread(
                            comment: comment,
                            rumorId: widget.rumor.id,
                            currentUserId: _currentUserId,
                            rumorService: _rumorService,
                            onReply: (commentId, author) {
                              setState(() {
                                _replyingToCommentId = commentId;
                                _replyingToAuthor = author;
                              });
                              _commentFocusNode.requestFocus();
                            },
                            formatTime: _formatTime,
                          );
                        },
                        childCount: snapshot.data!.length,
                      ),
                    );
                  },
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          ),
          
          // Comment Input
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToCommentId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.1),
                              Colors.orange.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          // border: Border.all(
                          //   color: Colors.amber.withOpacity(0.3),
                          // ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.reply,
                                color: Colors.amber,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Replying to',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _replyingToAuthor ?? 'Anonymous',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _replyingToCommentId = null;
                                  _replyingToAuthor = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: CompositedTransformTarget(
                            link: _mentionLayerLink,
                            child: Container(
                              key: _commentFieldKey,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add your thoughts...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.newline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _submitComment,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              // boxShadow: [
                              //   BoxShadow(
                              //     color: Colors.amber.withOpacity(0.3),
                              //     blurRadius: 12,
                              //     offset: const Offset(0, 4),
                              //   ),
                              // ],
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildRumorContentWithMentions(
  BuildContext context,
  String text, {
  double fontSize = 14,
  double height = 1.5,
}) {
  final spans = <InlineSpan>[];
  final combinedPattern = RegExp(r'(#\w+|@\w+)');
  int lastMatchEnd = 0;

  for (final match in combinedPattern.allMatches(text)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd, match.start),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: height,
        ),
      ));
    }

    final matchText = match.group(0)!;
    final isHashtag = matchText.startsWith('#');
    final isMention = matchText.startsWith('@');

    if (isHashtag) {
      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(
          color: Colors.amber,
          fontSize: fontSize,
          height: height,
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
                // Prefer cached verified users to avoid extra reads
                List<UserModel>? users =
                    await UserDirectoryCacheService.instance.getCachedUsers();

                if (users == null || users.isEmpty) {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .where('isVerified', isEqualTo: true)
                      .limit(500)
                      .get();

                  users = snapshot.docs.map((doc) {
                    final data = Map<String, dynamic>.from(doc.data());
                    data['uid'] = doc.id;
                    return UserModel.fromMap(data);
                  }).toList();

                  await UserDirectoryCacheService.instance.cacheUsers(users);
                }

                UserModel? targetUser;
                if (users.isNotEmpty) {
                  final lowerToken = token.toLowerCase();
                  targetUser = users.firstWhere(
                    (u) => (u.rollNo?.toLowerCase() == lowerToken),
                    orElse: () {
                      final mentionName = token.replaceAll('_', ' ').toLowerCase();
                      return users!.firstWhere(
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

                if (targetUser != null && targetUser.uid.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(userId: targetUser!.uid),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error finding mentioned user in rumor comment: $e');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                matchText,
                style: const TextStyle(
                  color: Colors.amber,
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
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        height: height,
      ),
    ));
  }

  return RichText(
    text: TextSpan(children: spans),
    textAlign: TextAlign.start,
    softWrap: true,
  );
}


class _CommentThread extends StatefulWidget {
  final RumorCommentModel comment;
  final String rumorId;
  final String currentUserId;
  final RumorService rumorService;
  final Function(String, String) onReply;
  final String Function(DateTime) formatTime;

  const _CommentThread({
    required this.comment,
    required this.rumorId,
    required this.currentUserId,
    required this.rumorService,
    required this.onReply,
    required this.formatTime,
  });

  @override
  State<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<_CommentThread> with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  bool _showReplies = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.likedByUsers.contains(widget.currentUserId);
    _likeCount = widget.comment.likes;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        // border: Border.all(
        //   color: Colors.white.withOpacity(0.05),
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CachedCircleAvatar(
                      imageUrl: widget.comment.authorImage,
                      displayName: widget.comment.authorName,
                      radius: 18,
                      backgroundColor: Colors.amber,
                      textColor: Colors.black,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.comment.authorName.isNotEmpty
                                    ? widget.comment.authorName
                                    : 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey[600],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.formatTime(widget.comment.timestamp),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          buildRumorContentWithMentions(
                            context,
                            widget.comment.content,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          _animationController.forward().then((_) {
                            _animationController.reverse();
                          });
                          
                          await widget.rumorService.likeComment(
                            widget.rumorId,
                            widget.comment.id,
                            widget.currentUserId,
                          );
                          setState(() {
                            _isLiked = !_isLiked;
                            _likeCount += _isLiked ? 1 : -1;
                          });
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isLiked
                              ? Colors.red.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          // border: Border.all(
                          //   color: _isLiked
                          //       ? Colors.red.withOpacity(0.3)
                          //       : Colors.white.withOpacity(0.1),
                          // ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Curves.easeOut,
                                ),
                              ),
                              child: FaIcon(
                                _isLiked
                                    ? FontAwesomeIcons.solidHeart
                                    : FontAwesomeIcons.heart,
                                color: _isLiked ? Colors.red : Colors.grey[400],
                                size: 12,
                              ),
                            ),
                            if (_likeCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                _likeCount.toString(),
                                style: TextStyle(
                                  color: _isLiked ? Colors.red : Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final author = widget.comment.authorName.isNotEmpty
                            ? widget.comment.authorName
                            : 'User';
                        widget.onReply(widget.comment.id, author);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          // border: Border.all(
                          //   color: Colors.white.withOpacity(0.1),
                          // ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.reply,
                              color: Colors.grey[400],
                              size: 12,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (widget.comment.replyCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showReplies = !_showReplies;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withOpacity(0.1),
                              Colors.orange.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          // border: Border.all(
                          //   color: Colors.amber.withOpacity(0.2),
                          // ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: _showReplies ? 0.5 : 0.0,
                              child: const FaIcon(
                                FontAwesomeIcons.chevronDown,
                                color: Colors.amber,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showReplies
                                  ? 'Hide ${widget.comment.replyCount} ${widget.comment.replyCount == 1 ? 'reply' : 'replies'}'
                                  : 'View ${widget.comment.replyCount} ${widget.comment.replyCount == 1 ? 'reply' : 'replies'}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _showReplies && widget.comment.replyCount > 0
                ? StreamBuilder<List<RumorCommentModel>>(
                    stream: widget.rumorService.getRepliesStream(
                      widget.rumorId,
                      widget.comment.id,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        padding: const EdgeInsets.only(left: 48, right: 12, bottom: 12),
                        child: Column(
                          children: snapshot.data!.map((reply) {
                            return _ReplyComment(
                              comment: reply,
                              rumorId: widget.rumorId,
                              currentUserId: widget.currentUserId,
                              rumorService: widget.rumorService,
                              formatTime: widget.formatTime,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ReplyComment extends StatefulWidget {
  final RumorCommentModel comment;
  final String rumorId;
  final String currentUserId;
  final RumorService rumorService;
  final String Function(DateTime) formatTime;

  const _ReplyComment({
    required this.comment,
    required this.rumorId,
    required this.currentUserId,
    required this.rumorService,
    required this.formatTime,
  });

  @override
  State<_ReplyComment> createState() => _ReplyCommentState();
}

class _ReplyCommentState extends State<_ReplyComment> with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int _likeCount;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.likedByUsers.contains(widget.currentUserId);
    _likeCount = widget.comment.likes;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(
        //   color: Colors.white.withOpacity(0.05),
        // ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedCircleAvatar(
                imageUrl: widget.comment.authorImage,
                displayName: widget.comment.authorName,
                radius: 14,
                backgroundColor: Colors.amber,
                textColor: Colors.black,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.comment.authorName.isNotEmpty
                              ? widget.comment.authorName
                              : 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.formatTime(widget.comment.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    buildRumorContentWithMentions(
                      context,
                      widget.comment.content,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              try {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                });
                
                await widget.rumorService.likeComment(
                  widget.rumorId,
                  widget.comment.id,
                  widget.currentUserId,
                );
                setState(() {
                  _isLiked = !_isLiked;
                  _likeCount += _isLiked ? 1 : -1;
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isLiked
                    ? Colors.red.withOpacity(0.15)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                // border: Border.all(
                //   color: _isLiked
                //       ? Colors.red.withOpacity(0.3)
                //       : Colors.white.withOpacity(0.08),
                // ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: FaIcon(
                      _isLiked
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.heart,
                      color: _isLiked ? Colors.red : Colors.grey[500],
                      size: 10,
                    ),
                  ),
                  if (_likeCount > 0) ...[
                    const SizedBox(width: 5),
                    Text(
                      _likeCount.toString(),
                      style: TextStyle(
                        color: _isLiked ? Colors.red : Colors.grey[500],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
