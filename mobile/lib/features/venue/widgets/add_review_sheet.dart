import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/star_rating_widget.dart';
import '../providers/review_provider.dart';

Future<void> showAddReviewSheet(
  BuildContext context, {
  required String venueId,
  Review? existingReview,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddReviewSheet(
      venueId: venueId,
      existingReview: existingReview,
    ),
  );
}

class _AddReviewSheet extends ConsumerStatefulWidget {
  final String venueId;
  final Review? existingReview;

  const _AddReviewSheet({
    required this.venueId,
    this.existingReview,
  });

  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  late int _rating;
  late final TextEditingController _commentController;
  bool get _isEditing => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 0;
    _commentController = TextEditingController(
      text: widget.existingReview?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(reviewFormProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    ref.listen<ReviewFormState>(reviewFormProvider, (prev, next) {
      if (next.isSuccess) {
        Navigator.of(context).pop();
        AppToast.success(
          context,
          _isEditing ? 'Yorum güncellendi.' : 'Yorum eklendi.',
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _isEditing ? 'Yorumu Düzenle' : 'Yorum Yaz',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Yıldız seçimi
          const Text(
            'Puanınız',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: StarRatingWidget(
              rating: _rating.toDouble(),
              size: 40,
              interactive: true,
              onRatingChanged: (value) => setState(() => _rating = value),
            ),
          ),
          const SizedBox(height: 20),

          // Yorum alanı
          TextField(
            controller: _commentController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Yorumunuzu yazın (isteğe bağlı)...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Hata mesajı
          if (formState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                formState.error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 14),
              ),
            ),

          // Gönder butonu
          ElevatedButton(
            onPressed: _rating == 0 || formState.isLoading ? null : _submit,
            child: formState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Güncelle' : 'Gönder'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _submit() {
    final notifier = ref.read(reviewFormProvider.notifier);
    final comment = _commentController.text.trim();

    if (_isEditing) {
      notifier.updateReview(
        venueId: widget.venueId,
        reviewId: widget.existingReview!.id,
        rating: _rating,
        comment: comment.isEmpty ? null : comment,
      );
    } else {
      notifier.submitReview(
        venueId: widget.venueId,
        rating: _rating,
        comment: comment.isEmpty ? null : comment,
      );
    }
  }
}
