// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guide_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GuideApplication {

 String get id;@JsonKey(name: 'user_id') String get userId; String get status; String? get note;@JsonKey(name: 'reviewed_by') String? get reviewedBy;@JsonKey(name: 'reviewed_at') DateTime? get reviewedAt;@JsonKey(name: 'user_name') String? get userName;@JsonKey(name: 'user_email') String? get userEmail;@JsonKey(name: 'referred_by') String? get referredBy;@JsonKey(name: 'referrer_name') String? get referrerName;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of GuideApplication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GuideApplicationCopyWith<GuideApplication> get copyWith => _$GuideApplicationCopyWithImpl<GuideApplication>(this as GuideApplication, _$identity);

  /// Serializes this GuideApplication to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GuideApplication&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&(identical(other.note, note) || other.note == note)&&(identical(other.reviewedBy, reviewedBy) || other.reviewedBy == reviewedBy)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userEmail, userEmail) || other.userEmail == userEmail)&&(identical(other.referredBy, referredBy) || other.referredBy == referredBy)&&(identical(other.referrerName, referrerName) || other.referrerName == referrerName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,status,note,reviewedBy,reviewedAt,userName,userEmail,referredBy,referrerName,createdAt);

@override
String toString() {
  return 'GuideApplication(id: $id, userId: $userId, status: $status, note: $note, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, userName: $userName, userEmail: $userEmail, referredBy: $referredBy, referrerName: $referrerName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $GuideApplicationCopyWith<$Res>  {
  factory $GuideApplicationCopyWith(GuideApplication value, $Res Function(GuideApplication) _then) = _$GuideApplicationCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String status, String? note,@JsonKey(name: 'reviewed_by') String? reviewedBy,@JsonKey(name: 'reviewed_at') DateTime? reviewedAt,@JsonKey(name: 'user_name') String? userName,@JsonKey(name: 'user_email') String? userEmail,@JsonKey(name: 'referred_by') String? referredBy,@JsonKey(name: 'referrer_name') String? referrerName,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$GuideApplicationCopyWithImpl<$Res>
    implements $GuideApplicationCopyWith<$Res> {
  _$GuideApplicationCopyWithImpl(this._self, this._then);

  final GuideApplication _self;
  final $Res Function(GuideApplication) _then;

/// Create a copy of GuideApplication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? status = null,Object? note = freezed,Object? reviewedBy = freezed,Object? reviewedAt = freezed,Object? userName = freezed,Object? userEmail = freezed,Object? referredBy = freezed,Object? referrerName = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,reviewedBy: freezed == reviewedBy ? _self.reviewedBy : reviewedBy // ignore: cast_nullable_to_non_nullable
as String?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,userEmail: freezed == userEmail ? _self.userEmail : userEmail // ignore: cast_nullable_to_non_nullable
as String?,referredBy: freezed == referredBy ? _self.referredBy : referredBy // ignore: cast_nullable_to_non_nullable
as String?,referrerName: freezed == referrerName ? _self.referrerName : referrerName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GuideApplication].
extension GuideApplicationPatterns on GuideApplication {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GuideApplication value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GuideApplication() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GuideApplication value)  $default,){
final _that = this;
switch (_that) {
case _GuideApplication():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GuideApplication value)?  $default,){
final _that = this;
switch (_that) {
case _GuideApplication() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String status,  String? note, @JsonKey(name: 'reviewed_by')  String? reviewedBy, @JsonKey(name: 'reviewed_at')  DateTime? reviewedAt, @JsonKey(name: 'user_name')  String? userName, @JsonKey(name: 'user_email')  String? userEmail, @JsonKey(name: 'referred_by')  String? referredBy, @JsonKey(name: 'referrer_name')  String? referrerName, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GuideApplication() when $default != null:
return $default(_that.id,_that.userId,_that.status,_that.note,_that.reviewedBy,_that.reviewedAt,_that.userName,_that.userEmail,_that.referredBy,_that.referrerName,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String status,  String? note, @JsonKey(name: 'reviewed_by')  String? reviewedBy, @JsonKey(name: 'reviewed_at')  DateTime? reviewedAt, @JsonKey(name: 'user_name')  String? userName, @JsonKey(name: 'user_email')  String? userEmail, @JsonKey(name: 'referred_by')  String? referredBy, @JsonKey(name: 'referrer_name')  String? referrerName, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _GuideApplication():
return $default(_that.id,_that.userId,_that.status,_that.note,_that.reviewedBy,_that.reviewedAt,_that.userName,_that.userEmail,_that.referredBy,_that.referrerName,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId,  String status,  String? note, @JsonKey(name: 'reviewed_by')  String? reviewedBy, @JsonKey(name: 'reviewed_at')  DateTime? reviewedAt, @JsonKey(name: 'user_name')  String? userName, @JsonKey(name: 'user_email')  String? userEmail, @JsonKey(name: 'referred_by')  String? referredBy, @JsonKey(name: 'referrer_name')  String? referrerName, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _GuideApplication() when $default != null:
return $default(_that.id,_that.userId,_that.status,_that.note,_that.reviewedBy,_that.reviewedAt,_that.userName,_that.userEmail,_that.referredBy,_that.referrerName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GuideApplication extends GuideApplication {
  const _GuideApplication({required this.id, @JsonKey(name: 'user_id') required this.userId, this.status = 'pending', this.note, @JsonKey(name: 'reviewed_by') this.reviewedBy, @JsonKey(name: 'reviewed_at') this.reviewedAt, @JsonKey(name: 'user_name') this.userName, @JsonKey(name: 'user_email') this.userEmail, @JsonKey(name: 'referred_by') this.referredBy, @JsonKey(name: 'referrer_name') this.referrerName, @JsonKey(name: 'created_at') this.createdAt}): super._();
  factory _GuideApplication.fromJson(Map<String, dynamic> json) => _$GuideApplicationFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey() final  String status;
@override final  String? note;
@override@JsonKey(name: 'reviewed_by') final  String? reviewedBy;
@override@JsonKey(name: 'reviewed_at') final  DateTime? reviewedAt;
@override@JsonKey(name: 'user_name') final  String? userName;
@override@JsonKey(name: 'user_email') final  String? userEmail;
@override@JsonKey(name: 'referred_by') final  String? referredBy;
@override@JsonKey(name: 'referrer_name') final  String? referrerName;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of GuideApplication
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GuideApplicationCopyWith<_GuideApplication> get copyWith => __$GuideApplicationCopyWithImpl<_GuideApplication>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GuideApplicationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GuideApplication&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&(identical(other.note, note) || other.note == note)&&(identical(other.reviewedBy, reviewedBy) || other.reviewedBy == reviewedBy)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userEmail, userEmail) || other.userEmail == userEmail)&&(identical(other.referredBy, referredBy) || other.referredBy == referredBy)&&(identical(other.referrerName, referrerName) || other.referrerName == referrerName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,status,note,reviewedBy,reviewedAt,userName,userEmail,referredBy,referrerName,createdAt);

@override
String toString() {
  return 'GuideApplication(id: $id, userId: $userId, status: $status, note: $note, reviewedBy: $reviewedBy, reviewedAt: $reviewedAt, userName: $userName, userEmail: $userEmail, referredBy: $referredBy, referrerName: $referrerName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$GuideApplicationCopyWith<$Res> implements $GuideApplicationCopyWith<$Res> {
  factory _$GuideApplicationCopyWith(_GuideApplication value, $Res Function(_GuideApplication) _then) = __$GuideApplicationCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String status, String? note,@JsonKey(name: 'reviewed_by') String? reviewedBy,@JsonKey(name: 'reviewed_at') DateTime? reviewedAt,@JsonKey(name: 'user_name') String? userName,@JsonKey(name: 'user_email') String? userEmail,@JsonKey(name: 'referred_by') String? referredBy,@JsonKey(name: 'referrer_name') String? referrerName,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$GuideApplicationCopyWithImpl<$Res>
    implements _$GuideApplicationCopyWith<$Res> {
  __$GuideApplicationCopyWithImpl(this._self, this._then);

  final _GuideApplication _self;
  final $Res Function(_GuideApplication) _then;

/// Create a copy of GuideApplication
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? status = null,Object? note = freezed,Object? reviewedBy = freezed,Object? reviewedAt = freezed,Object? userName = freezed,Object? userEmail = freezed,Object? referredBy = freezed,Object? referrerName = freezed,Object? createdAt = freezed,}) {
  return _then(_GuideApplication(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,reviewedBy: freezed == reviewedBy ? _self.reviewedBy : reviewedBy // ignore: cast_nullable_to_non_nullable
as String?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,userEmail: freezed == userEmail ? _self.userEmail : userEmail // ignore: cast_nullable_to_non_nullable
as String?,referredBy: freezed == referredBy ? _self.referredBy : referredBy // ignore: cast_nullable_to_non_nullable
as String?,referrerName: freezed == referrerName ? _self.referrerName : referrerName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
