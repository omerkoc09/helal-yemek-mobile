import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/search/models/search_suggestion.dart';

FoodCategory cat(int id, String name) =>
    FoodCategory(id: id, key: 'k$id', name: name);

Venue venue(String id, String name, String city) => Venue(
      id: id,
      name: name,
      city: city,
      latitude: 41.0,
      longitude: 29.0,
      addedBy: 'test-user',
      status: 'approved',
    );

void main() {
  final categories = [cat(1, 'Döner'), cat(2, 'Kebap'), cat(3, 'Köfte')];
  final cities = ['İstanbul', 'Isparta', 'Bursa'];

  test('boş sorgu için öneri üretilmez', () {
    final result = buildSuggestions(
      query: '   ',
      categories: categories,
      cities: cities,
      districts: const [],
      venues: [venue('1', 'Dönerci Ali', 'Bursa')],
    );
    expect(result, isEmpty);
  });

  test('kategori Türkçe duyarsız eşleşir', () {
    final result = buildSuggestions(
      query: 'doner',
      categories: categories,
      cities: cities,
      districts: const [],
      venues: const [],
    );
    expect(result.length, 1);
    expect(result.first.type, SuggestionType.category);
    expect(result.first.label, 'Döner');
  });

  test('şehir Türkçe duyarsız eşleşir', () {
    final result = buildSuggestions(
      query: 'istanbul',
      categories: categories,
      cities: cities,
      districts: const [],
      venues: const [],
    );
    expect(result.any((s) => s.type == SuggestionType.city && s.label == 'İstanbul'), isTrue);
  });

  test('mekan önerisi id ve şehir alt başlığı taşır', () {
    final result = buildSuggestions(
      query: 'ali',
      categories: categories,
      cities: cities,
      districts: const [],
      venues: [venue('v1', 'Dönerci Ali', 'Bursa')],
    );
    expect(result.length, 1);
    expect(result.first.type, SuggestionType.venue);
    expect(result.first.venueId, 'v1');
    expect(result.first.subtitle, 'Bursa');
  });

  test('sıra kategori → şehir → mekan olur', () {
    final result = buildSuggestions(
      query: 'k',
      categories: [cat(1, 'Kebap')],
      cities: ['Kayseri'],
      districts: const [],
      venues: [venue('v1', 'Kral Kebap', 'Bursa')],
    );
    expect(result.map((s) => s.type).toList(), [
      SuggestionType.category,
      SuggestionType.city,
      SuggestionType.venue,
    ]);
  });

  test('limitler uygulanır: 3 kategori, 3 şehir, 5 mekan', () {
    final manyCategories =
        List.generate(6, (i) => cat(i, 'Test Kategori $i'));
    final manyCities = List.generate(6, (i) => 'Test Sehir $i');
    final manyVenues =
        List.generate(9, (i) => venue('v$i', 'Test Mekan $i', 'Bursa'));

    final result = buildSuggestions(
      query: 'test',
      categories: manyCategories,
      cities: manyCities,
      districts: const [],
      venues: manyVenues,
    );

    expect(result.where((s) => s.type == SuggestionType.category).length, 3);
    expect(result.where((s) => s.type == SuggestionType.city).length, 3);
    expect(result.where((s) => s.type == SuggestionType.venue).length, 5);
  });

  test('eşleşme yoksa boş liste döner', () {
    final result = buildSuggestions(
      query: 'zzzz',
      categories: categories,
      cities: cities,
      districts: const [],
      venues: const [],
    );
    expect(result, isEmpty);
  });

  test('sunucudan gelen mekanlar ada göre yeniden filtrelenmez', () {
    final result = buildSuggestions(
      query: 'doner',
      categories: categories,
      cities: cities,
      districts: const [],
      venues: [venue('v1', 'Meşhur Usta', 'Bursa')],
    );
    expect(
      result.any((s) =>
          s.type == SuggestionType.venue && s.label == 'Meşhur Usta'),
      isTrue,
    );
  });

  test('ilçe Türkçe duyarsız eşleşir ve şehirle birlikte etiketlenir', () {
    final result = buildSuggestions(
      query: 'fatih',
      categories: const [],
      cities: const [],
      districts: [const CityDistrict(city: 'İstanbul', district: 'Fatih')],
      venues: const [],
    );

    expect(result.length, 1);
    expect(result.first.type, SuggestionType.district);
    expect(result.first.label, 'İstanbul / Fatih');
    expect(result.first.city, 'İstanbul');
    expect(result.first.district, 'Fatih');
  });

  test('ilçe önerileri en fazla 3 tane gelir', () {
    final manyDistricts = List.generate(
      6,
      (i) => CityDistrict(city: 'İstanbul', district: 'Test İlçe $i'),
    );

    final result = buildSuggestions(
      query: 'test',
      categories: const [],
      cities: const [],
      districts: manyDistricts,
      venues: const [],
    );

    expect(result.where((s) => s.type == SuggestionType.district).length, 3);
  });

  test('öneri sırası kategori → ilçe → şehir → mekan olur', () {
    final result = buildSuggestions(
      query: 'a',
      categories: [cat(1, 'Adana Kebap')],
      cities: ['Adana'],
      districts: [const CityDistrict(city: 'Adana', district: 'Aladağ')],
      venues: [venue('v1', 'Ali Usta', 'Adana')],
    );

    expect(result.map((s) => s.type).toList(), [
      SuggestionType.category,
      SuggestionType.district,
      SuggestionType.city,
      SuggestionType.venue,
    ]);
  });
}
