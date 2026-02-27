// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Review _$ReviewFromJson(Map<String, dynamic> json) => _Review(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  userId: json['user_id'] as String,
  rating: (json['rating'] as num).toInt(),
  comment: json['comment'] as String?,
  userName: json['user_name'] as String?,
  userAvatar: json['user_avatar'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$ReviewToJson(_Review instance) => <String, dynamic>{
  'id': instance.id,
  'venue_id': instance.venueId,
  'user_id': instance.userId,
  'rating': instance.rating,
  'comment': instance.comment,
  'user_name': instance.userName,
  'user_avatar': instance.userAvatar,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
