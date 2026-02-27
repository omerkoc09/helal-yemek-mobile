import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import 'venue_detail_provider.dart';

class ReviewFormState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  const ReviewFormState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  ReviewFormState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return ReviewFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class ReviewFormNotifier extends Notifier<ReviewFormState> {
  @override
  ReviewFormState build() => const ReviewFormState();

  void reset() {
    state = const ReviewFormState();
  }

  Future<void> submitReview({
    required String venueId,
    required int rating,
    String? comment,
  }) async {
    state = const ReviewFormState(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        ApiEndpoints.venueReviews(venueId),
        data: {
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      state = const ReviewFormState(isSuccess: true);
      ref.invalidate(venueReviewsProvider(venueId));
      ref.invalidate(venueDetailProvider(venueId));
    } catch (e) {
      state = const ReviewFormState(
        error: 'Yorum gönderilemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> updateReview({
    required String venueId,
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    state = const ReviewFormState(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        ApiEndpoints.venueReview(venueId, reviewId),
        data: {
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      state = const ReviewFormState(isSuccess: true);
      ref.invalidate(venueReviewsProvider(venueId));
      ref.invalidate(venueDetailProvider(venueId));
    } catch (e) {
      state = const ReviewFormState(
        error: 'Yorum güncellenemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> deleteReview({
    required String venueId,
    required String reviewId,
  }) async {
    state = const ReviewFormState(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete(ApiEndpoints.venueReview(venueId, reviewId));
      state = const ReviewFormState(isSuccess: true);
      ref.invalidate(venueReviewsProvider(venueId));
      ref.invalidate(venueDetailProvider(venueId));
    } catch (e) {
      state = const ReviewFormState(error: 'Yorum silinemedi.');
    }
  }
}

final reviewFormProvider =
    NotifierProvider<ReviewFormNotifier, ReviewFormState>(
  ReviewFormNotifier.new,
);
