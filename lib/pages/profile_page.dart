import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'comments_page.dart';

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
  final PostService _postService = PostService();
  late TabController _tabController;
  late Future<UserModel?> _userFuture;
  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userFuture = _authService.getUserProfile(widget.userId);
    _postsFuture = _postService.getUserPosts(widget.userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {
      _userFuture = _authService.getUserProfile(widget.userId);
      _postsFuture = _postService.getUserPosts(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser?.uid;

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
                  expandedHeight: 280,
                  floating: false,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (isOwnProfile)
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          // TODO: Navigate to settings
                        },
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
                        _buildProfileHeader(user),
                      ],
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
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(
                          icon: const FaIcon(FontAwesomeIcons.tableCells, size: 18),
                          text: 'Posts',
                        ),
                        Tab(
                          icon: const FaIcon(FontAwesomeIcons.heart, size: 18),
                          text: 'Liked',
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
                _buildLikedTab(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        // Avatar
        _buildAvatar(user.avatarUrl ?? '', user.name ?? 'User', radius: 50),
        const SizedBox(height: 16),
        // Name
        Text(
          user.name ?? 'User',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        // Email
        Text(
          user.email,
          style: GoogleFonts.poppins(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        if (user.rollNo != null) ...[
          const SizedBox(height: 4),
          Text(
            'Roll No: ${user.rollNo}',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 12,
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
        const SizedBox(height: 16),
        // Edit Profile Button
        if (isOwnProfile)
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to edit profile
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String imageUrl, String userName, {double radius = 50}) {
    String _initials() {
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
    return FutureBuilder<List<Post>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.yellow),
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
            return PostCard(
              post: posts[index],
              currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
              onDelete: _refreshProfile,
              onComment: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommentsPage(
                      postId: posts[index].id,
                      currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      currentUserName: user.name ?? 'User',
                      currentUserImage: user.avatarUrl ?? '',
                    ),
                  ),
                ).then((_) => _refreshProfile());
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLikedTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.heart,
            color: Colors.grey,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Liked posts coming soon',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
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
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
