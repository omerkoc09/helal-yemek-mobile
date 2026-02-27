// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'correction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Correction {

 String get id;@JsonKey(name: 'venue_id') String get venueId;@JsonKey(name: 'suggested_by') String get suggestedBy;@JsonKey(name: 'field_name') String get fieldName;@JsonKey(name: 'old_value') String? get oldValue;@JsonKey(name: 'new_value') String get newValue; String get status;@JsonKey(name: 'reviewed_by') String? get reviewedBy;@JsonKey(name: 'reviewed_at') DateTime? get reviewedAt; String? get note;@JsonKey(name: 'venue_name') String? get venueName;@JsonKey(name: 'suggested_by_name') String? get suggestedByName;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of Correction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CorrectionCopyWith<Correction> get copyWith => _$CorrectionCopyWithImpl<Correction>(this as Correction, _$identity);

  /// Serializes this Correction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Correction&&(identical(other.id, id) || other.id == id)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.suggestedBy, suggestedBy) || other.suggestedBy == suggestedBy)&&(identical(other.fieldName, fieldName) || other.fieldName == fieldName)&&(identical(other.oldValue, oldValue) || other.oldValue == oldValue)&&(identical(other.newValue, newValue) || other.newValue == newValue)&&(identical(other.status, status) || other.status == status)&&(identical(other.reviewedBy, reviewedBy) || other.reviewedBy == reviewedBy)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.note, note) || other.note == note)&&(identical(other.venueName, venueName) || other.venueName == venueName)&&(identical(other.suggestedByName, suggestedByName) || other.suggestedByName == suggestedByName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,venueId,suggestedBy,fieldName,oldValue,newValue,status,reviewedBy,reviewedAt,note,venueName,suggestedByName,createdAt);

