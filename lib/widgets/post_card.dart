import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:characters/characters.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../pages/comments_page.dart';
import '../pages/trending_page.dart';
import '../pages/profile_page.dart';
import 'cached_network_image_widget.dart';

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

class _ReactionsSheet extends StatefulWidget {
  final String postId;
  final PostService postService;

  const _ReactionsSheet({required this.postId, required this.postService});

  @override
  State<_ReactionsSheet> createState() => _ReactionsSheetState();
}

class _ReactionsSheetState extends State<_ReactionsSheet> {
  final List<_ReactionOption> _options = const [
    _ReactionOption(key: 'all', label: 'All', emoji: '⭐', color: Colors.yellow),
    _ReactionOption(key: 'like', label: 'Like', emoji: '👍', color: Colors.blue),
    _ReactionOption(key: 'love', label: 'Love', emoji: '❤️', color: Colors.redAccent),
    _ReactionOption(key: 'care', label: 'Care', emoji: '🤗', color: Colors.orangeAccent),
    _ReactionOption(key: 'haha', label: 'Haha', emoji: '😂', color: Colors.amber),
    _ReactionOption(key: 'wow', label: 'Wow', emoji: '😮', color: Colors.lightBlueAccent),
    _ReactionOption(key: 'sad', label: 'Sad', emoji: '😢', color: Colors.indigoAccent),
    _ReactionOption(key: 'angry', label: 'Angry', emoji: '😡', color: Colors.deepOrange),
  ];

  Map<String, String> _reactions = {};
  Map<String, Map<String, dynamic>> _users = {};
  bool _loading = true;
  Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      final data = snap.data() as Map<String, dynamic>?;
      final reactions = Map<String, String>.from(data?['reactions'] ?? {});

      final userIds = reactions.keys.toList();
      final usersList = await widget.postService.getUsersBasicByIds(userIds);
      final users = <String, Map<String, dynamic>>{
        for (final u in usersList) (u['id'] as String): u,
      };

      final counts = <String, int>{};
      counts['all'] = reactions.length;
      for (final o in _options.where((o) => o.key != 'all')) {
        counts[o.key] = reactions.values.where((rk) => rk == o.key).length;
      }

