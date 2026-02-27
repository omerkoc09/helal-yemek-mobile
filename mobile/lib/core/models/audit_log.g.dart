// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuditLog _$AuditLogFromJson(Map<String, dynamic> json) => _AuditLog(
  id: json['id'] as String,
  adminId: json['admin_id'] as String,
  action: json['action'] as String,
  targetType: json['target_type'] as String,
  targetId: json['target_id'] as String,
  note: json['note'] as String?,
  adminName: json['admin_name'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AuditLogToJson(_AuditLog instance) => <String, dynamic>{
  'id': instance.id,
  'admin_id': instance.adminId,
  'action': instance.action,
  'target_type': instance.targetType,
  'target_id': instance.targetId,
  'note': instance.note,
  'admin_name': instance.adminName,
  'created_at': instance.createdAt?.toIso8601String(),
};
