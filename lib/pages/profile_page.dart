import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../services/hot_not_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/avatar_crop_page.dart';
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
  final HotNotService _hotNotService = HotNotService();
  late TabController _tabController;
  late Future<UserModel?> _userFuture;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImage;
  bool _isUpdatingAvatar = false;
  bool _isHottingProfile = false;
  bool _hasHottedProfile = false;
  bool _hasLoadedHottedState = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userFuture = _authService.getUserProfile(widget.userId);
    _loadCurrentUserId();
  }

  Future<void> _showAvatarPreview(String imageUrl, String userName) async {
    if (imageUrl.isEmpty) return;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Profile picture',
        barrierColor: Colors.black.withOpacity(0.9),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              color: Colors.black,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildAvatar('', userName, radius: 80),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(color: Colors.grey[300]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      // Ignore preview errors; not critical for core flow.
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    setState(() {
      _userFuture = _authService.getUserProfile(widget.userId);
      // When refreshing the profile, reload hotted state next time it is needed
      _hasLoadedHottedState = false;
    });
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('current_user_uid');
    final storedName = prefs.getString('current_user_name');
    final storedImage = prefs.getString('current_user_avatar');

    if (!mounted) return;

    setState(() {
      _currentUserId = (storedId != null && storedId.isNotEmpty)
          ? storedId
          : FirebaseAuth.instance.currentUser?.uid;
      _currentUserName = storedName ?? 'User';
      _currentUserImage = storedImage ?? '';
    });
  }

  Future<void> _ensureHottedStateLoaded(String targetUserId) async {
    if (_hasLoadedHottedState) return;

    final voterId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (voterId == null || voterId.isEmpty) return;

    _hasLoadedHottedState = true;

    try {
      final voteId = '${voterId}_$targetUserId';
      final doc = await FirebaseFirestore.instance
          .collection('votes')
          .doc(voteId)
          .get();

      if (!mounted) return;

      final isHot = doc.exists && (doc.data()?['isHot'] == true);
      setState(() {
        _hasHottedProfile = isHot;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasHottedProfile = false;
      });
    }
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

          final hasBioForActions = (user.bio ?? '').trim().isNotEmpty;

          // For other users' profiles, lazily load whether current user has already hotted them
          if (!isOwnProfile) {
            _ensureHottedStateLoaded(user.uid);
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: Colors.black,
                  floating: false,
                  pinned: true,
                  // leading: IconButton(
                  //   icon: const Icon(Icons.arrow_back, color: Colors.white),
                  //   onPressed: () => Navigator.pop(context),
                  // ),
                  actions: isOwnProfile
                      ? [
                          if (hasBioForActions)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.yellow),
                              tooltip: 'Edit profile',
                              onPressed: () => _showEditProfileDialog(user),
                            ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.redAccent),
                            tooltip: 'Log out',
                            onPressed: _logoutFromProfile,
                          ),
                        ]
                      : const [],
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildProfileHeader(user, isOwnProfile),
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

  Future<void> _logoutFromProfile() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('pending_verification', false);
    await prefs.setBool('isSuspended', false);

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _showEditProfileDialog(UserModel user) async {
    final hometownController =
        TextEditingController(text: user.hometown ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');
    final interestsController =
        TextEditingController(text: user.interests ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Colors.yellow,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit profile',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Share a bit more so people can get to know you.',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hometownController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Hometown',
                    hintText: 'e.g. Mumbai, Pune',
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: Colors.yellow,
                      size: 18,
                    ),
                    labelStyle:
                        GoogleFonts.poppins(color: Colors.grey[400]),
                    hintStyle:
                        GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    hintText: 'A short line about you',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.yellow,
                      size: 18,
                    ),
                    labelStyle:
                        GoogleFonts.poppins(color: Colors.grey[400]),
                    hintStyle:
                        GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interestsController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Interests',
                    hintText: 'music, football, coding',
                    prefixIcon: const Icon(
                      Icons.star_border,
                      color: Colors.yellow,
                      size: 18,
                    ),
                    labelStyle:
                        GoogleFonts.poppins(color: Colors.grey[400]),
                    hintStyle:
                        GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
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
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final hometown = hometownController.text.trim();
    final bio = bioController.text.trim();
    final interests = interestsController.text.trim();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'hometown': hometown,
        'bio': bio,
        'interests': interests,
      });

      if (!mounted) return;
      _refreshProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')), 
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
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
      File file = File(picked.path);

      // Open custom in-app avatar cropper
      final croppedFile = await Navigator.of(context).push<File?>(
        MaterialPageRoute(
          builder: (_) => AvatarCropPage(imageFile: file),
        ),
      );

      if (croppedFile == null) {
        if (mounted) {
          setState(() {
            _isUpdatingAvatar = false;
          });
        }
        return;
      }

      file = croppedFile;

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
    final bioText = (user.bio ?? '').trim();
    final hasBio = bioText.isNotEmpty;
    final rawInterests = user.interests ?? '';
    final interestItems = rawInterests
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      children: [
        // Avatar with single-tap preview
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () async {
                try {
                  await HapticFeedback.mediumImpact();
                } catch (_) {}
                if (!mounted) return;
                await _showAvatarPreview(
                  user.avatarUrl ?? '',
                  user.name ?? 'User',
                );
              },
              child:
                  _buildAvatar(user.avatarUrl ?? '', user.name ?? 'User', radius: 50),
            ),
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
        // Extra info: hometown, bio, interests (only show if set)
        if ((user.hometown ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    user.hometown!,
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (hasBio)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              bioText,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (interestItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final interest in interestItems)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.yellow.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      interest,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Only show inline Add bio button when there is no bio yet
        if (isOwnProfile && !hasBio)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: () => _showEditProfileDialog(user),
              icon: const Icon(
                Icons.add,
                color: Colors.yellow,
                size: 18,
              ),
              label: Text(
                'Add bio',
                style: GoogleFonts.poppins(
                  color: Colors.yellow,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Hot / Unhot profile button
              ElevatedButton.icon(
                onPressed: _isHottingProfile
                    ? null
                    : () async {
                        final prefs = await SharedPreferences.getInstance();
                        final currentUserId =
                            prefs.getString('current_user_uid') ?? '';

                        if (currentUserId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please login to hot profiles')),
                          );
                          return;
                        }

                        if (mounted) {
                          setState(() {
                            _isHottingProfile = true;
                          });
                        } else {
                          _isHottingProfile = true;
                        }

                        final bool wasHotted = _hasHottedProfile;

                        try {
                          if (!wasHotted) {
                            // Hot the profile
                            final isMatch = await _hotNotService.castVote(
                              voterId: currentUserId,
                              targetId: user.uid,
                              isHot: true,
                            );

                            if (!mounted) return;
                            setState(() {
                              _hasHottedProfile = true;
                            });
                            _refreshProfile();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isMatch
                                      ? 'It\'s a match! You both hotted each other.'
                                      : 'You hotted this profile.',
                                ),
                              ),
                            );
                          } else {
                            // Unhot the profile
                            await _hotNotService.unhotUser(
                              voterId: currentUserId,
                              targetId: user.uid,
                            );

                            if (!mounted) return;
                            setState(() {
                              _hasHottedProfile = false;
                            });
                            _refreshProfile();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('You unhot this profile.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to update hot: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isHottingProfile = false;
                            });
                          } else {
                            _isHottingProfile = false;
                          }
                        }
                      },
                icon: _isHottingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(
                        FontAwesomeIcons.fire,
                        size: 16,
                      ),
                label: Text(
                  _hasHottedProfile ? 'Unhot' : 'Hot',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _hasHottedProfile ? Colors.grey[900] : Colors.black,
                  foregroundColor: _hasHottedProfile
                      ? Colors.grey[300]
                      : const Color.fromARGB(255, 255, 123, 0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: _hasHottedProfile
                          ? Colors.grey.shade600
                          : const Color.fromARGB(255, 255, 123, 0),
                      width: 1.4,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              // Message button
              ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final currentUserId = prefs.getString('current_user_uid') ?? '';
                  final currentUserName =
                      prefs.getString('current_user_name') ?? 'User';
                  final currentUserImage =
                      prefs.getString('current_user_avatar') ?? '';

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
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
              // Report button
              OutlinedButton.icon(
                onPressed: () => _showReportDialogForUser(user),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(
                  'Report',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
              ),
            ],
          ),
        // Edit profile entry point now via pen icon in the app bar
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
    final effectiveCurrentUserName = _currentUserName ?? 'User';
    final effectiveCurrentUserImage = _currentUserImage ?? '';

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
                    currentUserName: effectiveCurrentUserName,
                    currentUserImage: effectiveCurrentUserImage,
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
    final effectiveCurrentUserName = _currentUserName ?? 'User';
    final effectiveCurrentUserImage = _currentUserImage ?? '';

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
                    currentUserName: effectiveCurrentUserName,
                    currentUserImage: effectiveCurrentUserImage,
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
