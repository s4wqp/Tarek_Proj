import 'package:flutter/material.dart';
import 'package:tarek_proj/config/app_colors.dart';

/// A simple in-app notifications screen.
/// In production this would be backed by Firebase Cloud Messaging or a
/// notifications API.  For now it provides a polished placeholder that is
/// ready to be wired up.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Simulated notification list — replace with real data source.
  final List<_NotifItem> _notifications = [
    _NotifItem(
      icon: Icons.check_circle,
      color: AppColors.success,
      title: 'Account Approved',
      body: 'Your provider account has been approved. Start offering services!',
      time: '2 min ago',
      isRead: false,
    ),
    _NotifItem(
      icon: Icons.directions_car,
      color: AppColors.primary,
      title: 'New Ride Request',
      body: 'A passenger is looking for a ride from Cairo to Alexandria.',
      time: '15 min ago',
      isRead: false,
    ),
    _NotifItem(
      icon: Icons.star,
      color: AppColors.warning,
      title: 'New Rating',
      body: 'You received a 5-star rating for your last trip!',
      time: '1 hour ago',
      isRead: true,
    ),
    _NotifItem(
      icon: Icons.campaign,
      color: AppColors.secondary,
      title: 'Promotion',
      body: 'Check out our new sponsor deals in your area.',
      time: '3 hours ago',
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n.isRead = true;
                }
              });
            },
            child: const Text('Mark all read',
                style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_off,
                        size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text('No notifications yet',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("You're all caught up!",
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 14)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, i) {
                final n = _notifications[i];
                return Dismissible(
                  key: ValueKey(i),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() => _notifications.removeAt(i));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification dismissed')),
                    );
                  },
                  child: _buildNotifTile(n),
                );
              },
            ),
    );
  }

  Widget _buildNotifTile(_NotifItem n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: n.isRead ? AppColors.card : AppColors.card.withAlpha(230),
        borderRadius: BorderRadius.circular(14),
        border: n.isRead
            ? null
            : Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: n.color.withAlpha(40),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(n.icon, color: n.color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(n.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            if (!n.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(n.body,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Text(n.time,
                style:
                    const TextStyle(color: AppColors.textHint, fontSize: 11)),
          ],
        ),
        onTap: () {
          setState(() => n.isRead = true);
        },
      ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  bool isRead;

  _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });
}
