import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/review.dart';
import '../../../core/models/venue.dart';

final venueDetailProvider =
    FutureProvider.family<Venue, String>((ref, venueId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.venueDetail(venueId));
  final data = response.data;
  final json =
      data is Map<String, dynamic> ? (data['data'] ?? data) : data;
  return Venue.fromJson(json as Map<String, dynamic>);
});

final venueReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, venueId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.venueReviews(venueId));
  final data = response.data;
  final List<dynamic> reviewList =
      data is Map<String, dynamic> ? (data['data'] as List? ?? []) : (data as List? ?? []);
  return reviewList
      .map((json) => Review.fromJson(json as Map<String, dynamic>))
      .toList();
});
