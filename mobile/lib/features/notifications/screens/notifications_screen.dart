import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/notification_provider.dart';
import '../../../core/models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Tümünü okundu işaretle',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('Henüz bildiriminiz yok',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
      child: ListView.builder(
        itemCount: state.notifications.length,
        itemBuilder: (context, index) => _NotificationItem(
          notification: state.notifications[index],
          onTap: () => _handleTap(state.notifications[index]),
        ),
      ),
    );
  }

  void _handleTap(AppNotification n) {
    if (!n.isRead) {
      ref.read(notificationProvider.notifier).markRead(n.id);
    }
    final venueId = n.data?['venue_id'];
    if (venueId != null) {
      context.push('/venue/$venueId');
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationItem({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isWarning = notification.type == 'verification_warning';
    final color = isWarning ? Colors.orange : Colors.red;
    final icon = isWarning ? Icons.warning_amber_rounded : Icons.pause_circle_outline;

    return ListTile(
      tileColor: notification.isRead ? null : color.withValues(alpha: 0.06),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
          fontSize: 14,
        )),
      subtitle: Text(notification.body,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        DateFormat('dd MMM', 'tr').format(notification.createdAt),
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      onTap: onTap,
    );
  }
}
