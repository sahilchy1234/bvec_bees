import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../pages/comments_page.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onComment;
  final VoidCallback? onAuthorTap;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onDelete,
    required this.onComment,
    this.onAuthorTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _FloatingReactionBubble {
  final _ReactionOption option;
  final AnimationController controller;
  final Animation<double> offsetAnimation;
  final Animation<double> opacityAnimation;
  final Animation<double> scaleAnimation;

  _FloatingReactionBubble({
    required this.option,
    required this.controller,
    required this.offsetAnimation,
    required this.opacityAnimation,
    required this.scaleAnimation,
  });
}

class _ReactionOption {
  final String key;
  final String label;
  final String emoji;
  final Color color;

  const _ReactionOption({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
  });
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  final PostService _postService = PostService();

  late Map<String, int> _reactionCounts;
  String? _currentReaction;
  late int _totalReactions;
  final List<_FloatingReactionBubble> _floatingBubbles = [];

  final List<_ReactionOption> _reactionOptions = const [
    _ReactionOption(key: 'like', label: 'Like', emoji: '👍', color: Colors.blue),
    _ReactionOption(key: 'love', label: 'Love', emoji: '❤️', color: Colors.redAccent),
    _ReactionOption(key: 'care', label: 'Care', emoji: '🤗', color: Colors.orangeAccent),
    _ReactionOption(key: 'haha', label: 'Haha', emoji: '😂', color: Colors.amber),
    _ReactionOption(key: 'wow', label: 'Wow', emoji: '😮', color: Colors.lightBlueAccent),
    _ReactionOption(key: 'sad', label: 'Sad', emoji: '😢', color: Colors.indigoAccent),
    _ReactionOption(key: 'angry', label: 'Angry', emoji: '😡', color: Colors.deepOrange),
  ];

  late Map<String, _ReactionOption> _reactionOptionByKey;

  @override
  void initState() {
    super.initState();
    _reactionOptionByKey = {
      for (final option in _reactionOptions) option.key: option
    };

    _reactionCounts = {..._createDefaultReactionCounts(), ...widget.post.reactionCounts};
    _currentReaction = widget.post.reactions[widget.currentUserId];
    _totalReactions = _reactionCounts.values.fold<int>(0, (sum, value) => sum + value);
  }

  Map<String, int> _createDefaultReactionCounts() {
    return {for (final option in _reactionOptions) option.key: 0};
  }

  Future<void> _setReaction(String? reactionKey) async {
    final previousReaction = _currentReaction;
    final previousCounts = Map<String, int>.from(_reactionCounts);
    final previousTotal = _totalReactions;

    setState(() {
      _applyReactionChange(reactionKey);
    });

    if (reactionKey != null && reactionKey != previousReaction) {
      _spawnFloatingReaction(reactionKey);
    }

    try {
      if (reactionKey == null) {
        await _postService.removeReaction(widget.post.id, widget.currentUserId);
      } else {
        await _postService.setReaction(widget.post.id, widget.currentUserId, reactionKey);
      }
    } catch (e) {
      setState(() {
        _reactionCounts = previousCounts;
        _currentReaction = previousReaction;
        _totalReactions = previousTotal;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _applyReactionChange(String? reactionKey) {
    if (reactionKey == _currentReaction) {
      // Remove reaction
      if (_currentReaction != null) {
        final key = _currentReaction!;
        _reactionCounts[key] = (_reactionCounts[key] ?? 1) - 1;
        if (_reactionCounts[key]! < 0) _reactionCounts[key] = 0;
        _totalReactions = (_totalReactions - 1).clamp(0, 1 << 20);
        _currentReaction = null;
      }
      return;
    }

    // Remove previous reaction
    if (_currentReaction != null) {
      final prevKey = _currentReaction!;
      _reactionCounts[prevKey] = (_reactionCounts[prevKey] ?? 1) - 1;
      if (_reactionCounts[prevKey]! < 0) {
        _reactionCounts[prevKey] = 0;
      }
      _totalReactions = (_totalReactions - 1).clamp(0, 1 << 20);
    }

    if (reactionKey != null) {
      _reactionCounts[reactionKey] = (_reactionCounts[reactionKey] ?? 0) + 1;
      _totalReactions += 1;
      _currentReaction = reactionKey;
    }
  }

  _ReactionOption _reactionForKey(String key) {
    return _reactionOptionByKey[key] ?? _reactionOptions.first;
  }

  _ReactionOption? get _currentReactionOption =>
      _currentReaction != null ? _reactionOptionByKey[_currentReaction!] : null;

  void _handlePrimaryReactionTap() {
    if (_currentReaction == 'like') {
      _setReaction(null);
    } else {
      _setReaction('like');
    }
  }

  void _spawnFloatingReaction(String reactionKey) {
    final option = _reactionOptionByKey[reactionKey];
    if (option == null) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    final curved = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);

    final bubble = _FloatingReactionBubble(
      option: option,
      controller: controller,
      offsetAnimation: Tween<double>(begin: 0, end: -80).animate(curved),
      opacityAnimation: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: controller, curve: const Interval(0.2, 1.0, curve: Curves.easeIn)),
      ),
      scaleAnimation: Tween<double>(begin: 0.8, end: 1.3).animate(
        CurvedAnimation(parent: controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
      ),
    );

    setState(() {
      _floatingBubbles.add(bubble);
    });

    controller.forward().whenComplete(() {
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _floatingBubbles.remove(bubble);
      });
      controller.dispose();
    });
  }

