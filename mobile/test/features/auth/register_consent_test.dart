import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itimat/features/auth/screens/register_screen.dart';

/// Kayıt ekranındaki yasal onay kapısı.
///
/// Şartlar onaylanmadan hesap açılabilmesi hem sözleşmesel hem de mağaza
/// açısından sorun — bu yüzden hem "Hesap Oluştur" hem de "Google ile kayıt"
/// yolu onaya bağlı.
void main() {
  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pump();
  }

  /// Etiketiyle bulunan butonun etkin olup olmadığını döner.
  bool isButtonEnabled(WidgetTester tester, String label) {
    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(ElevatedButton),
      ),
    );
    return button.onPressed != null;
  }

  testWidgets('onay kutuları başlangıçta işaretsiz', (tester) async {
    await pumpRegister(tester);

    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes.length, 2, reason: 'şartlar + KVKK ayrı olmalı');
    expect(
      boxes.every((b) => b.value == false),
      isTrue,
      reason: 'onaylar önceden işaretli gelmemeli — açık rıza özgür irade ister',
    );
  });

  testWidgets('şartlar onaylanmadan kayıt butonu kapalı', (tester) async {
    await pumpRegister(tester);

    expect(
      isButtonEnabled(tester, 'Hesap Oluştur'),
      isFalse,
      reason: 'onaysız hesap açılamamalı',
    );
  });

  testWidgets('şartlar onaylanınca kayıt butonu açılır', (tester) async {
    await pumpRegister(tester);

    // İlk kutu: kullanım şartları + gizlilik politikası.
    // Onay kutuları form altında; varsayılan test ekranına (800x600) sığmıyor.
    // Kaydırmadan tap() sessizce hedefi ıskalar.
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(isButtonEnabled(tester, 'Hesap Oluştur'), isTrue);
  });

  testWidgets('KVKK rızası kaydı engellemez (isteğe bağlı)', (tester) async {
    // KVKK açık rızası sözleşmenin ifasından bağımsızdır; zorunlu tutmak
    // rızayı sakatlar. Yalnızca şartlar onayı yeterli olmalı.
    await pumpRegister(tester);

    // Onay kutuları form altında; varsayılan test ekranına (800x600) sığmıyor.
    // Kaydırmadan tap() sessizce hedefi ıskalar.
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    final kvkkBox = tester.widgetList<Checkbox>(find.byType(Checkbox)).last;
    expect(kvkkBox.value, isFalse, reason: 'KVKK işaretsiz kalmalı');
    expect(
      isButtonEnabled(tester, 'Hesap Oluştur'),
      isTrue,
      reason: 'KVKK olmadan da kayıt yapılabilmeli',
    );
  });
}
