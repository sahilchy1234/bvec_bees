import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatelessWidget {
  final String currentUserId;

  const NotificationsPage({super.key, required this.currentUserId});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationService().getUserNotifications(currentUserId),
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
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

              final type = (data['type'] as String?) ?? '';
              final title = (data['title'] as String?) ?? '';
              final body = (data['body'] as String?) ?? '';
              final senderName = (data['senderName'] as String?) ?? '';
              final senderImage = (data['senderImage'] as String?) ?? '';
              final ts = data['timestamp'];

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
                  // Placeholder: later you can navigate to post/chat/match based on data
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
    );
  }
}
