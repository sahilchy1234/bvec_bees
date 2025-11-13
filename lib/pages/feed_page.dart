import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:characters/characters.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/feed_cache_service.dart';
import '../widgets/post_card.dart';
import '../widgets/cached_network_image_widget.dart';
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

class _FeedPageState extends State<FeedPage> with AutomaticKeepAliveClientMixin<FeedPage> {
  final PostService _postService = PostService();
  final FeedCacheService _cacheService = FeedCacheService.instance;
  final List<Post> _posts = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialFeed();
    
    // Debug: Print user data
    print('=== FeedPage User Data ===');
    print('User ID: ${widget.currentUserId}');
    print('User Name: ${widget.currentUserName}');
    print('User Image: ${widget.currentUserImage}');
    print('User Email: ${widget.currentUserEmail}');
    print('========================');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadInitialFeed() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _postService.getFeedPaginated(limit: 10, useCache: true);
      
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(result.posts);
          _lastDocument = result.lastDocument;
          _hasMore = result.hasMore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final result = await _postService.getFeedPaginated(
        limit: 10,
        startAfter: _lastDocument,
        useCache: false,
      );
      
      if (mounted) {
        setState(() {
          _posts.addAll(result.posts);
          _lastDocument = result.lastDocument;
          _hasMore = result.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
      print('Error loading more posts: $e');
    }
  }

  Future<void> _refreshFeed() async {
    // Clear cache and reload
    await _cacheService.clearCache();
    _lastDocument = null;
    _hasMore = true;
    await _loadInitialFeed();
    widget.onRefreshUser();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveStateMixin
    
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: Colors.yellow,
      backgroundColor: Colors.grey[900],
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Create post section as sliver
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildCreatePostSection(),
                const Divider(color: Colors.grey, height: 1),
              ],
            ),
          ),
          
          // Feed content
          if (_isLoading && _posts.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              ),
            )
          else if (_error != null && _posts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error loading feed',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshFeed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_posts.isEmpty)
            SliverFillRemaining(
              child: Center(
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
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index < _posts.length) {
                    return PostCard(
                      key: ValueKey(_posts[index].id), // Add key for better performance
                      post: _posts[index],
                      currentUserId: widget.currentUserId,
                      onDelete: _refreshFeed,
                      onComment: () {
                        showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => CommentsPage(
                            postId: _posts[index].id,
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
                            builder: (_) => ProfilePage(userId: _posts[index].authorId),
                          ),
                        );
                      },
                    );
                  } else if (_isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.yellow,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  } else if (!_hasMore) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'You\'ve reached the end of the feed!',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
                childCount: _posts.length + (_isLoadingMore || !_hasMore ? 1 : 0),
              ),
            ),
          
          // Bottom padding
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 100),
          ),
        ],
      ),
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
    return CachedCircleAvatar(
      imageUrl: imageUrl,
      displayName: userName,
      radius: radius,
      backgroundColor: Colors.yellow,
      textColor: Colors.black,
    );
  }
}
