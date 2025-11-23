import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/feed_cache_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'comments_page.dart';
import 'chat_page.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;
  late Future<UserModel?> _userFuture;
  String? _currentUserId;
  bool _isUpdatingAvatar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userFuture = _authService.getUserProfile(widget.userId);
    _loadCurrentUserId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {
      _userFuture = _authService.getUserProfile(widget.userId);
    });
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('current_user_uid');

    if (!mounted) return;

    setState(() {
      _currentUserId = (storedId != null && storedId.isNotEmpty)
          ? storedId
          : FirebaseAuth.instance.currentUser?.uid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUserId = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = (_currentUserId != null && _currentUserId!.isNotEmpty)
        ? _currentUserId
        : authUserId;
    final isOwnProfile = widget.userId == effectiveUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<UserModel?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                'User not found',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: Colors.black,
                  expandedHeight: 360,
                  floating: false,
                  pinned: true,
                  // leading: IconButton(
                  //   icon: const Icon(Icons.arrow_back, color: Colors.white),
                  //   onPressed: () => Navigator.pop(context),
                  // ),
                  actions: const [],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.black,
                      padding: const EdgeInsets.only(top: 48, bottom: 32),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildProfileHeader(user, isOwnProfile),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.yellow,
                      labelColor: Colors.yellow,
                      dividerColor: const Color.fromARGB(0, 14, 14, 14),
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(
                          icon: FaIcon(FontAwesomeIcons.tableCells, size: 18),
                          text: 'Posts',
                        ),
                        Tab(
                          icon: FaIcon(FontAwesomeIcons.at, size: 18),
                          text: 'Mentions',
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(user),
                _buildMentionsTab(user),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showReportDialogForUser(UserModel user) async {
    final reporterId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (reporterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to report users')),
      );
      return;
    }
    if (reporterId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot report yourself')),
      );
      return;
    }

    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Report user',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Tell us what is wrong with this profile',
              hintStyle: GoogleFonts.poppins(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.yellow),
              ),
              filled: true,
              fillColor: Colors.grey[850],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[300]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Submit',
                style: GoogleFonts.poppins(color: Colors.yellow),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final text = controller.text.trim();
      await _reportService.reportContent(
        reporterId: reporterId,
        targetId: user.uid,
        targetType: 'user',
        targetOwnerId: user.uid,
        reason: text.isEmpty ? 'Not specified' : text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $e')),
      );
    }
  }

  Future<void> _changeProfilePicture(UserModel user) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _isUpdatingAvatar = true;
      });

      final String? oldUrl = user.avatarUrl;
      final file = File(picked.path);
      final newUrl = await _storageService.uploadProfileImage(user.uid, file);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'avatarUrl': newUrl});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_avatar', newUrl);

      await _updateUserAvatarInPosts(user.uid, newUrl, user.name);

      if (oldUrl != null && oldUrl.isNotEmpty && oldUrl != newUrl) {
        try {
          await _storageService.deleteProfileImage(oldUrl);
        } catch (_) {}
      }

      if (!mounted) return;
      _refreshProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update picture: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  Future<void> _updateUserAvatarInPosts(String userId, String newUrl, String? name) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      WriteBatch batch = firestore.batch();
      int count = 0;

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'authorImage': newUrl,
          if (name != null && name.isNotEmpty) 'authorName': name,
        });
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = firestore.batch();
          count = 0;
        }
      }

      if (count > 0) {
        await batch.commit();
      }

      await FeedCacheService.instance.clearCache();
    } catch (_) {}
  }

  Widget _buildProfileHeader(UserModel user, bool isOwnProfile) {
    return Column(
      children: [
        // Avatar
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            _buildAvatar(user.avatarUrl ?? '', user.name ?? 'User', radius: 50),
            if (isOwnProfile)
              GestureDetector(
                onTap: _isUpdatingAvatar ? null : () => _changeProfilePicture(user),
                child: Container(
                  margin: const EdgeInsets.only(right: 4, bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.yellow, width: 1.5),
                  ),
                  child: _isUpdatingAvatar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.yellow,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: Colors.yellow,
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          user.name ?? 'User',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (user.semester != null) ...[
          const SizedBox(height: 4),
          Text(
            'Semester: ${user.semester}',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
        if (user.branch != null) ...[
          const SizedBox(height: 2),
          Text(
            user.branch!,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            // border: Border.all(
            //   color: Colors.yellow.withOpacity(0.4),
            //   width: 1.2,
            // ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.fire,
                color: Color.fromARGB(255, 255, 123, 0),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${user.hotCount} hots',
                style: GoogleFonts.poppins(
                  color: Colors.yellow,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Action Buttons
        if (!isOwnProfile)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final currentUserId = prefs.getString('current_user_uid') ?? '';
                  final currentUserName = prefs.getString('current_user_name') ?? 'User';
                  final currentUserImage = prefs.getString('current_user_avatar') ?? '';

                  if (currentUserId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please login to chat')),
                    );
                    return;
                  }

                  try {
                    final conversationId = await ChatService().getOrCreateConversation(
                      user1Id: currentUserId,
                      user1Name: currentUserName,
                      user1Image: currentUserImage,
                      user2Id: user.uid,
                      user2Name: user.name ?? 'User',
                      user2Image: user.avatarUrl ?? '',
                    );

                    if (!mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          conversationId: conversationId,
                          currentUserId: currentUserId,
                          currentUserName: currentUserName,
                          currentUserImage: currentUserImage,
                          otherUserId: user.uid,
                          otherUserName: user.name ?? 'User',
                          otherUserImage: user.avatarUrl ?? '',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to start chat: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  'Message',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showReportDialogForUser(user),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  'Report',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAvatar(String imageUrl, String userName, {double radius = 50}) {
    String initials() {
      final trimmed = userName.trim();
      if (trimmed.isEmpty) return '?';
      final parts = trimmed.split(RegExp(r'\s+'));
      final letters = parts
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase())
          .toList();
      if (letters.isEmpty) return '?';
      return letters.take(2).join();
    }

    Widget fallbackAvatar() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.yellow,
        ),
        alignment: Alignment.center,
        child: Text(
          initials(),
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

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[900],
        border: Border.all(color: Colors.yellow, width: 3),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallbackAvatar(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackAvatar();
          },
        ),
      ),
    );
  }

  Widget _buildPostsTab(UserModel user) {
    final authUserId = FirebaseAuth.instance.currentUser?.uid;
    final effectiveCurrentUserId = (_currentUserId != null && _currentUserId!.isNotEmpty)
        ? _currentUserId!
        : (authUserId ?? '');

    final stream = FirebaseFirestore.instance
        .collection('posts')
        .where('authorId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromMap(doc.data(), doc.id))
            .toList());

    return StreamBuilder<List<Post>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.yellow),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading posts',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.image,
                  color: Colors.grey,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              currentUserId: effectiveCurrentUserId,
              onDelete: _refreshProfile,
              onComment: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CommentsPage(
                    postId: post.id,
                    currentUserId: effectiveCurrentUserId,
                    currentUserName: user.name ?? 'User',
                    currentUserImage: user.avatarUrl ?? '',
                  ),
                ).then((_) => _refreshProfile());
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMentionsTab(UserModel user) {
    final mentionKey = '@${(user.name ?? 'User').replaceAll(' ', '_')}';

    final authUserId = FirebaseAuth.instance.currentUser?.uid;
    final effectiveCurrentUserId = (_currentUserId != null && _currentUserId!.isNotEmpty)
        ? _currentUserId!
        : (authUserId ?? '');

    final stream = FirebaseFirestore.instance
        .collection('posts')
        .where('mentions', arrayContains: mentionKey)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromMap(doc.data(), doc.id))
            .toList());

    return StreamBuilder<List<Post>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.yellow),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading mentions',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.at,
                  color: Colors.grey,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'No mentions yet',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Posts where you are mentioned will appear here',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              currentUserId: effectiveCurrentUserId,
              onDelete: _refreshProfile,
              onComment: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CommentsPage(
                    postId: post.id,
                    currentUserId: effectiveCurrentUserId,
                    currentUserName: user.name ?? 'User',
                    currentUserImage: user.avatarUrl ?? '',
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 14, 14, 14),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
