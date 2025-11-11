import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';
import 'create_post_page.dart';
import 'comments_page.dart';
import 'profile_page.dart';

class FeedPage extends StatefulWidget {
  final ScrollController scrollController;
  final String currentUserId;
  final String currentUserName;
  final String currentUserImage;
  final String currentUserEmail;
  final VoidCallback onRefreshUser;

  const FeedPage({
    super.key,
    required this.scrollController,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserImage,
    required this.currentUserEmail,
    required this.onRefreshUser,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostService _postService = PostService();
  late Future<List<Post>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = _postService.getFeed();
    
    // Debug: Print user data
    print('=== FeedPage User Data ===');
    print('User ID: ${widget.currentUserId}');
    print('User Name: ${widget.currentUserName}');
    print('User Image: ${widget.currentUserImage}');
    print('User Email: ${widget.currentUserEmail}');
    print('========================');
  }

  void _refreshFeed() {
    setState(() {
      _feedFuture = _postService.getFeed();
    });
    widget.onRefreshUser();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 100, top: 12, left: 0, right: 0),
      children: [
        // Create post section
        _buildCreatePostSection(),
        const Divider(color: Colors.grey, height: 1),
        // Feed
        FutureBuilder<List<Post>>(
          future: _feedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Colors.blue),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Error loading feed: ${snapshot.error}',
                    style: GoogleFonts.poppins(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No posts yet. Be the first to post!',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return PostCard(
                  post: posts[index],
                  currentUserId: widget.currentUserId,
                  onDelete: _refreshFeed,
                  onComment: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => CommentsPage(
                        postId: posts[index].id,
                        currentUserId: widget.currentUserId,
                        currentUserName: widget.currentUserName,
                        currentUserImage: widget.currentUserImage,
                      ),
                    );
                  },
                  onAuthorTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userId: posts[index].authorId),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreatePostSection() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // User avatar and input
          Row(
            children: [
              _buildUserAvatar(
                widget.currentUserImage,
                widget.currentUserName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePostPage(
                          userId: widget.currentUserId,
                          userName: widget.currentUserName,
                          userImage: widget.currentUserImage,
                        ),
                      ),
                    ).then((_) => _refreshFeed());
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.yellow.withOpacity(0.3), width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      "What's on your mind?",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: FontAwesomeIcons.image,
                label: 'Photo',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePostPage(
                        userId: widget.currentUserId,
                        userName: widget.currentUserName,
                        userImage: widget.currentUserImage,
                      ),
                    ),
                  ).then((_) => _refreshFeed());
                },
              ),
              _buildActionButton(
                icon: FontAwesomeIcons.pen,
                label: 'Text',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePostPage(
                        userId: widget.currentUserId,
                        userName: widget.currentUserName,
                        userImage: widget.currentUserImage,
                      ),
                    ),
                  ).then((_) => _refreshFeed());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.yellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.yellow.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              color: Colors.yellow,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.yellow,
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
    final double size = radius * 2;

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
      return Container(
        width: size,
        height: size,
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
            fontSize: radius,
          ),
        ),
      );
    }

    if (imageUrl.isEmpty) {
      return fallbackAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[900],
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
}
