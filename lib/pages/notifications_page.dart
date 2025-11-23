import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'post_detail_page.dart';
import 'matches_page.dart';
import 'profile_page.dart';

class NotificationsPage extends StatefulWidget {
  final String currentUserId;

  const NotificationsPage({super.key, required this.currentUserId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    NotificationService().markAllAsRead(widget.currentUserId);
    _notificationsFuture = NotificationService()
        .getUserNotificationsOnce(widget.currentUserId, useCache: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: Colors.yellow,
        onRefresh: () async {
          final fresh = await NotificationService().getUserNotificationsOnce(
            widget.currentUserId,
            useCache: false,
          );
          if (!mounted) return;
          setState(() {
            _notificationsFuture = Future.value(fresh);
          });
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load notifications',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              );
            }

            final all = snapshot.data ?? <Map<String, dynamic>>[];
            final docs = all.where((data) {
              final type = (data['type'] as String?) ?? '';
              return type != 'chat';
            }).toList();

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'No notifications yet',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(
                color: Colors.white12,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final data = docs[index];

                final type = (data['type'] as String?) ?? '';
                final title = (data['title'] as String?) ?? '';
                final body = (data['body'] as String?) ?? '';
                final senderName = (data['senderName'] as String?) ?? '';
                final senderImage = (data['senderImage'] as String?) ?? '';
                final ts = data['timestamp'];
                final relatedId = data['relatedId'] as String?;
                final Map<String, dynamic> extraData =
                    (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};

              DateTime? timestamp;
              if (ts is Timestamp) {
                timestamp = ts.toDate();
              } else if (ts is DateTime) {
                timestamp = ts;
              }

                final timeText = timestamp != null
                    ? DateFormat('MMM d, h:mm a').format(timestamp)
                    : '';

                IconData icon;
                Color iconColor;

              switch (type) {
                case 'post_like':
                  icon = Icons.favorite;
                  iconColor = Colors.pinkAccent;
                  break;
                case 'comment':
                  icon = Icons.mode_comment_outlined;
                  iconColor = Colors.lightBlueAccent;
                  break;
                case 'tag':
                  icon = Icons.alternate_email;
                  iconColor = Colors.purpleAccent;
                  break;
                case 'match':
                  icon = Icons.local_fire_department;
                  iconColor = Colors.orangeAccent;
                  break;
                case 'hot_vote':
                  icon = Icons.local_fire_department;
                  iconColor = Colors.redAccent;
                  break;
                case 'chat':
                  icon = Icons.chat_bubble_outline;
                  iconColor = Colors.greenAccent;
                  break;
                case 'engagement':
                  icon = Icons.notifications_active_outlined;
                  iconColor = Colors.amberAccent;
                  break;
                default:
                  icon = Icons.notifications_none;
                  iconColor = Colors.white70;
              }

                return ListTile(
                  onTap: () {
                    // Navigate based on notification type
                    if (type == 'post_like' || type == 'comment' || type == 'tag') {
                      final postId =
                          extraData['postId'] as String? ?? relatedId ?? '';
                      if (postId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailPage(postId: postId),
                          ),
                        );
                      }
                    } else if (type == 'match') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MatchesPage(),
                        ),
                      );
                    } else if (type == 'hot_vote') {
                      final voterId =
                          extraData['voterId'] as String? ?? relatedId ?? '';
                      if (voterId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: voterId),
                          ),
                        );
                      }
                    }
                  },
                  leading: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage:
                          senderImage.isNotEmpty ? NetworkImage(senderImage) : null,
                      child: senderImage.isEmpty
                          ? Text(
                              senderName.isNotEmpty
                                  ? senderName[0].toUpperCase()
                                  : 'B',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.black,
                      child: Icon(
                        icon,
                        size: 14,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
                title: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    if (timeText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
