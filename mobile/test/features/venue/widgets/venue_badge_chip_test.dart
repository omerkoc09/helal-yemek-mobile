import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:caiz_mi/core/models/venue.dart';
import 'package:caiz_mi/features/venue/widgets/venue_badge_chip.dart';

void main() {
  testWidgets('compact: ekleyen dahil toplam sayıyı gösterir (count+1)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VenueBadgeChip(badge: Badge(level: 'silver', count: 4), compact: true),
      ),
    ));
    // count=4 (ekleyen hariç) → 5 (ekleyen dahil) gösterilir.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4'), findsNothing);
  });

  testWidgets('compact: base/null rozet hiçbir şey göstermez', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VenueBadgeChip(badge: null, compact: true)),
    ));
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('detay: ekleyen dahil somut sayı gösterir, seviye adı göstermez', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VenueBadgeChip(badge: Badge(level: 'gold', count: 7), compact: false),
      ),
    ));
    // count=7 (ekleyen hariç) → 8 (ekleyen dahil) gösterilir.
    expect(find.text('8 rehber doğruladı'), findsOneWidget);
    // Seviye adı (Altın/Gümüş/Bronz) GÖSTERİLMEZ — kavram sadeliği.
    expect(find.textContaining('Altın'), findsNothing);
    expect(find.textContaining('Rozet'), findsNothing);
  });

  testWidgets('detay: base/null rozet hiçbir şey göstermez', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VenueBadgeChip(badge: Badge(level: 'base', count: 0), compact: false),
      ),
    ));
    expect(find.byType(Icon), findsNothing);
    expect(find.textContaining('rehber'), findsNothing);
  });
}
