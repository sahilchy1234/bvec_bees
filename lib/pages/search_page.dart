import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      
      // Search by name (case-insensitive)
      final nameSnapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: queryLower)
          .where('name', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(20)
          .get();

      // Search by roll number
      final rollSnapshot = await _firestore
          .collection('users')
          .where('rollNo', isGreaterThanOrEqualTo: queryLower)
          .where('rollNo', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(20)
          .get();

      final userMap = <String, UserModel>{};

      for (final doc in nameSnapshot.docs) {
        final data = doc.data();
        data['uid'] = doc.id;
        final user = UserModel.fromMap(data);
        userMap[user.uid] = user;
      }

      for (final doc in rollSnapshot.docs) {
        final data = doc.data();
        data['uid'] = doc.id;
        final user = UserModel.fromMap(data);
        userMap[user.uid] = user;
      }

      setState(() {
        _searchResults = userMap.values.toList();
        _isSearching = false;
      });
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
          onChanged: (value) {
            setState(() {});
            _performSearch(value);
          },
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          ),
                        ],
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
