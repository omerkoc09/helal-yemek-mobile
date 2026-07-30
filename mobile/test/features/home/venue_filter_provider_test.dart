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

FoodCategory _cat(int id, String name) =>
    FoodCategory(id: id, key: 'k$id', name: name);

Venue _venueFull({
  required String name,
  String? district,
  List<FoodCategory> categories = const [],
}) =>
    Venue(
      id: name,
      name: name,
      city: 'Bursa',
      district: district,
      latitude: 41.0,
      longitude: 29.0,
      addedBy: 'test-user',
      status: 'approved',
      categories: categories,
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

  test('liste filtresi kategori adıyla eşleşir', () {
    final venues = [
      _venueFull(name: 'Meşhur Usta', categories: [_cat(1, 'Kebap')]),
      _venueFull(name: 'Pizza Roma', categories: [_cat(2, 'Pizza')]),
    ];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'kebap',
    );

    expect(result.length, 1);
    expect(result.first.name, 'Meşhur Usta');
  });

  test('liste filtresi ilçe adıyla eşleşir', () {
    final venues = [
      _venueFull(name: 'Bir Mekan', district: 'Osmangazi'),
      _venueFull(name: 'Başka Mekan', district: 'Nilüfer'),
    ];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'osmangazi',
    );

    expect(result.length, 1);
    expect(result.first.name, 'Bir Mekan');
  });

  test('kategori eşleşmesi de Türkçe karakter duyarsızdır', () {
    final venues = [
      _venueFull(name: 'Bir Mekan', categories: [_cat(1, 'Köfte')]),
    ];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'kofte',
    );

    expect(result.length, 1);
  });

  test('ilçesi/kategorisi olmayan mekan eşleşmezse listeden düşer', () {
    final venues = [_venueFull(name: 'Bir Mekan')];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'zzzz',
    );

    expect(result, isEmpty);
  });
}
