import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/auth/auth_provider.dart';
import 'package:itimat/features/notifications/providers/notification_provider.dart';
import 'package:itimat/shared/widgets/app_header.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final bool _isAuth;
  _FakeAuthNotifier(this._isAuth);

  @override
  AuthState build() => AuthState(
        status: _isAuth ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      );
}

class _FakeNotificationNotifier extends NotificationNotifier {
  final int _unread;
  _FakeNotificationNotifier(this._unread);

  @override
  NotificationState build() => NotificationState(unreadCount: _unread);

  @override
  Future<void> fetchUnreadCount() async {}

  @override
  Future<void> fetchNotifications() async {}
}

Widget _buildHeader({required bool isAuth, int unread = 0}) {
  return ProviderScope(
    overrides: [
      locationLabelProvider.overrideWith((_) async => 'Test Şehir'),
      authProvider.overrideWith(() => _FakeAuthNotifier(isAuth)),
      notificationProvider.overrideWith(() => _FakeNotificationNotifier(unread)),
    ],
    child: MaterialApp(
      home: Scaffold(appBar: AppHeader()),
    ),
  );
}

void main() {
  group('AppHeader — bildirim ikonu görünürlüğü', () {
    testWidgets('TC-19: giriş yapılmamışsa zil ikonu görünmez', (tester) async {
      await tester.pumpWidget(_buildHeader(isAuth: false));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none), findsNothing);
    });

    testWidgets('TC-20: unreadCount=5 ise zil ikonu görünür ve "5" badge gösterilir',
        (tester) async {
      await tester.pumpWidget(_buildHeader(isAuth: true, unread: 5));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('TC-21: unreadCount=100 ise badge "99+" gösterir', (tester) async {
      await tester.pumpWidget(_buildHeader(isAuth: true, unread: 100));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('TC-22: unreadCount=0 ise zil ikonu görünür ama badge olmaz',
        (tester) async {
      await tester.pumpWidget(_buildHeader(isAuth: true, unread: 0));
      await tester.pump();

      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });
}
