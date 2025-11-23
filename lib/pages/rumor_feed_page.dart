import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../models/rumor_model.dart';
import '../services/rumor_service.dart';
import '../services/auth_service.dart';
import '../services/rumor_performance_service.dart';
import '../widgets/rumor_card.dart';
import 'rumor_discussion_page.dart';

class RumorFeedPage extends StatefulWidget {
  final ScrollController scrollController;

  const RumorFeedPage({
    super.key,
    required this.scrollController,
  });

  @override
  State<RumorFeedPage> createState() => _RumorFeedPageState();
}

class _RumorFeedPageState extends State<RumorFeedPage> {
  final RumorService _rumorService = RumorService();
  final AuthService _authService = AuthService();
  final RumorPerformanceService _performanceService = RumorPerformanceService.instance;
  late String _currentUserId;
  final TextEditingController _rumorController = TextEditingController();
  bool _isCreatingRumor = false;
  bool _isLoading = true;
  
  // Pagination and performance optimization
  final List<RumorModel> _rumors = [];
  bool _hasMore = true;
  String? _lastRumorId;
  bool _isLoadingMore = false;
  final bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _preloadTimer;
  String? _error;
  
  // Memory management
  static const int _maxCachedRumors = 200;
  static const int _preloadThreshold = 10; // Start preloading when 10 items left

  @override
  void initState() {
    super.initState();
    _performanceService.initialize();
    _loadCurrentUserId();
    _scrollController.addListener(_onScroll);
    _performanceService.optimizeScrollPerformance(_scrollController);
  }
  
  @override
  void dispose() {
    _rumorController.dispose();
    _scrollController.dispose();
    _preloadTimer?.cancel();
    _rumorService.dispose();
    _performanceService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = maxScroll - currentScroll;
    
    // Start preloading when user is within 500px of bottom
    if (delta < 500 && _hasMore && !_isLoadingMore) {
      _loadMoreRumors();
    }
    
    // Memory management: remove old rumors when list gets too large
    if (_rumors.length > _maxCachedRumors) {
      setState(() {
        _rumors.removeRange(100, _rumors.length);
      });
    }
  }

  Future<void> _shareRumor(RumorModel rumor) async {
    final rumorId = rumor.id;
    final shareUrl = 'https://link.getbeezy.app/rumor/$rumorId';

    try {
      final message = 'Check out this rumor on Beezy:\n$shareUrl';

      await Share.share(
        message,
        subject: 'Beezy rumor',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing rumor: $e')),
      );
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('current_user_uid');
      
      if (uid != null && uid.isNotEmpty) {
        setState(() {
          _currentUserId = uid;
          _isLoading = false;
        });
        await _loadInitialRumors();
      } else {
        setState(() {
          _currentUserId = 'anonymous';
          _isLoading = false;
        });
        await _loadInitialRumors();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialRumors() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _performanceService.executeWithConnectionPool(
        () => _rumorService.getRumorsPaginated(limit: 20),
      );
      
      if (mounted) {
        setState(() {
          _rumors.clear();
          _rumors.addAll(result.rumors);
          _lastRumorId = result.lastRumorId;
          _hasMore = result.hasMore;
          _isLoading = false;
        });
        
        // Track access for performance optimization
        for (final rumor in result.rumors) {
          _performanceService.trackRumorAccess(rumor.id);
        }
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

  Future<void> _loadMoreRumors() async {
    if (_isLoadingMore || !_hasMore || _lastRumorId == null) return;

    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final result = await _performanceService.executeWithConnectionPool(
        () => _rumorService.getRumorsPaginated(
          limit: 20,
          startAfterId: _lastRumorId,
        ),
      );
      
      if (mounted) {
        setState(() {
          _rumors.addAll(result.rumors);
          _lastRumorId = result.lastRumorId;
          _hasMore = result.hasMore;
          _isLoadingMore = false;
        });
        
        // Track access for performance optimization
        for (final rumor in result.rumors) {
          _performanceService.trackRumorAccess(rumor.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
      print('Error loading more rumors: $e');
    }
  }

  Future<void> _refreshRumors() async {
    await _rumorService.refreshCache();
    _lastRumorId = null;
    _hasMore = true;
    await _loadInitialRumors();
  }

  Future<void> _createRumor() async {
    if (_rumorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rumor')),
      );
      return;
    }

    setState(() {
      _isCreatingRumor = true;
    });

    try {
      await _rumorService.createRumor(_rumorController.text);
      _rumorController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rumor posted anonymously!')),
        );
        // Refresh the feed to show the new rumor
        _refreshRumors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRumor = false;
        });
      }
    }
  }

  void _showCreateRumorDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.fire,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Spill the Tea ☕',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Share your rumor anonymously',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rumorController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'What\'s the rumor?',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.amber.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.amber.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.amber, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: Colors.grey[850],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isCreatingRumor ? null : _createRumor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      disabledBackgroundColor: Colors.grey[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isCreatingRumor
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _rumorController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 10, 10),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
                  color: const Color.fromARGB(255, 14, 14, 14), // header background color

              child: const Text(
                'Rumors',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshRumors,
              color: Colors.amber,
              child: _isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        ),
                      ],
                    )
                  : (_rumors.isEmpty && !_isLoadingMore)
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const FaIcon(
                                      FontAwesomeIcons.userSecret,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'No rumors yet',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first to spill the tea! 🔥',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                    onPressed: _showCreateRumorDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FaIcon(
                                          FontAwesomeIcons.fire,
                                          color: Colors.black,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Rumor',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 100, top: 12),
                          itemCount: _rumors.length + 1, // +1 for loader
                          itemBuilder: (context, index) {
                            if (index == _rumors.length && _hasMore) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const CircularProgressIndicator(color: Colors.amber)
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }

                            if (index >= _rumors.length) {
                              return const SizedBox.shrink();
                            }

                            final rumor = _rumors[index];
                            return RumorCard(
                              key: ValueKey(rumor.id),
                              rumor: rumor,
                              currentUserId: _currentUserId,
                              onVoteYes: () async {
                                try {
                                  await _rumorService.voteOnRumor(
                                    rumor.id,
                                    _currentUserId,
                                    true,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              onVoteNo: () async {
                                try {
                                  await _rumorService.voteOnRumor(
                                    rumor.id,
                                    _currentUserId,
                                    false,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              onComment: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RumorDiscussionPage(rumor: rumor),
                                  ),
                                );
                              },
                              onShare: () => _shareRumor(rumor),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRumorDialog,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color.fromARGB(255, 255, 213, 0)),
            borderRadius: BorderRadius.all(Radius.circular(16)),

        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        elevation: 8,
        child: const FaIcon(
          FontAwesomeIcons.pen,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
