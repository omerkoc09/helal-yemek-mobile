import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/home/providers/venue_filter_provider.dart';

Venue _venue(String name) => Venue(
      id: name,
      name: name,
      city: 'Bursa',
      latitude: 41.0,
      longitude: 29.0,
      addedBy: 'test-user',
      status: 'approved',
    );

void main() {
  test('lokal isim araması Türkçe karakter duyarsızdır', () {
    final venues = [_venue('Köfteci Yusuf'), _venue('Pizza Roma')];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'kofte',
    );

    expect(result.length, 1);
    expect(result.first.name, 'Köfteci Yusuf');
  });

  test('büyük/küçük harf farkı sonucu etkilemez', () {
    final venues = [_venue('Dönerci Ali')];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'DONERCI',
    );

    expect(result.length, 1);
  });
}
