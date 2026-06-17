import 'package:flutter_test/flutter_test.dart';
import 'package:caiz_mi/shared/widgets/notification_badge_label.dart';

void main() {
  group('notificationBadgeLabel', () {
    test('TC-20: 1-99 arası sayıyı olduğu gibi döndürür', () {
      expect(notificationBadgeLabel(1), '1');
      expect(notificationBadgeLabel(5), '5');
      expect(notificationBadgeLabel(99), '99');
    });

    test('TC-21: 99 üzeri için "99+" döndürür', () {
      expect(notificationBadgeLabel(100), '99+');
      expect(notificationBadgeLabel(150), '99+');
      expect(notificationBadgeLabel(999), '99+');
    });

    test('tam 99 sınırında "99" döndürür (99+ değil)', () {
      expect(notificationBadgeLabel(99), '99');
    });

    test('tam 100 sınırında "99+" döndürür', () {
      expect(notificationBadgeLabel(100), '99+');
    });

    test('0 için "0" döndürür (badge zaten gösterilmez ama fonksiyon doğru çalışmalı)', () {
      expect(notificationBadgeLabel(0), '0');
    });
  });
}
