import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/user_directory_cache_service.dart';
import 'profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  List<String> _recentSearches = [];
  Timer? _debounce;
  static const int _maxRecentSearches = 8;
  List<UserModel> _allVerifiedUsers = [];
  bool _usersLoaded = false;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('recent_user_searches') ?? [];
    if (!mounted) return;
    setState(() {
      _recentSearches = saved;
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(
      prefs.getStringList('recent_user_searches') ?? <String>[],
    );

    current.removeWhere(
      (item) => item.toLowerCase() == trimmed.toLowerCase(),
    );
    current.insert(0, trimmed);
    if (current.length > _maxRecentSearches) {
      current.removeRange(_maxRecentSearches, current.length);
    }

    await prefs.setStringList('recent_user_searches', current);
    if (!mounted) return;
    setState(() {
      _recentSearches = current;
    });
  }

  Future<void> _ensureUsersLoaded() async {
    if (_usersLoaded || _isLoadingUsers) return;
    _isLoadingUsers = true;
    try {
      // Try cached users first
      final cached = await UserDirectoryCacheService.instance.getCachedUsers();
      if (cached != null && cached.isNotEmpty) {
        _allVerifiedUsers = cached;
        _usersLoaded = true;
        return;
      }

      // Fallback: load from Firestore once
      final snapshot = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .get();

      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return UserModel.fromMap(data);
      }).toList();

      _allVerifiedUsers = users;
      _usersLoaded = true;
      // Cache for reuse across app sessions
      await UserDirectoryCacheService.instance.cacheUsers(users);
    } finally {
      _isLoadingUsers = false;
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final queryLower = query.toLowerCase().trim();

      // Fetch verified users and filter client-side for a true case-insensitive
      // search on both name and roll number. This avoids issues with
      // capitalization and ensures all matching profiles can be found.
      await _ensureUsersLoaded();

      final users = _allVerifiedUsers.where((user) {
        final name = (user.name ?? '').toLowerCase();
        final roll = (user.rollNo ?? '').toLowerCase();
        final nameMatches = queryLower.length >= 3
            ? name.contains(queryLower)
            : name.startsWith(queryLower);
        final rollMatches = roll.startsWith(queryLower);
        return nameMatches || rollMatches;
      }).toList();

      setState(() {
        _searchResults = users;
        _isSearching = false;
      });

      await _saveRecentSearch(query);
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Widget _buildUserAvatar(String imageUrl, String userName, {double radius = 24}) {
    if (imageUrl.isEmpty) {
      final initials = userName
          .split(' ')
          .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
          .join()
          .substring(0, 1);

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.yellow,
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[900],
      backgroundImage: NetworkImage(imageUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  Widget _buildRecentSearchesSection() {
    if (_recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Recent searches',
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentSearches.map((term) {
            return ActionChip(
              label: Text(
                term,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              backgroundColor: Colors.grey[900],
              onPressed: () {
                _searchController.text = term;
                setState(() {});
                _performSearch(term);
              },
            );
          }).toList(),
        ),
      ],
    );
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
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search users by name or roll number...',
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _performSearch,
        ),
      ),
      body: _isSearching
          ? const Center(
              child: CircularProgressIndicator(color: Colors.yellow),
            )
          : _hasSearched && _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : !_hasSearched
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Search for users',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter a name or roll number to start',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            _buildRecentSearchesSection(),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(userId: user.uid),
                              ),
                            );
                          },
                          leading: _buildUserAvatar(
                            user.avatarUrl ?? '',
                            user.name ?? 'User',
                          ),
                          title: Text(
                            user.name ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: user.rollNo != null
                              ? Text(
                                  user.rollNo!,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                        );
                      },
                    ),
    );
  }
}
