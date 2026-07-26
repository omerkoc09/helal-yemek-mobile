import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';

import 'package:caiz_mi/core/models/venue.dart';
import 'package:caiz_mi/features/venue/widgets/trust_criteria_badge.dart';

void main() {
  const seedKeys = [
    'trust_certified',
    'known_owner',
    'no_boycott_products',
    'no_alcohol',
    'clean_maintained',
    'visited_by_guide',
    'long_standing',
    'some_admin_added_key', // bilinmeyen → nötr fallback
  ];

  List<TrustCriteria> _buildCriteria() => [
        for (var i = 0; i < seedKeys.length; i++)
          TrustCriteria(
            id: i + 1,
            key: seedKeys[i],
            name: 'Kriter ${i + 1}',
            description: i.isEven ? 'Açıklama ${i + 1}' : null,
          ),
      ];

  testWidgets('tüm kriterler taşmadan render olur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TrustCriteriaBadges(criteria: _buildCriteria()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TrustCriteriaBadge), findsNWidgets(seedKeys.length));
    expect(find.text('Kriter 1'), findsOneWidget);
  });

  testWidgets('açıklamalı rozete tıklayınca dialog açılır', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrustCriteriaBadges(criteria: _buildCriteria()),
        ),
      ),
    );

    // 'Kriter 1' açıklamalı (index 0, çift) → tıklanabilir.
    await tester.tap(find.text('Kriter 1'));
    await tester.pumpAndSettle();

    expect(find.text('Açıklama 1'), findsOneWidget);
    expect(find.text('Tamam'), findsOneWidget);
  });

  testWidgets('boş liste hiçbir şey render etmez', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrustCriteriaBadges(criteria: [])),
      ),
    );

    expect(find.byType(TrustCriteriaBadge), findsNothing);
  });
}
