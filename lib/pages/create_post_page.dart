import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/post_service.dart';
import '../models/user_model.dart';

class CreatePostPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userImage;

  const CreatePostPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userImage,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final LayerLink _mentionLayerLink = LayerLink();
  final GlobalKey _contentFieldKey = GlobalKey();
  final List<File> _selectedImages = [];
  final PostService _postService = PostService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  double _imageAlignmentY = 0.0;
  
  final ImagePicker _imagePicker = ImagePicker();
  
  // Mention autocomplete
  OverlayEntry? _mentionOverlay;
  List<UserModel> _mentionSuggestions = [];
  final bool _showMentionSuggestions = false;
  String _currentMentionQuery = '';

  @override
  void initState() {
    super.initState();
    
    // Debug: Print user data
    print('=== CreatePostPage User Data ===');
    print('User ID: ${widget.userId}');
    print('User Name: ${widget.userName}');
    print('User Image: ${widget.userImage}');
    print('================================');
    
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onTextChanged);
    _contentController.dispose();
    _removeMentionOverlay();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#\w+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@\w+');
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
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

  void _onTextChanged() {
    final text = _contentController.text;
    final cursorPos = _contentController.selection.baseOffset;
    
    if (cursorPos < 0) return;
    
    // Find if cursor is after @
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
      if (query.isNotEmpty) {
        debugPrint('[CreatePost] Mention query: "$query"');
        _searchUsers(query);
      } else {
        _removeMentionOverlay();
      }
    } else {
      _removeMentionOverlay();
    }
  }
  
  Future<void> _searchUsers(String query) async {
    try {
      debugPrint('[CreatePost] Searching users for "$query"');
      final snapshot = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .limit(10)
          .get();
      
      final q = query.toLowerCase();
      final users = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['uid'] = doc.id;
            return UserModel.fromMap(data);
          })
          .where((user) {
            final name = (user.name ?? '').toLowerCase();
            final roll = (user.rollNo ?? '').toLowerCase();
            final nameMatches = q.length >= 3 ? name.contains(q) : name.startsWith(q);
            final rollMatches = roll.startsWith(q);
            return nameMatches || rollMatches;
          })
          .toList();
      
      debugPrint('[CreatePost] Found ${users.length} user(s) for "$query"');
      if (users.isNotEmpty) {
        setState(() {
          _mentionSuggestions = users;
          _currentMentionQuery = query;
        });
        debugPrint('[CreatePost] Showing mention overlay with ${users.length} suggestion(s)');
        _showMentionOverlay();
      } else {
        debugPrint('[CreatePost] No users found for "$query"; removing overlay');
        _removeMentionOverlay();
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }
  
  void _showMentionOverlay() {
    _removeMentionOverlay(clearSuggestions: false);
    final renderBox = _contentFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true);

    if (renderBox == null) {
      debugPrint('[CreatePost] Unable to create overlay: renderBox or overlay missing');
      return;
    }

    final size = renderBox.size;
    debugPrint('[CreatePost] Creating overlay. TextField size: $size');
    _mentionOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: CompositedTransformFollower(
          link: _mentionLayerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 8),
          child: Material(
            color: Colors.transparent,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: size.width,
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.yellow.withOpacity(0.3)),
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
                        radius: 20,
                        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        backgroundColor: Colors.yellow,
                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? Text(
                                (user.name ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user.name ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _mentionTokenFor(user),
                        style: GoogleFonts.poppins(
                          color: Colors.yellow,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: user.rollNo != null && user.rollNo!.isNotEmpty
                          ? Text(
                              user.rollNo!,
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      onTap: () => _insertMention(user),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_mentionOverlay!);
  }
  
  void _insertMention(UserModel user) {
    final text = _contentController.text;
    final cursorPos = _contentController.selection.baseOffset;
    
    // Find @ position
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
      
      _contentController.text = '$before$mention $after';
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: before.length + mention.length + 1),
      );
      debugPrint('[CreatePost] Inserted mention "$mention"');
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
    debugPrint('[CreatePost] Mention overlay removed');
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add text or images')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hashtags = _extractHashtags(_contentController.text);
      final mentions = _extractMentions(_contentController.text);

      await _postService.createPost(
        authorId: widget.userId,
        authorName: widget.userName,
        authorImage: widget.userImage,
        content: _contentController.text.trim(),
        imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        hashtags: hashtags,
        mentions: mentions,
        imageAlignmentY: _imageAlignmentY,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Create Post',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                disabledBackgroundColor: Colors.yellow.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Text(
                      'Post',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(widget.userImage),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Public',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CompositedTransformTarget(
                link: _mentionLayerLink,
                child: Container(
                  key: _contentFieldKey,
                  child: TextField(
                    controller: _contentController,
                    maxLines: 6,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
            ),
            // Selected images preview
            if (_selectedImages.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feed preview',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          // Adjust alignment based on drag; clamp to [-1, 1]
                          // Reverse direction: dragging down moves image the opposite way
                          final next = _imageAlignmentY - details.delta.dy / 150;
                          _imageAlignmentY = next.clamp(-1.0, 1.0);
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 300,
                          child: Image.file(
                            _selectedImages.first,
                            fit: BoxFit.cover,
                            alignment: Alignment(0, _imageAlignmentY),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const Divider(color: Colors.grey, height: 1),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: FontAwesomeIcons.image,
                    label: 'Photo',
                    onTap: _pickImage,
                  ),
                  _buildActionButton(
                    icon: FontAwesomeIcons.pen,
                    label: 'Text',
                    onTap: () {
                      // Text is already in the input field
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.yellow,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
