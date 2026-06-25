import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';

/// Yol tarifi tıklamasını backend'e bildirir. Fire-and-forget:
/// await edilmez, hata yutulur — Google Maps her durumda açılır.
void trackDirectionClick(WidgetRef ref, String venueId) {
  final apiClient = ref.read(apiClientProvider);
  unawaited(_send(apiClient, venueId));
}

Future<void> _send(ApiClient apiClient, String venueId) async {
  try {
    await apiClient.post(ApiEndpoints.venueDirectionClick(venueId));
  } catch (_) {
    // sessizce yut — Google Maps her durumda açılır
  }
}