      if (!mounted) return;
      setState(() {
        _reactions = reactions;
        _users = users;
        _loading = false;
        _counts = counts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  List<Map<String, dynamic>> _filtered(String key) {
    if (key == 'all') {
      return _reactions.keys
          .map((uid) => {...?_users[uid], 'reaction': _reactions[uid]})
          .where((m) => m['id'] != null)
          .toList();
    }
    return _reactions.entries
        .where((e) => e.value == key)
        .map((e) => {...?_users[e.key], 'reaction': e.value})
        .where((m) => m['id'] != null)
        .toList();
  }

  int _countFor(String key) {
    return _counts[key] ?? 0;
  }

  _ReactionOption _optionFor(String key) {
    return _options.firstWhere((o) => o.key == key, orElse: () => _options.first);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: DefaultTabController(
        length: _options.length,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Reactions',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              indicatorColor: Colors.yellow,
              labelColor: Colors.yellow,
              unselectedLabelColor: Colors.grey,
              tabs: _options.map((o) => Tab(text: '${o.emoji} ${_countFor(o.key)}')).toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
                  : TabBarView(
                      children: _options.map((o) {
                        final items = _filtered(o.key);
                        if (items.isEmpty) {
                          return Center(
                            child: Text('No reactions', style: GoogleFonts.poppins(color: Colors.grey)),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(color: Colors.grey[900]),
                          itemBuilder: (context, index) {
                            final u = items[index];
                            final rk = u['reaction'] as String? ?? '';
                            final opt = _optionFor(rk);
                            return InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => ProfilePage(userId: u['id'] as String)),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[800]!),
                                ),
                                child: Row(
                                  children: [
                                    _buildAvatar(u['image'] as String? ?? '', u['name'] as String? ?? '', radius: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        u['name'] as String? ?? 'User',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: opt.color.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: opt.color.withOpacity(0.45)),
                                      ),
                                      child: Text(
                                        _emojiFor(rk),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String imageUrl, String name, {double radius = 18}) {
    return CachedCircleAvatar(
      imageUrl: imageUrl,
      displayName: name,
      radius: radius,
      backgroundColor: Colors.yellow,
      textColor: Colors.black,
    );
  }

  String _emojiFor(String key) {
    final found = _options.firstWhere((o) => o.key == key, orElse: () => const _ReactionOption(key: 'all', label: 'All', emoji: '⭐', color: Colors.yellow));
    return found.emoji;
  }
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
  bool _pickerVisible = false;
  late AnimationController _pickerController;
  Timer? _pickerHideTimer;
  int _hoveredPickerIndex = -1;
  final GlobalKey _pickerKey = GlobalKey();
  static const double _pickerIconSlotWidth = 44.0;
  static const double _pickerHorizontalPadding = 10.0;

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
    _pickerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  }

  void _openReactionsPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ReactionsSheet(postId: widget.post.id, postService: _postService),
          ),
        );
      },
    );
  }

  Future<void> _hapticSelect() async {
    // Try several haptic types for best device compatibility
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
    try { await HapticFeedback.selectionClick(); } catch (_) {}
    try { await HapticFeedback.vibrate(); } catch (_) {}
    try {
      const channel = MethodChannel('com.bvec.bees/haptics');
      await channel.invokeMethod('vibrate', {
        'duration': 25,
        'amplitude': 150,
      });
    } catch (_) {}
    try { await SystemSound.play(SystemSoundType.click); } catch (_) {}
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
    if (_currentReaction == 'like' || _currentReaction == "love" || _currentReaction == "care" || _currentReaction == "haha" || _currentReaction == "wow" || _currentReaction == "sad" || _currentReaction == "angry"  ) {
        _setReaction(null);
      // debugPrint("CLICKED");

      

      _currentReaction = null;

      

    } else {
      _setReaction('like');
    }
  }

  void _showInlineReactionPicker() {
    _pickerHideTimer?.cancel();
    setState(() {
      _pickerVisible = true;
    });
    _pickerController.forward(from: 0);
    _pickerHideTimer = Timer(const Duration(seconds: 2), () {
      _hideInlineReactionPicker();
    });
  }

  void _hideInlineReactionPicker() {
    _pickerHideTimer?.cancel();
    if (!_pickerVisible) return;
    _pickerController.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _pickerVisible = false;
      });
    });
  }

  int _indexFromGlobalPosition(Offset globalPosition) {
    final box = _pickerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return -1;
    final local = box.globalToLocal(globalPosition);
    final dx = local.dx - _pickerHorizontalPadding;
    final raw = (dx / _pickerIconSlotWidth).floor();
    final idx = raw.clamp(0, _reactionOptions.length - 1);
    return (dx < 0 || dx.isNaN || dx.isInfinite) ? -1 : idx;
  }

  void _onPickerPanStart(DragStartDetails details) {
    _pickerHideTimer?.cancel();
    final idx = _indexFromGlobalPosition(details.globalPosition);
    if (idx != -1) setState(() => _hoveredPickerIndex = idx);
  }

  void _onPickerPanUpdate(DragUpdateDetails details) {
    final idx = _indexFromGlobalPosition(details.globalPosition);
    if (idx != -1 && idx != _hoveredPickerIndex) {
      setState(() => _hoveredPickerIndex = idx);
      HapticFeedback.lightImpact();
    }
  }

  void _onPickerPanEnd(DragEndDetails details) {
    final idx = _hoveredPickerIndex;
    if (idx >= 0 && idx < _reactionOptions.length) {
      _setReaction(_reactionOptions[idx].key);
      _hapticSelect();
    }
    setState(() => _hoveredPickerIndex = -1);
    _hideInlineReactionPicker();
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
          onLongPress: _showInlineReactionPicker,
          onLongPressMoveUpdate: (details) {
            if (!_pickerVisible) return;
            _pickerHideTimer?.cancel();
            final idx = _indexFromGlobalPosition(details.globalPosition);
            if (idx != -1 && idx != _hoveredPickerIndex) {
              setState(() => _hoveredPickerIndex = idx);
            }
          },
          onLongPressEnd: (details) {
            if (_pickerVisible && _hoveredPickerIndex >= 0 && _hoveredPickerIndex < _reactionOptions.length) {
              _setReaction(_reactionOptions[_hoveredPickerIndex].key);
            }
            setState(() => _hoveredPickerIndex = -1);
            _hideInlineReactionPicker();
          },
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
        if (_pickerVisible)
          Positioned(
            top: -70,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _pickerController, curve: Curves.easeOut),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(parent: _pickerController, curve: Curves.easeOutBack),
                ),
                child: Transform.translate(
                  offset: const Offset(110, 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: _onPickerPanStart,
                    onPanUpdate: _onPickerPanUpdate,
                    onPanEnd: _onPickerPanEnd,
                    child: Container(
                      key: _pickerKey,
                      padding: const EdgeInsets.symmetric(horizontal: _pickerHorizontalPadding, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.grey[800]!, width: 1),
                      ),
                      child: AnimatedBuilder(
                        animation: _pickerController,
                        builder: (context, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < _reactionOptions.length; i++)
                                _buildPickerIcon(_reactionOptions[i], i),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
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
    _pickerHideTimer?.cancel();
    _pickerController.dispose();
    super.dispose();
  }

  Widget _buildPickerIcon(_ReactionOption option, int index) {
    final curve = CurvedAnimation(
      parent: _pickerController,
      curve: Interval(
        (0.05 * index).clamp(0.0, 0.9),
        (0.05 * index + 0.6).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final translateY = (1 - curve.value) * 12.0;
        final baseScale = 0.9 + (curve.value * 0.1);
        final isHovered = _hoveredPickerIndex == index;
        final scale = baseScale * (isHovered ? 1.25 : 1.0);
        return Transform.translate(
          offset: Offset(0, -translateY),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hoveredPickerIndex = index),
        onTapCancel: () => setState(() => _hoveredPickerIndex = -1),
        onTapUp: (_) {
          setState(() => _hoveredPickerIndex = -1);
          _setReaction(option.key);
          _hapticSelect();
          _hideInlineReactionPicker();
        },
        child: Container(
          width: _pickerIconSlotWidth,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_hoveredPickerIndex == index)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: option.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    option.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                ],
              ),
              // Removed label beneath hovered emoji for a cleaner UI
            ],
          ),
        ),
      ),
    );
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
            child: _buildContentWithHashtags(),
          ),
          // Images
          if (widget.post.imageUrls != null && widget.post.imageUrls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: CachedNetworkImageWidget(
                imageUrl: widget.post.imageUrls!.first,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          // Engagement stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openReactionsPanel,
                    child: _buildReactionsSummary(),
                  ),
                ),
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

  Widget _buildContentWithHashtags() {
    final spans = <InlineSpan>[];
    final text = widget.post.content;
    final combinedPattern = RegExp(r'(#\w+|@\w+)');
    int lastMatchEnd = 0;

    for (final match in combinedPattern.allMatches(text)) {
      // Add text before match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ));
      }

      final matchText = match.group(0)!;
      final isHashtag = matchText.startsWith('#');
      final isMention = matchText.startsWith('@');

      if (isHashtag) {
        // Add clickable hashtag
        spans.add(TextSpan(
          text: matchText,
          style: GoogleFonts.poppins(
            color: Colors.yellow,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrendingPage(hashtag: matchText),
                ),
              );
            },
        ));
      } else if (isMention) {
        // Render mention as a pill chip (yellow background) and make it clickable
        // Debug: log mention chip rendering
        debugPrint('[PostCard] Rendering mention chip for: $matchText');
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () async {
                debugPrint('[PostCard] Mention tapped: $matchText');
                final token = matchText.substring(1);
                try {
                  // Try rollNo (stored normalized to lowercase)
                  var qs = await FirebaseFirestore.instance
                      .collection('users')
                      .where('rollNo', isEqualTo: token.toLowerCase())
                      .limit(1)
                      .get();

                  if (qs.docs.isEmpty) {
                    // Fallback to name match
                    final mentionName = token.replaceAll('_', ' ');
                    qs = await FirebaseFirestore.instance
                        .collection('users')
                        .where('name', isEqualTo: mentionName)
                        .limit(1)
                        .get();
                  }

                  if (qs.docs.isNotEmpty && mounted) {
                    final userId = qs.docs.first.id;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: userId),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error finding mentioned user: $e');
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  matchText,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
        children: spans,
      ),
      textAlign: TextAlign.start,
      softWrap: true,
    );
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 20}) {
    return CachedCircleAvatar(
      imageUrl: imageUrl,
      displayName: userName,
      radius: radius,
      backgroundColor: Colors.yellow,
      textColor: Colors.black,
    );
  }
}
