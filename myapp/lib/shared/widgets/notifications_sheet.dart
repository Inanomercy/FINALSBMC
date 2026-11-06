import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../../features/authentication/providers/auth_provider.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static void show(BuildContext context) {
    final userId = context.read<AuthProvider>().userProfile?.id;
    if (userId != null) {
      context.read<NotificationProvider>().loadNotifications(userId);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifs = provider.notifications;
    final userId = context.read<AuthProvider>().userProfile?.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (provider.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${provider.unreadCount}',
                            style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    if (provider.unreadCount > 0 && userId != null)
                      TextButton(
                        onPressed: () => provider.markAllAsRead(userId),
                        child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                      ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : notifs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 54, color: AppColors.grey),
                            SizedBox(height: 8),
                            Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final n = notifs[i];
                          return ListTile(
                            tileColor: n.isRead ? null : AppColors.primary.withValues(alpha: 0.04),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Icon(
                                n.type == 'order'
                                    ? Icons.receipt_long
                                    : (n.type == 'payment' ? Icons.payment : Icons.notifications),
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(n.title,
                                style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(n.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd, hh:mm a').format(n.createdAt),
                                  style: const TextStyle(fontSize: 10, color: AppColors.grey),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (!n.isRead) provider.markAsRead(n.id);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
