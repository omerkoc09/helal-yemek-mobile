import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/notification_model.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) => NotificationState(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() => const NotificationState();

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.notifications);
      final items = (res.data['data'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(notifications: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Bildirimler yüklenemedi');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiEndpoints.notificationsUnreadCount);
      state = state.copyWith(unreadCount: res.data['count'] as int);
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put(ApiEndpoints.notificationRead(id), data: {});
      state = state.copyWith(
        notifications: state.notifications.map((n) =>
          n.id == id ? n.copyWith(isRead: true) : n
        ).toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put(ApiEndpoints.notificationsReadAll, data: {});
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
        unreadCount: 0,
      );
    } catch (_) {}
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);
