// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'venue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Venue _$VenueFromJson(Map<String, dynamic> json) => _Venue(
  id: json['id'] as String,
  name: json['name'] as String,
  city: json['city'] as String,
  district: json['district'] as String?,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  googlePlaceId: json['google_place_id'] as String?,
  notes: json['notes'] as String?,
  status: json['status'] as String? ?? 'pending',
  rejectionNote: json['rejection_note'] as String?,
  addedBy: json['added_by'] as String,
  addedByName: json['added_by_name'] as String?,
  approvedBy: json['approved_by'] as String?,
  verifiedAt: json['verified_at'] == null
      ? null
      : DateTime.parse(json['verified_at'] as String),
  verificationDueAt: json['verification_due_at'] == null
      ? null
      : DateTime.parse(json['verification_due_at'] as String),
  foodHalalMode: json['food_halal_mode'] as String? ?? 'all',
  excludedProducts:
      (json['excluded_products'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  trustCriteria:
      (json['trust_criteria'] as List<dynamic>?)
          ?.map((e) => TrustCriteria.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  photos:
      (json['photos'] as List<dynamic>?)
          ?.map((e) => VenuePhoto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  categories:
      (json['categories'] as List<dynamic>?)
          ?.map((e) => FoodCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  avgRating: (json['average_rating'] as num?)?.toDouble(),
  reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
  confirmationCount: (json['confirmation_count'] as num?)?.toInt() ?? 0,
  badge: json['badge'] == null
      ? null
      : Badge.fromJson(json['badge'] as Map<String, dynamic>),
  confirmedByMe: json['confirmed_by_me'] as bool?,
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
  'city': instance.city,
  'district': instance.district,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'google_place_id': instance.googlePlaceId,
  'notes': instance.notes,
  'status': instance.status,
  'rejection_note': instance.rejectionNote,
  'added_by': instance.addedBy,
  'added_by_name': instance.addedByName,
  'approved_by': instance.approvedBy,
  'verified_at': instance.verifiedAt?.toIso8601String(),
  'verification_due_at': instance.verificationDueAt?.toIso8601String(),
  'food_halal_mode': instance.foodHalalMode,
  'excluded_products': instance.excludedProducts,
  'trust_criteria': instance.trustCriteria,
  'photos': instance.photos,
  'categories': instance.categories,
  'average_rating': instance.avgRating,
  'review_count': instance.reviewCount,
  'confirmation_count': instance.confirmationCount,
  'badge': instance.badge,
  'confirmed_by_me': instance.confirmedByMe,
  'distance': instance.distance,
  'categories_str': instance.categoriesStr,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};

_TrustCriteria _$TrustCriteriaFromJson(Map<String, dynamic> json) =>
    _TrustCriteria(
      id: (json['id'] as num).toInt(),
      key: json['key'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$TrustCriteriaToJson(_TrustCriteria instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'name': instance.name,
      'description': instance.description,
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
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
    );

Map<String, dynamic> _$FoodCategoryToJson(_FoodCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'name': instance.name,
      'image_url': instance.imageUrl,
    };

_Badge _$BadgeFromJson(Map<String, dynamic> json) => _Badge(
  level: json['level'] as String,
  count: (json['count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$BadgeToJson(_Badge instance) => <String, dynamic>{
  'level': instance.level,
  'count': instance.count,
};
