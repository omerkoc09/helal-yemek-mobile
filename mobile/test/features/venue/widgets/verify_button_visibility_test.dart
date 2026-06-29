import 'package:flutter_test/flutter_test.dart';
import 'package:caiz_mi/features/venue/widgets/verify_button_visibility.dart';

void main() {
  group('shouldShowVerifyButton', () {
    test('TC-08: mekan sahibi + approved + due uyarı penceresinde (≤1 gün) → göster', () {
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt: DateTime.now().add(const Duration(hours: 12))),
        isTrue,
      );
    });

    test('TC-08b: mekan sahibi + approved ama due henüz yaklaşmadı (>1 gün) → gizle', () {
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt: DateTime.now().add(const Duration(days: 7))),
        isFalse,
      );
    });

    test('TC-08d: due sınırın hemen üstünde (~1 gün 1 saat) → gizle', () {
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt:
                DateTime.now().add(const Duration(days: 1, hours: 1))),
        isFalse,
      );
    });

    test('TC-08e: due geçmiş (süre dolmuş) ama hâlâ approved → göster', () {
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt:
                DateTime.now().subtract(const Duration(hours: 1))),
        isTrue,
      );
    });

    test('TC-08c: mekan sahibi + approved ama due tarihi yok → gizle', () {
      expect(shouldShowVerifyButton('u1', 'u1', 'approved'), isFalse);
    });

    test('TC-09: mekan sahibi + suspended → göster', () {
      expect(shouldShowVerifyButton('u1', 'u1', 'suspended'), isTrue);
    });

    test('regression: doğrulama sonrası due tam period (2 gün) ileri → gizle', () {
      // Rehber doğrulayınca backend verification_due_at = NOW() + periodDays
      // yapıyor (ör. 2 gün). Buton bu yeni due'yla gizlenmeli; aksi halde
      // doğruladıktan sonra buton "hâlâ duruyor" olur.
      expect(
        shouldShowVerifyButton('u1', 'u1', 'approved',
            verificationDueAt: DateTime.now().add(const Duration(days: 2))),
        isFalse,
      );
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
