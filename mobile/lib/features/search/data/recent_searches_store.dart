import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Son arama terimlerini cihazda saklar.
///
/// Hassas veri değil; projede zaten bulunan flutter_secure_storage kullanılıyor
/// (token_storage.dart deseni) — yalnızca yeni bağımlılık eklememek için.
class RecentSearchesStore {
  static const String _key = 'recent_searches';
  static const int maxItems = 10;

  final FlutterSecureStorage _storage;

  RecentSearchesStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Kayıtlı terimleri en yeniden eskiye döndürür.
  /// Bozuk veri sessizce boş listeye düşer.
  Future<List<String>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Terimi listenin başına ekler; tekrar edenler yukarı taşınır, liste
  /// [maxItems] ile sınırlanır. Güncel listeyi döndürür.
  Future<List<String>> add(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return load();

    // Not: `await load()..removeWhere(...)` cascade'i `Future` üzerinde
    // çalışır, çözülen `List` üzerinde değil — bu yüzden önce await edip
    // sonucu ayrı bir değişkende tutuyoruz.
    final list = await load();
    list.removeWhere((e) => e == trimmed);
    list.insert(0, trimmed);

    final capped = list.take(maxItems).toList();
    await _storage.write(key: _key, value: jsonEncode(capped));
    return capped;
  }

  /// Tüm kayıtları siler.
  Future<void> clear() => _storage.delete(key: _key);
}

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(),
);
