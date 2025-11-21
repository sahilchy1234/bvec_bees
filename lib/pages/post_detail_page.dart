import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';
import 'comments_page.dart';
import 'profile_page.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  late Future<Post?> _postFuture;

  String _currentUserId = '';
  String _currentUserName = 'User';
  String _currentUserImage = '';
  String _currentUserEmail = '';

  @override
  void initState() {
    super.initState();
    _postFuture = _postService.getPost(widget.postId);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserId = prefs.getString('current_user_uid') ?? '';
      _currentUserName = prefs.getString('current_user_name') ?? 'User';
      _currentUserImage = prefs.getString('current_user_avatar') ?? '';
      _currentUserEmail = prefs.getString('current_user_email') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 10, 10),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 14, 14, 14),
        foregroundColor: Colors.white,
        title: const Text('Post'),
      ),
      body: FutureBuilder<Post?>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading post: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final post = snapshot.data;
          if (post == null) {
            return const Center(
              child: Text(
                'Post not found',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            );
          }

          return SingleChildScrollView(
            child: PostCard(
              post: post,
              currentUserId: _currentUserId,
              onDelete: () {
                Navigator.of(context).pop();
              },
              onComment: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CommentsPage(
                    postId: post.id,
                    currentUserId: _currentUserId,
                    currentUserName: _currentUserName,
                    currentUserImage: _currentUserImage,
                  ),
                );
              },
              onAuthorTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: post.authorId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
