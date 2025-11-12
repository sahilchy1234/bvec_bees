import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../pages/comments_page.dart';
import '../pages/profile_page.dart';

class TrendingPage extends StatefulWidget {
  final String? hashtag;

  const TrendingPage({super.key, this.hashtag});

  @override
  State<TrendingPage> createState() => _TrendingPageState();
}

class _TrendingPageState extends State<TrendingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _currentUserId = '';
  String _currentUserName = 'User';
  String _currentUserImage = '';
  String? _selectedHashtag;
  List<String> _trendingHashtags = [];
  bool _isLoadingHashtags = true;

  @override
  void initState() {
    super.initState();
    _selectedHashtag = widget.hashtag;
    _loadCurrentUser();
    _loadTrendingHashtags();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('current_user_uid') ?? '';
      _currentUserName = prefs.getString('current_user_name') ?? 'User';
      _currentUserImage = prefs.getString('current_user_avatar') ?? '';
    });
  }

  Future<void> _loadTrendingHashtags() async {
    setState(() => _isLoadingHashtags = true);
    try {
      final postsSnapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final hashtagCounts = <String, int>{};
      for (final doc in postsSnapshot.docs) {
        final hashtags = List<String>.from(doc.data()['hashtags'] ?? []);
        for (final tag in hashtags) {
          hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
        }
      }

      final sorted = hashtagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _trendingHashtags = sorted.take(20).map((e) => e.key).toList();
        _isLoadingHashtags = false;
      });
    } catch (e) {
      setState(() => _isLoadingHashtags = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trending: $e')),
        );
      }
    }
  }

  Stream<List<Post>> _streamPostsByHashtag(String hashtag) {
    return _firestore
        .collection('posts')
        .where('hashtags', arrayContains: hashtag)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Post.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedHashtag ?? 'Trending',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Trending hashtags horizontal list
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _isLoadingHashtags
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.yellow),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _trendingHashtags.length,
                    itemBuilder: (context, index) {
                      final tag = _trendingHashtags[index];
                      final isSelected = tag == _selectedHashtag;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedHashtag = tag;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.yellow
                                : Colors.grey[900],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.yellow
                                  : Colors.grey[800]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(color: Colors.grey, height: 1),
          // Posts list
          Expanded(
            child: _selectedHashtag == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 64,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a hashtag to view posts',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<List<Post>>(
                    stream: _streamPostsByHashtag(_selectedHashtag!),
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
                              Icon(
                                Icons.post_add,
                                size: 64,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No posts with $_selectedHashtag',
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
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return PostCard(
                            post: post,
                            currentUserId: _currentUserId,
                            onDelete: () {
                              setState(() {});
                            },
                            onComment: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommentsPage(
                                    postId: post.id,
                                    currentUserId: _currentUserId,
                                    currentUserName: _currentUserName,
                                    currentUserImage: _currentUserImage,
                                  ),
                                ),
                              );
                            },
                            onAuthorTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfilePage(
                                    userId: post.authorId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