  void _showReactionPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _reactionOptions.map((option) {
              final isSelected = option.key == _currentReaction;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _setReaction(option.key);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        option.emoji,
                        style: TextStyle(fontSize: isSelected ? 42 : 36),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option.label,
                      style: GoogleFonts.poppins(
                        color: isSelected ? option.color : Colors.white,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildReactionButton() {
    final option = _currentReactionOption;
    final isActive = option != null;
    final emoji = option?.emoji ?? '👍';
    final label = option?.label ?? 'Like';
    final color = option?.color ?? Colors.grey;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _handlePrimaryReactionTap,
          onLongPress: _showReactionPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.12) : Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? color.withOpacity(0.4) : Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isActive ? color : Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        ..._floatingBubbles.map((bubble) {
          return AnimatedBuilder(
            animation: bubble.controller,
            builder: (context, child) {
              return Positioned(
                top: bubble.offsetAnimation.value,
                child: Opacity(
                  opacity: bubble.opacityAnimation.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: bubble.scaleAnimation.value,
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bubble.option.color.withOpacity(0.6)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                bubble.option.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  List<_ReactionOption> _topReactions() {
    final entries = _reactionCounts.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((entry) => _reactionForKey(entry.key)).take(3).toList();
  }

  Widget _buildReactionsSummary() {
    final topReactions = _topReactions();
    if (_totalReactions == 0) {
      return Text(
        'Be the first to react',
        style: GoogleFonts.poppins(
          color: Colors.grey,
          fontSize: 12,
        ),
      );
    }

    return Row(
      children: [
        if (topReactions.isNotEmpty)
          Row(
            children: topReactions
                .map(
                  (option) => Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      option.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
          ),
        if (topReactions.isNotEmpty) const SizedBox(width: 6),
        Text(
          '$_totalReactions reactions',
          style: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final bubble in _floatingBubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: widget.onAuthorTap,
                    child: Row(
                      children: [
                        _buildUserAvatar(widget.post.authorImage, widget.post.authorName, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.post.authorName,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatTime(widget.post.timestamp),
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.post.authorId == widget.currentUserId)
                  PopupMenuButton(
                    color: Colors.grey[900],
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Text(
                          'Delete',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        onTap: () async {
                          try {
                            await _postService.deletePost(widget.post.id);
                            widget.onDelete();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.content,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (widget.post.hashtags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: widget.post.hashtags
                          .map((tag) => Text(
                                tag,
                                style: GoogleFonts.poppins(
                                  color: Colors.yellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          // Images
          if (widget.post.imageUrls != null && widget.post.imageUrls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.post.imageUrls!.first,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.grey[900],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.yellow,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // Engagement stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _buildReactionsSummary()),
                Text(
                  '${widget.post.comments} comments',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${widget.post.shares} shares',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(),
                GestureDetector(
                  onTap: widget.onComment,
                  child: _buildActionButton(
                    icon: FontAwesomeIcons.comment,
                    label: 'Comment',
                    color: Colors.grey,
                    onTap: widget.onComment,
                  ),
                ),
                _buildActionButton(
                  icon: FontAwesomeIcons.share,
                  label: 'Share',
                  color: Colors.yellow,
                  onTap: () async {
                    try {
                      await _postService.sharePost(widget.post.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post shared!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isActive = color == Colors.red || color == Colors.yellow;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 20}) {
    String _initials() {
      final trimmed = userName.trim();
      if (trimmed.isEmpty) return '?';
      final parts = trimmed.split(RegExp(r'\s+'));
      final letters = parts
          .where((part) => part.isNotEmpty)
          .map((part) => part.characters.first.toUpperCase())
          .toList();
      if (letters.isEmpty) return '?';
      return letters.take(2).join();
    }

    Widget fallbackAvatar() {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.yellow,
        child: Text(
          _initials(),
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    if (imageUrl.isEmpty) {
      return fallbackAvatar();
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[900],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
}
