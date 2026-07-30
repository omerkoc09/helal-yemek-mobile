import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';

/// Onaylı mekanı bulunan şehirler — öneri listesinde şehir eşleşmeleri için.
/// Ekran ömrü boyunca bir kez çekilir; öneriler istemcide lokal eşlenir.
final searchCitiesProvider = FutureProvider<List<String>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.venuesCities);

  final data = response.data;
  final List<dynamic> list = data is List
      ? data
      : (data is Map<String, dynamic> ? (data['data'] as List? ?? []) : []);

  return list.whereType<String>().toList();
});
