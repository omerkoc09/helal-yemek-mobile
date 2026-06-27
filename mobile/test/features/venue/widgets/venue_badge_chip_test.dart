import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:caiz_mi/core/models/venue.dart';
import 'package:caiz_mi/features/venue/widgets/venue_badge_chip.dart';

void main() {
  testWidgets('compact: silver rozet etiketi ve sayı gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VenueBadgeChip(badge: Badge(level: 'silver', count: 4), compact: true),
      ),
    ));
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('compact: base/null rozet hiçbir şey göstermez', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VenueBadgeChip(badge: null, compact: true)),
    ));
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('detay: gold seviye etiketi gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VenueBadgeChip(badge: Badge(level: 'gold', count: 7), compact: false),
      ),
    ));
    expect(find.textContaining('Altın'), findsOneWidget);
    expect(find.textContaining('7'), findsOneWidget);
  });
}
