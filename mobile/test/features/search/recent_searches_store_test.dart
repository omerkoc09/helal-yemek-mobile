import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:itimat/features/search/data/recent_searches_store.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late RecentSearchesStore store;
  // Depodaki güncel değeri taklit eden bellek içi durum.
  String? current;

  setUp(() {
    storage = MockSecureStorage();
    current = null;

    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => current);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      current = invocation.namedArguments[const Symbol('value')] as String?;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {
      current = null;
    });

    store = RecentSearchesStore(storage: storage);
  });

  test('kayıt yokken boş liste döner', () async {
    expect(await store.load(), isEmpty);
  });

  test('eklenen terim listeye girer ve kalıcı olur', () async {
    await store.add('döner');
    expect(await store.load(), ['döner']);
  });

  test('en yeni terim en üstte olur', () async {
    await store.add('döner');
    await store.add('kebap');
    expect(await store.load(), ['kebap', 'döner']);
  });

  test('tekrar aranan terim başa taşınır, çift kayıt oluşmaz', () async {
    await store.add('döner');
    await store.add('kebap');
    await store.add('döner');
    expect(await store.load(), ['döner', 'kebap']);
  });

  test('en fazla 10 kayıt tutulur', () async {
    for (var i = 1; i <= 12; i++) {
      await store.add('terim$i');
    }
    final list = await store.load();
    expect(list.length, 10);
    expect(list.first, 'terim12');
    expect(list.contains('terim1'), isFalse);
    expect(list.contains('terim2'), isFalse);
  });

  test('boş/whitespace terim kaydedilmez', () async {
    await store.add('   ');
    expect(await store.load(), isEmpty);
  });

  test('terim kırpılarak kaydedilir', () async {
    await store.add('  döner  ');
    expect(await store.load(), ['döner']);
  });

  test('clear tüm kayıtları siler', () async {
    await store.add('döner');
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('bozuk veri sessizce boş listeye düşer', () async {
    current = 'bu-json-degil{{{';
    expect(await store.load(), isEmpty);
  });
}