@override
String toString() {
  return 'Correction(id: $id, venueId: $venueId, suggestedBy: $suggestedBy, fieldName: $fieldName, oldValue: $oldValue, newValue: $newValue, status: $status, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, note: $note, venueName: $venueName, suggestedByName: $suggestedByName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $CorrectionCopyWith<$Res>  {
  factory $CorrectionCopyWith(Correction value, $Res Function(Correction) _then) = _$CorrectionCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'venue_id') String venueId,@JsonKey(name: 'suggested_by') String suggestedBy,@JsonKey(name: 'field_name') String fieldName,@JsonKey(name: 'old_value') String? oldValue,@JsonKey(name: 'new_value') String newValue, String status,@JsonKey(name: 'reviewed_by') String? reviewedBy,@JsonKey(name: 'reviewed_at') DateTime? reviewedAt, String? note,@JsonKey(name: 'venue_name') String? venueName,@JsonKey(name: 'suggested_by_name') String? suggestedByName,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$CorrectionCopyWithImpl<$Res>
    implements $CorrectionCopyWith<$Res> {
  _$CorrectionCopyWithImpl(this._self, this._then);

  final Correction _self;
  final $Res Function(Correction) _then;

/// Create a copy of Correction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? venueId = null,Object? suggestedBy = null,Object? fieldName = null,Object? oldValue = freezed,Object? newValue = null,Object? status = null,Object? reviewedBy = freezed,Object? reviewedAt = freezed,Object? note = freezed,Object? venueName = freezed,Object? suggestedByName = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,suggestedBy: null == suggestedBy ? _self.suggestedBy : suggestedBy // ignore: cast_nullable_to_non_nullable
as String,fieldName: null == fieldName ? _self.fieldName : fieldName // ignore: cast_nullable_to_non_nullable
as String,oldValue: freezed == oldValue ? _self.oldValue : oldValue // ignore: cast_nullable_to_non_nullable
as String?,newValue: null == newValue ? _self.newValue : newValue // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reviewedBy: freezed == reviewedBy ? _self.reviewedBy : reviewedBy // ignore: cast_nullable_to_non_nullable
as String?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,venueName: freezed == venueName ? _self.venueName : venueName // ignore: cast_nullable_to_non_nullable
as String?,suggestedByName: freezed == suggestedByName ? _self.suggestedByName : suggestedByName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Correction].
extension CorrectionPatterns on Correction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Correction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Correction() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Correction value)  $default,){
final _that = this;
switch (_that) {
case _Correction():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Correction value)?  $default,){
final _that = this;
switch (_that) {
case _Correction() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'venue_id')  String venueId, @JsonKey(name: 'suggested_by')  String suggestedBy, @JsonKey(name: 'field_name')  String fieldName, @JsonKey(name: 'old_value')  String? oldValue, @JsonKey(name: 'new_value')  String newValue,  String status, @JsonKey(name: 'reviewed_by')  String? reviewedBy, @JsonKey(name: 'reviewed_at')  DateTime? reviewedAt,  String? note, @JsonKey(name: 'venue_name')  String? venueName, @JsonKey(name: 'suggested_by_name')  String? suggestedByName, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Correction() when $default != null:
return $default(_that.id,_that.venueId,_that.suggestedBy,_that.fieldName,_that.oldValue,_that.newValue,_that.status,_that.reviewedBy,_that.reviewedAt,_that.note,_that.venueName,_that.suggestedByName,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'venue_id')  String venueId, @JsonKey(name: 'suggested_by')  String suggestedBy, @JsonKey(name: 'field_name')  String fieldName, @JsonKey(name: 'old_value')  String? oldValue, @JsonKey(name: 'new_value')  String newValue,  String status, @JsonKey(name: 'reviewed_by')  String? reviewedBy, @JsonKey(name: 'reviewed_at')  DateTime? reviewedAt,  String? note, @JsonKey(name: 'venue_name')  String? venueName, @JsonKey(name: 'suggested_by_name')  String? suggestedByName, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Correction():
return $default(_that.id,_that.venueId,_that.suggestedBy,_that.fieldName,_that.oldValue,_that.newValue,_that.status,_that.reviewedBy,_that.reviewedAt,_that.note,_that.venueName,_that.suggestedByName,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'venue_id')  String venueId, @JsonKey(name: 'suggested_by')  String suggestedBy, @JsonKey(name: 'field_name')  String fieldName, @JsonKey(name: 'old_value')  String? oldValue, @JsonKey(name: 'new_value')  String newValue,  String status, @JsonKey(name: 'reviewed_by')  String? reviewedBy, @JsonKey(name: 'reviewed_at')  DateTime? reviewedAt,  String? note, @JsonKey(name: 'venue_name')  String? venueName, @JsonKey(name: 'suggested_by_name')  String? suggestedByName, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Correction() when $default != null:
return $default(_that.id,_that.venueId,_that.suggestedBy,_that.fieldName,_that.oldValue,_that.newValue,_that.status,_that.reviewedBy,_that.reviewedAt,_that.note,_that.venueName,_that.suggestedByName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Correction implements Correction {
  const _Correction({required this.id, @JsonKey(name: 'venue_id') required this.venueId, @JsonKey(name: 'suggested_by') required this.suggestedBy, @JsonKey(name: 'field_name') required this.fieldName, @JsonKey(name: 'old_value') this.oldValue, @JsonKey(name: 'new_value') required this.newValue, this.status = 'pending', @JsonKey(name: 'reviewed_by') this.reviewedBy, @JsonKey(name: 'reviewed_at') this.reviewedAt, this.note, @JsonKey(name: 'venue_name') this.venueName, @JsonKey(name: 'suggested_by_name') this.suggestedByName, @JsonKey(name: 'created_at') this.createdAt});
  factory _Correction.fromJson(Map<String, dynamic> json) => _$CorrectionFromJson(json);

@override final  String id;
@override@JsonKey(name: 'venue_id') final  String venueId;
@override@JsonKey(name: 'suggested_by') final  String suggestedBy;
@override@JsonKey(name: 'field_name') final  String fieldName;
@override@JsonKey(name: 'old_value') final  String? oldValue;
@override@JsonKey(name: 'new_value') final  String newValue;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'reviewed_by') final  String? reviewedBy;
@override@JsonKey(name: 'reviewed_at') final  DateTime? reviewedAt;
@override final  String? note;
@override@JsonKey(name: 'venue_name') final  String? venueName;
@override@JsonKey(name: 'suggested_by_name') final  String? suggestedByName;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of Correction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CorrectionCopyWith<_Correction> get copyWith => __$CorrectionCopyWithImpl<_Correction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CorrectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Correction&&(identical(other.id, id) || other.id == id)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.suggestedBy, suggestedBy) || other.suggestedBy == suggestedBy)&&(identical(other.fieldName, fieldName) || other.fieldName == fieldName)&&(identical(other.oldValue, oldValue) || other.oldValue == oldValue)&&(identical(other.newValue, newValue) || other.newValue == newValue)&&(identical(other.status, status) || other.status == status)&&(identical(other.reviewedBy, reviewedBy) || other.reviewedBy == reviewedBy)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.note, note) || other.note == note)&&(identical(other.venueName, venueName) || other.venueName == venueName)&&(identical(other.suggestedByName, suggestedByName) || other.suggestedByName == suggestedByName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,venueId,suggestedBy,fieldName,oldValue,newValue,status,reviewedBy,reviewedAt,note,venueName,suggestedByName,createdAt);

