// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'correction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Correction _$CorrectionFromJson(Map<String, dynamic> json) => _Correction(
  id: json['id'] as String,
  venueId: json['venue_id'] as String,
  suggestedBy: json['suggested_by'] as String,
  fieldName: json['field_name'] as String,
  oldValue: json['old_value'] as String?,
  newValue: json['new_value'] as String,
  status: json['status'] as String? ?? 'pending',
  reviewedBy: json['reviewed_by'] as String?,
  reviewedAt: json['reviewed_at'] == null
      ? null
      : DateTime.parse(json['reviewed_at'] as String),
  note: json['note'] as String?,
  venueName: json['venue_name'] as String?,
  suggestedByName: json['suggested_by_name'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$CorrectionToJson(_Correction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'venue_id': instance.venueId,
      'suggested_by': instance.suggestedBy,
      'field_name': instance.fieldName,
      'old_value': instance.oldValue,
      'new_value': instance.newValue,
      'status': instance.status,
      'reviewed_by': instance.reviewedBy,
      'reviewed_at': instance.reviewedAt?.toIso8601String(),
      'note': instance.note,
      'venue_name': instance.venueName,
      'suggested_by_name': instance.suggestedByName,
      'created_at': instance.createdAt?.toIso8601String(),
    };
