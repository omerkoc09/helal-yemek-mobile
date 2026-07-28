import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itimat/features/venue/widgets/venue_detail_skeleton.dart';

void main() {
  group('VenueDetailSkeleton', () {
    testWidgets('ön bilgi verildiğinde mekan adı ve şehir hemen görünür',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VenueDetailSkeleton(name: 'Esenler döner', city: 'İstanbul'),
        ),
      );
      await tester.pump();

      expect(find.text('Esenler döner'), findsOneWidget);
      expect(find.text('İstanbul'), findsOneWidget);
    });

    testWidgets('ön bilgi yoksa metin göstermez ama yine de çizilir',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VenueDetailSkeleton()),
      );
      await tester.pump();

      expect(find.byType(VenueDetailSkeleton), findsOneWidget);
      expect(find.text('Esenler döner'), findsNothing);
      // İskelet blokları yine de çizilmeli.
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('geri butonu ile sayfadan çıkılabilir', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VenueDetailSkeleton(name: 'Test Mekan')),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('animasyon controller sızıntısız dispose edilir',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: VenueDetailSkeleton(name: 'Test')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Widget ağacından çıkar — dispose edilmezse pumpWidget sonrası
      // "A Ticker was still active" hatası alınır.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(find.byType(VenueDetailSkeleton), findsNothing);
    });
  });
}