@override
String toString() {
  return 'Correction(id: $id, venueId: $venueId, suggestedBy: $suggestedBy, fieldName: $fieldName, oldValue: $oldValue, newValue: $newValue, status: $status, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, note: $note, venueName: $venueName, suggestedByName: $suggestedByName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$CorrectionCopyWith<$Res> implements $CorrectionCopyWith<$Res> {
  factory _$CorrectionCopyWith(_Correction value, $Res Function(_Correction) _then) = __$CorrectionCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'venue_id') String venueId,@JsonKey(name: 'suggested_by') String suggestedBy,@JsonKey(name: 'field_name') String fieldName,@JsonKey(name: 'old_value') String? oldValue,@JsonKey(name: 'new_value') String newValue, String status,@JsonKey(name: 'reviewed_by') String? reviewedBy,@JsonKey(name: 'reviewed_at') DateTime? reviewedAt, String? note,@JsonKey(name: 'venue_name') String? venueName,@JsonKey(name: 'suggested_by_name') String? suggestedByName,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$CorrectionCopyWithImpl<$Res>
    implements _$CorrectionCopyWith<$Res> {
  __$CorrectionCopyWithImpl(this._self, this._then);

  final _Correction _self;
  final $Res Function(_Correction) _then;

/// Create a copy of Correction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? venueId = null,Object? suggestedBy = null,Object? fieldName = null,Object? oldValue = freezed,Object? newValue = null,Object? status = null,Object? reviewedBy = freezed,Object? reviewedAt = freezed,Object? note = freezed,Object? venueName = freezed,Object? suggestedByName = freezed,Object? createdAt = freezed,}) {
  return _then(_Correction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,suggestedBy: null == suggestedBy ? _self.suggestedBy : suggestedBy // ignore: cast_nullable_to_non_nullable
as String,fieldName: null == fieldName ? _self.fieldName : fieldName // ignore: cast_nullable_to_non_nullable
as String,oldValue: freezed == oldValue ? _self.oldValue : oldValue // ignore: cast_nullable_to_non_nullable
as String?,newValue: null == newValue ? _self.newValue : newValue // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reviewedBy: freezed == reviewedBy ? _self.reviewedBy : reviewedBy // ignore: cast_nullable_to_non_nullable
as String?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,venueName: freezed == venueName ? _self.venueName : venueName // ignore: cast_nullable_to_non_nullable
as String?,suggestedByName: freezed == suggestedByName ? _self.suggestedByName : suggestedByName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
