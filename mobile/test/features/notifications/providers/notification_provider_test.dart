import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:itimat/core/api/api_client.dart';
import 'package:itimat/core/auth/auth_provider.dart';
import 'package:itimat/core/api/api_endpoints.dart';
import 'package:itimat/features/notifications/providers/notification_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: ''),
    );

void main() {
  late MockApiClient mockApi;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockApiClient();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApi)],
    );
    registerFallbackValue(RequestOptions(path: ''));
  });

  tearDown(() => container.dispose());

  group('fetchNotifications', () {
    test('TC-13: API boş liste döndüğünde state boş liste olur (null değil)', () async {
      when(() => mockApi.get(ApiEndpoints.notifications))
          .thenAnswer((_) async => _ok({'data': []}));

      await container.read(notificationProvider.notifier).fetchNotifications();

      final state = container.read(notificationProvider);
      expect(state.notifications, isNotNull);
      expect(state.notifications, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('bildirimler başarıyla yüklenirse state\'e eklenir', () async {
      when(() => mockApi.get(ApiEndpoints.notifications)).thenAnswer((_) async =>
          _ok({
            'data': [
              {
                'id': 'n1',
                'user_id': 'u1',
                'type': 'verification_warning',
                'title': 'Test',
                'body': 'Test body',
                'is_read': false,
                'created_at': '2026-01-15T02:00:00.000Z',
              }
            ]
          }));

      await container.read(notificationProvider.notifier).fetchNotifications();

      final state = container.read(notificationProvider);
      expect(state.notifications.length, 1);
      expect(state.notifications.first.id, 'n1');
    });

    test('API hatasında error mesajı set edilir', () async {
      when(() => mockApi.get(ApiEndpoints.notifications))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      await container.read(notificationProvider.notifier).fetchNotifications();

      final state = container.read(notificationProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });
  });

  group('fetchUnreadCount', () {
    test('TC-14: unreadCount doğru değeri alır', () async {
      when(() => mockApi.get(ApiEndpoints.notificationsUnreadCount))
          .thenAnswer((_) async => _ok({'count': 3}));

      await container.read(notificationProvider.notifier).fetchUnreadCount();

      expect(container.read(notificationProvider).unreadCount, 3);
    });

    test('API hatasında unreadCount değişmez (sessiz başarısızlık)', () async {
      when(() => mockApi.get(ApiEndpoints.notificationsUnreadCount))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

      await container.read(notificationProvider.notifier).fetchUnreadCount();

      expect(container.read(notificationProvider).unreadCount, 0);
    });
  });

  group('markRead', () {
    test('başarılı markRead sonrası ilgili bildirim is_read=true olur', () async {
      // Önce 2 bildirim yükle
      when(() => mockApi.get(ApiEndpoints.notifications)).thenAnswer((_) async =>
          _ok({
            'data': [
              {
                'id': 'n1',
                'user_id': 'u1',
                'type': 'verification_warning',
                'title': 'T',
                'body': 'B',
                'is_read': false,
                'created_at': '2026-01-15T00:00:00.000Z',
              },
              {
                'id': 'n2',
                'user_id': 'u1',
                'type': 'venue_suspended',
                'title': 'T2',
                'body': 'B2',
                'is_read': false,
                'created_at': '2026-01-14T00:00:00.000Z',
              },
            ]
          }));
      when(() => mockApi.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'status': 'ok'}));

      await container.read(notificationProvider.notifier).fetchNotifications();
      // unreadCount manuel set
      container.read(notificationProvider.notifier).state =
          container.read(notificationProvider).copyWith(unreadCount: 2);

      await container.read(notificationProvider.notifier).markRead('n1');

      final state = container.read(notificationProvider);
      expect(state.notifications.firstWhere((n) => n.id == 'n1').isRead, isTrue);
      expect(state.notifications.firstWhere((n) => n.id == 'n2').isRead, isFalse);
      expect(state.unreadCount, 1);
    });

    test('unreadCount sıfırın altına düşmez', () async {
      when(() => mockApi.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'status': 'ok'}));

      // unreadCount zaten 0
      await container.read(notificationProvider.notifier).markRead('n1');

      expect(container.read(notificationProvider).unreadCount, 0);
    });
  });

  group('markAllRead', () {
    test('TC-16: tüm bildirimler is_read=true olur ve unreadCount=0', () async {
      when(() => mockApi.get(ApiEndpoints.notifications)).thenAnswer((_) async =>
          _ok({
            'data': [
              {
                'id': 'n1',
                'user_id': 'u1',
                'type': 'verification_warning',
                'title': 'T',
                'body': 'B',
                'is_read': false,
                'created_at': '2026-01-15T00:00:00.000Z',
              }
            ]
          }));
      when(() => mockApi.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'status': 'ok'}));

      await container.read(notificationProvider.notifier).fetchNotifications();
      container.read(notificationProvider.notifier).state =
          container.read(notificationProvider).copyWith(unreadCount: 1);

      await container.read(notificationProvider.notifier).markAllRead();

      final state = container.read(notificationProvider);
      expect(state.unreadCount, 0);
      expect(state.notifications.every((n) => n.isRead), isTrue);
    });
  });
}
