import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/theme/app_theme.dart';
import 'package:itimat/shared/widgets/app_toast.dart';

void main() {
  /// İçinden toast tetiklenebilen minimal bir uygulama.
  Widget harness(void Function(BuildContext) onTap) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => onTap(context),
                child: const Text('göster'),
              ),
            ),
          ),
        ),
      );

  Color? toastBackground(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.ancestor(
        of: find.byType(Row),
        matching: find.byType(Container),
      ).first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  testWidgets('success toast mesajı ve onay ikonunu gösterir', (tester) async {
    await tester.pumpWidget(harness((c) => AppToast.success(c, 'Kaydedildi')));
    await tester.tap(find.text('göster'));
    await tester.pump();

    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(toastBackground(tester), AppTheme.pinApproved);

    // Overlay'i temizle ki test sonunda bekleyen timer kalmasın.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('error toast hata rengiyle çizilir', (tester) async {
    await tester.pumpWidget(harness((c) => AppToast.error(c, 'Başarısız')));
    await tester.tap(find.text('göster'));
    await tester.pump();

    expect(find.text('Başarısız'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    expect(toastBackground(tester), AppTheme.error);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('success toast 2 saniye sonra kaybolur', (tester) async {
    await tester.pumpWidget(harness((c) => AppToast.success(c, 'Kaydedildi')));
    await tester.tap(find.text('göster'));
    await tester.pump();
    expect(find.text('Kaydedildi'), findsOneWidget);

    // Süre dolmadan hemen önce hâlâ görünür olmalı.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text('Kaydedildi'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Kaydedildi'), findsNothing);
  });

  testWidgets('error toast success’ten uzun kalır', (tester) async {
    await tester.pumpWidget(harness((c) => AppToast.error(c, 'Başarısız')));
    await tester.tap(find.text('göster'));
    await tester.pump();

    // Success süresi (2sn) dolduğunda hata mesajı hâlâ okunabilir olmalı.
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('Başarısız'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Başarısız'), findsNothing);
  });

  testWidgets('ikinci toast birincinin yerini alır', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(harness((c) => ctx = c));
    await tester.tap(find.text('göster'));
    await tester.pump();

    AppToast.success(ctx, 'Birinci');
    await tester.pump();
    expect(find.text('Birinci'), findsOneWidget);

    AppToast.error(ctx, 'İkinci');
    await tester.pump();
    expect(find.text('Birinci'), findsNothing);
    expect(find.text('İkinci'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });
}
