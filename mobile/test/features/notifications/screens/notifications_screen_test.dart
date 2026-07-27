import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itimat/core/models/notification_model.dart';
import 'package:itimat/features/notifications/providers/notification_provider.dart';
import 'package:itimat/features/notifications/screens/notifications_screen.dart';

// initState'deki fetchNotifications çağrısını durdurmak için no-op notifier.
class _FakeNotificationNotifier extends NotificationNotifier {
  final NotificationState _initial;
  _FakeNotificationNotifier(this._initial);

  @override
  NotificationState build() => _initial;

  @override
  Future<void> fetchNotifications() async {}

  @override
  Future<void> fetchUnreadCount() async {}
}

Widget _buildScreen(NotificationState initialState) {
  return ProviderScope(
    overrides: [
      notificationProvider
          .overrideWith(() => _FakeNotificationNotifier(initialState)),
    ],
    child: const MaterialApp(home: NotificationsScreen()),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr', null);
  });

  group('NotificationsScreen', () {
    testWidgets('TC-23: boş bildirim listesi empty state gösterir', (tester) async {
      await tester.pumpWidget(_buildScreen(const NotificationState()));
      await tester.pump(); // post-frame callback'i tetikle

      expect(find.text('Henüz bildiriminiz yok'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets('TC-24: yüklenirken LoadingIndicator gösterilir', (tester) async {
      await tester.pumpWidget(
        _buildScreen(const NotificationState(isLoading: true)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Henüz bildiriminiz yok'), findsNothing);
    });

    testWidgets('TC-23b: bildirimler varsa liste görünür, empty state olmaz',
        (tester) async {
      final notification = AppNotification(
        id: 'n1',
        userId: 'u1',
        type: 'verification_warning',
        title: 'Doğrulama Uyarısı',
        body: 'Mekanınızın doğrulama süresi dolmak üzere.',
        isRead: false,
        createdAt: DateTime(2026, 1, 15),
      );

      await tester.pumpWidget(
        _buildScreen(NotificationState(notifications: [notification])),
      );
      await tester.pump();

      expect(find.text('Doğrulama Uyarısı'), findsOneWidget);
      expect(find.text('Henüz bildiriminiz yok'), findsNothing);
    });

    testWidgets('unreadCount=0 iken "tümünü okundu işaretle" butonu olmaz',
        (tester) async {
      await tester.pumpWidget(_buildScreen(const NotificationState()));
      await tester.pump();

      expect(find.text('Tümünü okundu işaretle'), findsNothing);
    });

    testWidgets('unreadCount>0 iken "tümünü okundu işaretle" butonu görünür',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildScreen(const NotificationState(unreadCount: 2)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tümünü okundu işaretle'), findsOneWidget);
    });
  });
}
