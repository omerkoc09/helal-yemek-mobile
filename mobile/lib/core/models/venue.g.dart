// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Venue _$VenueFromJson(Map<String, dynamic> json) => _Venue(
  id: json['id'] as String,
  name: json['name'] as String,
  address: json['address'] as String,
  city: json['city'] as String,
  district: json['district'] as String?,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  googlePlaceId: json['google_place_id'] as String?,
  notes: json['notes'] as String?,
  status: json['status'] as String? ?? 'pending',
  rejectionNote: json['rejection_note'] as String?,
  addedBy: json['added_by'] as String,
  approvedBy: json['approved_by'] as String?,
  verifiedAt: json['verified_at'] == null
      ? null
      : DateTime.parse(json['verified_at'] as String),
  foodHalalMode: json['food_halal_mode'] as String? ?? 'selected',
  excludedProducts:
      (json['excluded_products'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  criteria:
      (json['criteria'] as List<dynamic>?)
          ?.map((e) => HalalCriteria.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => VenuePhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  foodItems:
      (json['food_items'] as List<dynamic>?)
          ?.map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  avgRating: (json['average_rating'] as num?)?.toDouble(),
  reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
  distance: (json['distance'] as num?)?.toDouble(),
  categoriesStr: json['categories_str'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$VenueToJson(_Venue instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
  'city': instance.city,
  'district': instance.district,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'google_place_id': instance.googlePlaceId,
  'notes': instance.notes,
  'status': instance.status,
  'rejection_note': instance.rejectionNote,
  'added_by': instance.addedBy,
  'approved_by': instance.approvedBy,
  'verified_at': instance.verifiedAt?.toIso8601String(),
  'food_halal_mode': instance.foodHalalMode,
  'excluded_products': instance.excludedProducts,
  'criteria': instance.criteria,
  'photos': instance.photos,
  'food_items': instance.foodItems,
  'average_rating': instance.avgRating,
  'review_count': instance.reviewCount,
  'distance': instance.distance,
  'categories_str': instance.categoriesStr,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

_HalalCriteria _$HalalCriteriaFromJson(Map<String, dynamic> json) =>
    _HalalCriteria(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String,
      labelTr: json['label_tr'] as String,
      labelEn: json['label_en'] as String,
      descriptionTr: json['description_tr'] as String?,
      descriptionEn: json['description_en'] as String?,
    );

Map<String, dynamic> _$HalalCriteriaToJson(_HalalCriteria instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'label_tr': instance.labelTr,
      'label_en': instance.labelEn,
      'description_tr': instance.descriptionTr,
      'description_en': instance.descriptionEn,
    };

_VenuePhoto _$VenuePhotoFromJson(Map<String, dynamic> json) => _VenuePhoto(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  url: json['url'] as String,
  uploadedBy: json['uploaded_by'] as String,
  isPrimary: json['is_primary'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$VenuePhotoToJson(_VenuePhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venue_id': instance.venueId,
      'url': instance.url,
      'uploaded_by': instance.uploadedBy,
      'is_primary': instance.isPrimary,
      'created_at': instance.createdAt?.toIso8601String(),
    };

_FoodCategory _$FoodCategoryFromJson(Map<String, dynamic> json) =>
    _FoodCategory(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String,
      labelTr: json['label_tr'] as String,
      labelEn: json['label_en'] as String,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$FoodCategoryToJson(_FoodCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'label_tr': instance.labelTr,
      'label_en': instance.labelEn,
      'items': instance.items,
    };

_FoodItem _$FoodItemFromJson(Map<String, dynamic> json) => _FoodItem(
  id: (json['id'] as num).toInt(),
  categoryId: (json['category_id'] as num).toInt(),
  key: json['key'] as String,
  labelTr: json['label_tr'] as String,
  labelEn: json['label_en'] as String,
  isCustom: json['is_custom'] as bool? ?? false,
);

Map<String, dynamic> _$FoodItemToJson(_FoodItem instance) => <String, dynamic>{
  'id': instance.id,
  'category_id': instance.categoryId,
  'key': instance.key,
  'label_tr': instance.labelTr,
  'label_en': instance.labelEn,
  'is_custom': instance.isCustom,
};
