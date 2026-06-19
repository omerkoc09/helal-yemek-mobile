import 'package:flutter_test/flutter_test.dart';
import 'package:caiz_mi/features/venue/widgets/verify_button_visibility.dart';

void main() {
  group('shouldShowVerifyButton', () {
    test('TC-08: mekan sahibi + approved + due ≤14 gün → göster', () {
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt: DateTime.now().add(const Duration(days: 7))),
        isTrue,
      );
    });

    test('TC-08b: mekan sahibi + approved ama due >14 gün → gizle', () {
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt: DateTime.now().add(const Duration(days: 30))),
        isFalse,
      );
    });

    test('TC-08c: mekan sahibi + approved ama due tarihi yok → gizle', () {
      expect(shouldShowVerifyButton('u1', 'u1', 'approved'), isFalse);
    });

    test('TC-09: mekan sahibi + suspended → göster', () {
      expect(shouldShowVerifyButton('u1', 'u1', 'suspended'), isTrue);
    });

    test('TC-25: başka kullanıcı + approved → gizle', () {
      expect(shouldShowVerifyButton('u2', 'u1', 'approved'), isFalse);
    });

    test('TC-26: mekan sahibi + pending → gizle', () {
      expect(shouldShowVerifyButton('u1', 'u1', 'pending'), isFalse);
    });

    test('mekan sahibi + rejected → gizle', () {
      expect(shouldShowVerifyButton('u1', 'u1', 'rejected'), isFalse);
    });

    test('giriş yapılmamış (null userId) → gizle', () {
      expect(shouldShowVerifyButton(null, 'u1', 'approved'), isFalse);
    });

    test('başka kullanıcı + suspended → gizle', () {
      expect(shouldShowVerifyButton('u2', 'u1', 'suspended'), isFalse);
    });
  });
}
