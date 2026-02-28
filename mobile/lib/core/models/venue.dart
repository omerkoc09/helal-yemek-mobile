import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue.freezed.dart';
part 'venue.g.dart';

@freezed
abstract class Venue with _$Venue {
  const factory Venue({
    required String id,
    required String name,
    required String address,
    required String city,
    required double latitude,
    required double longitude,
    String? notes,
    @Default('pending') String status,
    @JsonKey(name: 'rejection_note') String? rejectionNote,
    @JsonKey(name: 'added_by') required String addedBy,
    @JsonKey(name: 'approved_by') String? approvedBy,
    @JsonKey(name: 'verified_at') DateTime? verifiedAt,
    @JsonKey(name: 'all_food_halal') @Default(false) bool allFoodHalal,
    @Default([]) List<HalalCriteria> criteria,
    @Default([]) List<VenuePhoto> photos,
    @JsonKey(name: 'food_items') @Default([]) List<FoodItem> foodItems,
    @JsonKey(name: 'avg_rating') double? avgRating,
    @JsonKey(name: 'review_count') @Default(0) int reviewCount,
    double? distance,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Venue;

  const Venue._();

  factory Venue.fromJson(Map<String, dynamic> json) => _$VenueFromJson(json);

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
}

@freezed
abstract class HalalCriteria with _$HalalCriteria {
  const factory HalalCriteria({
    required int id,
    required String key,
    @JsonKey(name: 'label_tr') required String labelTr,
    @JsonKey(name: 'label_en') required String labelEn,
  }) = _HalalCriteria;

  factory HalalCriteria.fromJson(Map<String, dynamic> json) =>
      _$HalalCriteriaFromJson(json);
}

@freezed
abstract class VenuePhoto with _$VenuePhoto {
  const factory VenuePhoto({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    required String url,
    @JsonKey(name: 'uploaded_by') required String uploadedBy,
    @JsonKey(name: 'is_primary') @Default(false) bool isPrimary,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _VenuePhoto;

  factory VenuePhoto.fromJson(Map<String, dynamic> json) =>
      _$VenuePhotoFromJson(json);
}

@freezed
abstract class FoodCategory with _$FoodCategory {
  const factory FoodCategory({
    required int id,
    required String key,
    @JsonKey(name: 'label_tr') required String labelTr,
    @JsonKey(name: 'label_en') required String labelEn,
    @Default([]) List<FoodItem> items,
  }) = _FoodCategory;

  factory FoodCategory.fromJson(Map<String, dynamic> json) =>
      _$FoodCategoryFromJson(json);
}

@freezed
abstract class FoodItem with _$FoodItem {
  const factory FoodItem({
    required int id,
    @JsonKey(name: 'category_id') required int categoryId,
    required String key,
    @JsonKey(name: 'label_tr') required String labelTr,
    @JsonKey(name: 'label_en') required String labelEn,
    @JsonKey(name: 'is_custom') @Default(false) bool isCustom,
  }) = _FoodItem;

  factory FoodItem.fromJson(Map<String, dynamic> json) =>
      _$FoodItemFromJson(json);
}
