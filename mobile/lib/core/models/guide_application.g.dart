// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_application.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GuideApplication _$GuideApplicationFromJson(Map<String, dynamic> json) =>
    _GuideApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      city: json['city'] as String?,
      status: json['status'] as String? ?? 'pending',
      note: json['note'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      termsAcceptedAt: json['terms_accepted_at'] == null
          ? null
          : DateTime.parse(json['terms_accepted_at'] as String),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$GuideApplicationToJson(_GuideApplication instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'city': instance.city,
      'status': instance.status,
      'note': instance.note,
      'reviewed_by': instance.reviewedBy,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
      'terms_accepted_at': instance.termsAcceptedAt?.toIso8601String(),
      'user_name': instance.userName,
      'user_email': instance.userEmail,
      'created_at': instance.createdAt?.toIso8601String(),
    };
