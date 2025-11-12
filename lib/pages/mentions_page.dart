import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../pages/comments_page.dart';
import '../pages/profile_page.dart';

class MentionsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const MentionsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<MentionsPage> createState() => _MentionsPageState();
}

class _MentionsPageState extends State<MentionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _currentUserId = '';
  String _currentUserName = 'User';
  String _currentUserImage = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('current_user_uid') ?? '';
      _currentUserName = prefs.getString('current_user_name') ?? 'User';
      _currentUserImage = prefs.getString('current_user_avatar') ?? '';
    });
  }

  Stream<List<Post>> _streamMentionedPosts() {
    // Create mention pattern with underscores
    final mentionPattern = '@${widget.userName.replaceAll(' ', '_')}';
    
    return _firestore
        .collection('posts')
        .where('mentions', arrayContains: mentionPattern)
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
          'Mentions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _streamMentionedPosts(),
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
                  Icon(
                    Icons.alternate_email,
                    size: 64,
                    color: Colors.grey[700],
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
                    'Posts where you\'re mentioned will appear here',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
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
    );
  }
}
