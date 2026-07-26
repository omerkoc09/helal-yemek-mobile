// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'venue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Venue {

 String get id; String get name; String get city; String? get district; double get latitude; double get longitude;@JsonKey(name: 'google_place_id') String? get googlePlaceId; String? get notes; String get status;@JsonKey(name: 'rejection_note') String? get rejectionNote;@JsonKey(name: 'added_by') String get addedBy;@JsonKey(name: 'added_by_name') String? get addedByName;@JsonKey(name: 'approved_by') String? get approvedBy;@JsonKey(name: 'verified_at') DateTime? get verifiedAt;@JsonKey(name: 'verification_due_at') DateTime? get verificationDueAt;@JsonKey(name: 'food_halal_mode') String get foodHalalMode;@JsonKey(name: 'excluded_products') List<String> get excludedProducts;@JsonKey(name: 'trust_criteria') List<TrustCriteria> get trustCriteria; List<VenuePhoto> get photos;@JsonKey(name: 'food_items') List<FoodItem> get foodItems;@JsonKey(name: 'average_rating') double? get avgRating;@JsonKey(name: 'review_count') int get reviewCount;@JsonKey(name: 'confirmation_count') int get confirmationCount; Badge? get badge;@JsonKey(name: 'confirmed_by_me') bool? get confirmedByMe; double? get distance;@JsonKey(name: 'categories_str') String? get categoriesStr;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VenueCopyWith<Venue> get copyWith => _$VenueCopyWithImpl<Venue>(this as Venue, _$identity);

  /// Serializes this Venue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Venue&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.city, city) || other.city == city)&&(identical(other.district, district) || other.district == district)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.googlePlaceId, googlePlaceId) || other.googlePlaceId == googlePlaceId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status)&&(identical(other.rejectionNote, rejectionNote) || other.rejectionNote == rejectionNote)&&(identical(other.addedBy, addedBy) || other.addedBy == addedBy)&&(identical(other.addedByName, addedByName) || other.addedByName == addedByName)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.verificationDueAt, verificationDueAt) || other.verificationDueAt == verificationDueAt)&&(identical(other.foodHalalMode, foodHalalMode) || other.foodHalalMode == foodHalalMode)&&const DeepCollectionEquality().equals(other.excludedProducts, excludedProducts)&&const DeepCollectionEquality().equals(other.trustCriteria, trustCriteria)&&const DeepCollectionEquality().equals(other.photos, photos)&&const DeepCollectionEquality().equals(other.foodItems, foodItems)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.confirmationCount, confirmationCount) || other.confirmationCount == confirmationCount)&&(identical(other.badge, badge) || other.badge == badge)&&(identical(other.confirmedByMe, confirmedByMe) || other.confirmedByMe == confirmedByMe)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.categoriesStr, categoriesStr) || other.categoriesStr == categoriesStr)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,city,district,latitude,longitude,googlePlaceId,notes,status,rejectionNote,addedBy,addedByName,approvedBy,verifiedAt,verificationDueAt,foodHalalMode,const DeepCollectionEquality().hash(excludedProducts),const DeepCollectionEquality().hash(trustCriteria),const DeepCollectionEquality().hash(photos),const DeepCollectionEquality().hash(foodItems),avgRating,reviewCount,confirmationCount,badge,confirmedByMe,distance,categoriesStr,createdAt,updatedAt]);

@override
String toString() {
  return 'Venue(id: $id, name: $name, city: $city, district: $district, latitude: $latitude, longitude: $longitude, googlePlaceId: $googlePlaceId, notes: $notes, status: $status, rejectionNote: $rejectionNote, addedBy: $addedBy, addedByName: $addedByName, approvedBy: $approvedBy, verifiedAt: $verifiedAt, verificationDueAt: $verificationDueAt, foodHalalMode: $foodHalalMode, excludedProducts: $excludedProducts, trustCriteria: $trustCriteria, photos: $photos, foodItems: $foodItems, avgRating: $avgRating, reviewCount: $reviewCount, confirmationCount: $confirmationCount, badge: $badge, confirmedByMe: $confirmedByMe, distance: $distance, categoriesStr: $categoriesStr, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $VenueCopyWith<$Res>  {
  factory $VenueCopyWith(Venue value, $Res Function(Venue) _then) = _$VenueCopyWithImpl;
@useResult
$Res call({
 String id, String name, String city, String? district, double latitude, double longitude,@JsonKey(name: 'google_place_id') String? googlePlaceId, String? notes, String status,@JsonKey(name: 'rejection_note') String? rejectionNote,@JsonKey(name: 'added_by') String addedBy,@JsonKey(name: 'added_by_name') String? addedByName,@JsonKey(name: 'approved_by') String? approvedBy,@JsonKey(name: 'verified_at') DateTime? verifiedAt,@JsonKey(name: 'verification_due_at') DateTime? verificationDueAt,@JsonKey(name: 'food_halal_mode') String foodHalalMode,@JsonKey(name: 'excluded_products') List<String> excludedProducts,@JsonKey(name: 'trust_criteria') List<TrustCriteria> trustCriteria, List<VenuePhoto> photos,@JsonKey(name: 'food_items') List<FoodItem> foodItems,@JsonKey(name: 'average_rating') double? avgRating,@JsonKey(name: 'review_count') int reviewCount,@JsonKey(name: 'confirmation_count') int confirmationCount, Badge? badge,@JsonKey(name: 'confirmed_by_me') bool? confirmedByMe, double? distance,@JsonKey(name: 'categories_str') String? categoriesStr,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});


$BadgeCopyWith<$Res>? get badge;

}
/// @nodoc
class _$VenueCopyWithImpl<$Res>
    implements $VenueCopyWith<$Res> {
  _$VenueCopyWithImpl(this._self, this._then);

  final Venue _self;
  final $Res Function(Venue) _then;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? city = null,Object? district = freezed,Object? latitude = null,Object? longitude = null,Object? googlePlaceId = freezed,Object? notes = freezed,Object? status = null,Object? rejectionNote = freezed,Object? addedBy = null,Object? addedByName = freezed,Object? approvedBy = freezed,Object? verifiedAt = freezed,Object? verificationDueAt = freezed,Object? foodHalalMode = null,Object? excludedProducts = null,Object? trustCriteria = null,Object? photos = null,Object? foodItems = null,Object? avgRating = freezed,Object? reviewCount = null,Object? confirmationCount = null,Object? badge = freezed,Object? confirmedByMe = freezed,Object? distance = freezed,Object? categoriesStr = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,district: freezed == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String?,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,googlePlaceId: freezed == googlePlaceId ? _self.googlePlaceId : googlePlaceId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,rejectionNote: freezed == rejectionNote ? _self.rejectionNote : rejectionNote // ignore: cast_nullable_to_non_nullable
as String?,addedBy: null == addedBy ? _self.addedBy : addedBy // ignore: cast_nullable_to_non_nullable
as String,addedByName: freezed == addedByName ? _self.addedByName : addedByName // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,verificationDueAt: freezed == verificationDueAt ? _self.verificationDueAt : verificationDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,foodHalalMode: null == foodHalalMode ? _self.foodHalalMode : foodHalalMode // ignore: cast_nullable_to_non_nullable
as String,excludedProducts: null == excludedProducts ? _self.excludedProducts : excludedProducts // ignore: cast_nullable_to_non_nullable
as List<String>,trustCriteria: null == trustCriteria ? _self.trustCriteria : trustCriteria // ignore: cast_nullable_to_non_nullable
as List<TrustCriteria>,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<VenuePhoto>,foodItems: null == foodItems ? _self.foodItems : foodItems // ignore: cast_nullable_to_non_nullable
as List<FoodItem>,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,confirmationCount: null == confirmationCount ? _self.confirmationCount : confirmationCount // ignore: cast_nullable_to_non_nullable
as int,badge: freezed == badge ? _self.badge : badge // ignore: cast_nullable_to_non_nullable
as Badge?,confirmedByMe: freezed == confirmedByMe ? _self.confirmedByMe : confirmedByMe // ignore: cast_nullable_to_non_nullable
as bool?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,categoriesStr: freezed == categoriesStr ? _self.categoriesStr : categoriesStr // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BadgeCopyWith<$Res>? get badge {
    if (_self.badge == null) {
    return null;
  }

  return $BadgeCopyWith<$Res>(_self.badge!, (value) {
    return _then(_self.copyWith(badge: value));
  });
}
}


/// Adds pattern-matching-related methods to [Venue].
extension VenuePatterns on Venue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Venue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Venue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Venue value)  $default,){
final _that = this;
switch (_that) {
case _Venue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Venue value)?  $default,){
final _that = this;
switch (_that) {
case _Venue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String city,  String? district,  double latitude,  double longitude, @JsonKey(name: 'google_place_id')  String? googlePlaceId,  String? notes,  String status, @JsonKey(name: 'rejection_note')  String? rejectionNote, @JsonKey(name: 'added_by')  String addedBy, @JsonKey(name: 'added_by_name')  String? addedByName, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'verified_at')  DateTime? verifiedAt, @JsonKey(name: 'verification_due_at')  DateTime? verificationDueAt, @JsonKey(name: 'food_halal_mode')  String foodHalalMode, @JsonKey(name: 'excluded_products')  List<String> excludedProducts, @JsonKey(name: 'trust_criteria')  List<TrustCriteria> trustCriteria,  List<VenuePhoto> photos, @JsonKey(name: 'food_items')  List<FoodItem> foodItems, @JsonKey(name: 'average_rating')  double? avgRating, @JsonKey(name: 'review_count')  int reviewCount, @JsonKey(name: 'confirmation_count')  int confirmationCount,  Badge? badge, @JsonKey(name: 'confirmed_by_me')  bool? confirmedByMe,  double? distance, @JsonKey(name: 'categories_str')  String? categoriesStr, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Venue() when $default != null:
return $default(_that.id,_that.name,_that.city,_that.district,_that.latitude,_that.longitude,_that.googlePlaceId,_that.notes,_that.status,_that.rejectionNote,_that.addedBy,_that.addedByName,_that.approvedBy,_that.verifiedAt,_that.verificationDueAt,_that.foodHalalMode,_that.excludedProducts,_that.trustCriteria,_that.photos,_that.foodItems,_that.avgRating,_that.reviewCount,_that.confirmationCount,_that.badge,_that.confirmedByMe,_that.distance,_that.categoriesStr,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String city,  String? district,  double latitude,  double longitude, @JsonKey(name: 'google_place_id')  String? googlePlaceId,  String? notes,  String status, @JsonKey(name: 'rejection_note')  String? rejectionNote, @JsonKey(name: 'added_by')  String addedBy, @JsonKey(name: 'added_by_name')  String? addedByName, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'verified_at')  DateTime? verifiedAt, @JsonKey(name: 'verification_due_at')  DateTime? verificationDueAt, @JsonKey(name: 'food_halal_mode')  String foodHalalMode, @JsonKey(name: 'excluded_products')  List<String> excludedProducts, @JsonKey(name: 'trust_criteria')  List<TrustCriteria> trustCriteria,  List<VenuePhoto> photos, @JsonKey(name: 'food_items')  List<FoodItem> foodItems, @JsonKey(name: 'average_rating')  double? avgRating, @JsonKey(name: 'review_count')  int reviewCount, @JsonKey(name: 'confirmation_count')  int confirmationCount,  Badge? badge, @JsonKey(name: 'confirmed_by_me')  bool? confirmedByMe,  double? distance, @JsonKey(name: 'categories_str')  String? categoriesStr, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Venue():
return $default(_that.id,_that.name,_that.city,_that.district,_that.latitude,_that.longitude,_that.googlePlaceId,_that.notes,_that.status,_that.rejectionNote,_that.addedBy,_that.addedByName,_that.approvedBy,_that.verifiedAt,_that.verificationDueAt,_that.foodHalalMode,_that.excludedProducts,_that.trustCriteria,_that.photos,_that.foodItems,_that.avgRating,_that.reviewCount,_that.confirmationCount,_that.badge,_that.confirmedByMe,_that.distance,_that.categoriesStr,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String city,  String? district,  double latitude,  double longitude, @JsonKey(name: 'google_place_id')  String? googlePlaceId,  String? notes,  String status, @JsonKey(name: 'rejection_note')  String? rejectionNote, @JsonKey(name: 'added_by')  String addedBy, @JsonKey(name: 'added_by_name')  String? addedByName, @JsonKey(name: 'approved_by')  String? approvedBy, @JsonKey(name: 'verified_at')  DateTime? verifiedAt, @JsonKey(name: 'verification_due_at')  DateTime? verificationDueAt, @JsonKey(name: 'food_halal_mode')  String foodHalalMode, @JsonKey(name: 'excluded_products')  List<String> excludedProducts, @JsonKey(name: 'trust_criteria')  List<TrustCriteria> trustCriteria,  List<VenuePhoto> photos, @JsonKey(name: 'food_items')  List<FoodItem> foodItems, @JsonKey(name: 'average_rating')  double? avgRating, @JsonKey(name: 'review_count')  int reviewCount, @JsonKey(name: 'confirmation_count')  int confirmationCount,  Badge? badge, @JsonKey(name: 'confirmed_by_me')  bool? confirmedByMe,  double? distance, @JsonKey(name: 'categories_str')  String? categoriesStr, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Venue() when $default != null:
return $default(_that.id,_that.name,_that.city,_that.district,_that.latitude,_that.longitude,_that.googlePlaceId,_that.notes,_that.status,_that.rejectionNote,_that.addedBy,_that.addedByName,_that.approvedBy,_that.verifiedAt,_that.verificationDueAt,_that.foodHalalMode,_that.excludedProducts,_that.trustCriteria,_that.photos,_that.foodItems,_that.avgRating,_that.reviewCount,_that.confirmationCount,_that.badge,_that.confirmedByMe,_that.distance,_that.categoriesStr,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Venue extends Venue {
  const _Venue({required this.id, required this.name, required this.city, this.district, required this.latitude, required this.longitude, @JsonKey(name: 'google_place_id') this.googlePlaceId, this.notes, this.status = 'pending', @JsonKey(name: 'rejection_note') this.rejectionNote, @JsonKey(name: 'added_by') required this.addedBy, @JsonKey(name: 'added_by_name') this.addedByName, @JsonKey(name: 'approved_by') this.approvedBy, @JsonKey(name: 'verified_at') this.verifiedAt, @JsonKey(name: 'verification_due_at') this.verificationDueAt, @JsonKey(name: 'food_halal_mode') this.foodHalalMode = 'selected', @JsonKey(name: 'excluded_products') final  List<String> excludedProducts = const [], @JsonKey(name: 'trust_criteria') final  List<TrustCriteria> trustCriteria = const [], final  List<VenuePhoto> photos = const [], @JsonKey(name: 'food_items') final  List<FoodItem> foodItems = const [], @JsonKey(name: 'average_rating') this.avgRating, @JsonKey(name: 'review_count') this.reviewCount = 0, @JsonKey(name: 'confirmation_count') this.confirmationCount = 0, this.badge, @JsonKey(name: 'confirmed_by_me') this.confirmedByMe, this.distance, @JsonKey(name: 'categories_str') this.categoriesStr, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt}): _excludedProducts = excludedProducts,_trustCriteria = trustCriteria,_photos = photos,_foodItems = foodItems,super._();
  factory _Venue.fromJson(Map<String, dynamic> json) => _$VenueFromJson(json);

@override final  String id;
@override final  String name;
@override final  String city;
@override final  String? district;
@override final  double latitude;
@override final  double longitude;
@override@JsonKey(name: 'google_place_id') final  String? googlePlaceId;
@override final  String? notes;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'rejection_note') final  String? rejectionNote;
@override@JsonKey(name: 'added_by') final  String addedBy;
@override@JsonKey(name: 'added_by_name') final  String? addedByName;
@override@JsonKey(name: 'approved_by') final  String? approvedBy;
@override@JsonKey(name: 'verified_at') final  DateTime? verifiedAt;
@override@JsonKey(name: 'verification_due_at') final  DateTime? verificationDueAt;
@override@JsonKey(name: 'food_halal_mode') final  String foodHalalMode;
 final  List<String> _excludedProducts;
@override@JsonKey(name: 'excluded_products') List<String> get excludedProducts {
  if (_excludedProducts is EqualUnmodifiableListView) return _excludedProducts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_excludedProducts);
}

 final  List<TrustCriteria> _trustCriteria;
@override@JsonKey(name: 'trust_criteria') List<TrustCriteria> get trustCriteria {
  if (_trustCriteria is EqualUnmodifiableListView) return _trustCriteria;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trustCriteria);
}

 final  List<VenuePhoto> _photos;
@override@JsonKey() List<VenuePhoto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

 final  List<FoodItem> _foodItems;
@override@JsonKey(name: 'food_items') List<FoodItem> get foodItems {
  if (_foodItems is EqualUnmodifiableListView) return _foodItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_foodItems);
}

@override@JsonKey(name: 'average_rating') final  double? avgRating;
@override@JsonKey(name: 'review_count') final  int reviewCount;
@override@JsonKey(name: 'confirmation_count') final  int confirmationCount;
@override final  Badge? badge;
@override@JsonKey(name: 'confirmed_by_me') final  bool? confirmedByMe;
@override final  double? distance;
@override@JsonKey(name: 'categories_str') final  String? categoriesStr;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VenueCopyWith<_Venue> get copyWith => __$VenueCopyWithImpl<_Venue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VenueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Venue&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.city, city) || other.city == city)&&(identical(other.district, district) || other.district == district)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.googlePlaceId, googlePlaceId) || other.googlePlaceId == googlePlaceId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status)&&(identical(other.rejectionNote, rejectionNote) || other.rejectionNote == rejectionNote)&&(identical(other.addedBy, addedBy) || other.addedBy == addedBy)&&(identical(other.addedByName, addedByName) || other.addedByName == addedByName)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.verificationDueAt, verificationDueAt) || other.verificationDueAt == verificationDueAt)&&(identical(other.foodHalalMode, foodHalalMode) || other.foodHalalMode == foodHalalMode)&&const DeepCollectionEquality().equals(other._excludedProducts, _excludedProducts)&&const DeepCollectionEquality().equals(other._trustCriteria, _trustCriteria)&&const DeepCollectionEquality().equals(other._photos, _photos)&&const DeepCollectionEquality().equals(other._foodItems, _foodItems)&&(identical(other.avgRating, avgRating) || other.avgRating == avgRating)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.confirmationCount, confirmationCount) || other.confirmationCount == confirmationCount)&&(identical(other.badge, badge) || other.badge == badge)&&(identical(other.confirmedByMe, confirmedByMe) || other.confirmedByMe == confirmedByMe)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.categoriesStr, categoriesStr) || other.categoriesStr == categoriesStr)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,city,district,latitude,longitude,googlePlaceId,notes,status,rejectionNote,addedBy,addedByName,approvedBy,verifiedAt,verificationDueAt,foodHalalMode,const DeepCollectionEquality().hash(_excludedProducts),const DeepCollectionEquality().hash(_trustCriteria),const DeepCollectionEquality().hash(_photos),const DeepCollectionEquality().hash(_foodItems),avgRating,reviewCount,confirmationCount,badge,confirmedByMe,distance,categoriesStr,createdAt,updatedAt]);

@override
String toString() {
  return 'Venue(id: $id, name: $name, city: $city, district: $district, latitude: $latitude, longitude: $longitude, googlePlaceId: $googlePlaceId, notes: $notes, status: $status, rejectionNote: $rejectionNote, addedBy: $addedBy, addedByName: $addedByName, approvedBy: $approvedBy, verifiedAt: $verifiedAt, verificationDueAt: $verificationDueAt, foodHalalMode: $foodHalalMode, excludedProducts: $excludedProducts, trustCriteria: $trustCriteria, photos: $photos, foodItems: $foodItems, avgRating: $avgRating, reviewCount: $reviewCount, confirmationCount: $confirmationCount, badge: $badge, confirmedByMe: $confirmedByMe, distance: $distance, categoriesStr: $categoriesStr, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$VenueCopyWith<$Res> implements $VenueCopyWith<$Res> {
  factory _$VenueCopyWith(_Venue value, $Res Function(_Venue) _then) = __$VenueCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String city, String? district, double latitude, double longitude,@JsonKey(name: 'google_place_id') String? googlePlaceId, String? notes, String status,@JsonKey(name: 'rejection_note') String? rejectionNote,@JsonKey(name: 'added_by') String addedBy,@JsonKey(name: 'added_by_name') String? addedByName,@JsonKey(name: 'approved_by') String? approvedBy,@JsonKey(name: 'verified_at') DateTime? verifiedAt,@JsonKey(name: 'verification_due_at') DateTime? verificationDueAt,@JsonKey(name: 'food_halal_mode') String foodHalalMode,@JsonKey(name: 'excluded_products') List<String> excludedProducts,@JsonKey(name: 'trust_criteria') List<TrustCriteria> trustCriteria, List<VenuePhoto> photos,@JsonKey(name: 'food_items') List<FoodItem> foodItems,@JsonKey(name: 'average_rating') double? avgRating,@JsonKey(name: 'review_count') int reviewCount,@JsonKey(name: 'confirmation_count') int confirmationCount, Badge? badge,@JsonKey(name: 'confirmed_by_me') bool? confirmedByMe, double? distance,@JsonKey(name: 'categories_str') String? categoriesStr,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});


@override $BadgeCopyWith<$Res>? get badge;

}
/// @nodoc
class __$VenueCopyWithImpl<$Res>
    implements _$VenueCopyWith<$Res> {
  __$VenueCopyWithImpl(this._self, this._then);

  final _Venue _self;
  final $Res Function(_Venue) _then;

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? city = null,Object? district = freezed,Object? latitude = null,Object? longitude = null,Object? googlePlaceId = freezed,Object? notes = freezed,Object? status = null,Object? rejectionNote = freezed,Object? addedBy = null,Object? addedByName = freezed,Object? approvedBy = freezed,Object? verifiedAt = freezed,Object? verificationDueAt = freezed,Object? foodHalalMode = null,Object? excludedProducts = null,Object? trustCriteria = null,Object? photos = null,Object? foodItems = null,Object? avgRating = freezed,Object? reviewCount = null,Object? confirmationCount = null,Object? badge = freezed,Object? confirmedByMe = freezed,Object? distance = freezed,Object? categoriesStr = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Venue(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,district: freezed == district ? _self.district : district // ignore: cast_nullable_to_non_nullable
as String?,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,googlePlaceId: freezed == googlePlaceId ? _self.googlePlaceId : googlePlaceId // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,rejectionNote: freezed == rejectionNote ? _self.rejectionNote : rejectionNote // ignore: cast_nullable_to_non_nullable
as String?,addedBy: null == addedBy ? _self.addedBy : addedBy // ignore: cast_nullable_to_non_nullable
as String,addedByName: freezed == addedByName ? _self.addedByName : addedByName // ignore: cast_nullable_to_non_nullable
as String?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,verificationDueAt: freezed == verificationDueAt ? _self.verificationDueAt : verificationDueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,foodHalalMode: null == foodHalalMode ? _self.foodHalalMode : foodHalalMode // ignore: cast_nullable_to_non_nullable
as String,excludedProducts: null == excludedProducts ? _self._excludedProducts : excludedProducts // ignore: cast_nullable_to_non_nullable
as List<String>,trustCriteria: null == trustCriteria ? _self._trustCriteria : trustCriteria // ignore: cast_nullable_to_non_nullable
as List<TrustCriteria>,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<VenuePhoto>,foodItems: null == foodItems ? _self._foodItems : foodItems // ignore: cast_nullable_to_non_nullable
as List<FoodItem>,avgRating: freezed == avgRating ? _self.avgRating : avgRating // ignore: cast_nullable_to_non_nullable
as double?,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,confirmationCount: null == confirmationCount ? _self.confirmationCount : confirmationCount // ignore: cast_nullable_to_non_nullable
as int,badge: freezed == badge ? _self.badge : badge // ignore: cast_nullable_to_non_nullable
as Badge?,confirmedByMe: freezed == confirmedByMe ? _self.confirmedByMe : confirmedByMe // ignore: cast_nullable_to_non_nullable
as bool?,distance: freezed == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double?,categoriesStr: freezed == categoriesStr ? _self.categoriesStr : categoriesStr // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of Venue
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BadgeCopyWith<$Res>? get badge {
    if (_self.badge == null) {
    return null;
  }

  return $BadgeCopyWith<$Res>(_self.badge!, (value) {
    return _then(_self.copyWith(badge: value));
  });
}
}


/// @nodoc
mixin _$TrustCriteria {

 int get id; String get key; String get name; String? get description;
/// Create a copy of TrustCriteria
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrustCriteriaCopyWith<TrustCriteria> get copyWith => _$TrustCriteriaCopyWithImpl<TrustCriteria>(this as TrustCriteria, _$identity);

  /// Serializes this TrustCriteria to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrustCriteria&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,key,name,description);

@override
String toString() {
  return 'TrustCriteria(id: $id, key: $key, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class $TrustCriteriaCopyWith<$Res>  {
  factory $TrustCriteriaCopyWith(TrustCriteria value, $Res Function(TrustCriteria) _then) = _$TrustCriteriaCopyWithImpl;
@useResult
$Res call({
 int id, String key, String name, String? description
});




}
/// @nodoc
class _$TrustCriteriaCopyWithImpl<$Res>
    implements $TrustCriteriaCopyWith<$Res> {
  _$TrustCriteriaCopyWithImpl(this._self, this._then);

  final TrustCriteria _self;
  final $Res Function(TrustCriteria) _then;

/// Create a copy of TrustCriteria
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? key = null,Object? name = null,Object? description = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrustCriteria].
extension TrustCriteriaPatterns on TrustCriteria {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrustCriteria value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrustCriteria() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrustCriteria value)  $default,){
final _that = this;
switch (_that) {
case _TrustCriteria():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrustCriteria value)?  $default,){
final _that = this;
switch (_that) {
case _TrustCriteria() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String key,  String name,  String? description)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrustCriteria() when $default != null:
return $default(_that.id,_that.key,_that.name,_that.description);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String key,  String name,  String? description)  $default,) {final _that = this;
switch (_that) {
case _TrustCriteria():
return $default(_that.id,_that.key,_that.name,_that.description);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String key,  String name,  String? description)?  $default,) {final _that = this;
switch (_that) {
case _TrustCriteria() when $default != null:
return $default(_that.id,_that.key,_that.name,_that.description);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrustCriteria implements TrustCriteria {
  const _TrustCriteria({required this.id, required this.key, required this.name, this.description});
  factory _TrustCriteria.fromJson(Map<String, dynamic> json) => _$TrustCriteriaFromJson(json);

@override final  int id;
@override final  String key;
@override final  String name;
@override final  String? description;

/// Create a copy of TrustCriteria
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrustCriteriaCopyWith<_TrustCriteria> get copyWith => __$TrustCriteriaCopyWithImpl<_TrustCriteria>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrustCriteriaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrustCriteria&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,key,name,description);

@override
String toString() {
  return 'TrustCriteria(id: $id, key: $key, name: $name, description: $description)';
}


}

/// @nodoc
abstract mixin class _$TrustCriteriaCopyWith<$Res> implements $TrustCriteriaCopyWith<$Res> {
  factory _$TrustCriteriaCopyWith(_TrustCriteria value, $Res Function(_TrustCriteria) _then) = __$TrustCriteriaCopyWithImpl;
@override @useResult
$Res call({
 int id, String key, String name, String? description
});




}
/// @nodoc
class __$TrustCriteriaCopyWithImpl<$Res>
    implements _$TrustCriteriaCopyWith<$Res> {
  __$TrustCriteriaCopyWithImpl(this._self, this._then);

  final _TrustCriteria _self;
  final $Res Function(_TrustCriteria) _then;

/// Create a copy of TrustCriteria
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? key = null,Object? name = null,Object? description = freezed,}) {
  return _then(_TrustCriteria(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$VenuePhoto {

 String get id;@JsonKey(name: 'venue_id') String get venueId; String get url;@JsonKey(name: 'uploaded_by') String get uploadedBy;@JsonKey(name: 'is_primary') bool get isPrimary;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of VenuePhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VenuePhotoCopyWith<VenuePhoto> get copyWith => _$VenuePhotoCopyWithImpl<VenuePhoto>(this as VenuePhoto, _$identity);

  /// Serializes this VenuePhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VenuePhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.url, url) || other.url == url)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,venueId,url,uploadedBy,isPrimary,createdAt);

@override
String toString() {
  return 'VenuePhoto(id: $id, venueId: $venueId, url: $url, uploadedBy: $uploadedBy, isPrimary: $isPrimary, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $VenuePhotoCopyWith<$Res>  {
  factory $VenuePhotoCopyWith(VenuePhoto value, $Res Function(VenuePhoto) _then) = _$VenuePhotoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'venue_id') String venueId, String url,@JsonKey(name: 'uploaded_by') String uploadedBy,@JsonKey(name: 'is_primary') bool isPrimary,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$VenuePhotoCopyWithImpl<$Res>
    implements $VenuePhotoCopyWith<$Res> {
  _$VenuePhotoCopyWithImpl(this._self, this._then);

  final VenuePhoto _self;
  final $Res Function(VenuePhoto) _then;

/// Create a copy of VenuePhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? venueId = null,Object? url = null,Object? uploadedBy = null,Object? isPrimary = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VenuePhoto].
extension VenuePhotoPatterns on VenuePhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VenuePhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VenuePhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VenuePhoto value)  $default,){
final _that = this;
switch (_that) {
case _VenuePhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VenuePhoto value)?  $default,){
final _that = this;
switch (_that) {
case _VenuePhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'venue_id')  String venueId,  String url, @JsonKey(name: 'uploaded_by')  String uploadedBy, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VenuePhoto() when $default != null:
return $default(_that.id,_that.venueId,_that.url,_that.uploadedBy,_that.isPrimary,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'venue_id')  String venueId,  String url, @JsonKey(name: 'uploaded_by')  String uploadedBy, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _VenuePhoto():
return $default(_that.id,_that.venueId,_that.url,_that.uploadedBy,_that.isPrimary,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'venue_id')  String venueId,  String url, @JsonKey(name: 'uploaded_by')  String uploadedBy, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _VenuePhoto() when $default != null:
return $default(_that.id,_that.venueId,_that.url,_that.uploadedBy,_that.isPrimary,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VenuePhoto implements VenuePhoto {
  const _VenuePhoto({required this.id, @JsonKey(name: 'venue_id') required this.venueId, required this.url, @JsonKey(name: 'uploaded_by') required this.uploadedBy, @JsonKey(name: 'is_primary') this.isPrimary = false, @JsonKey(name: 'created_at') this.createdAt});
  factory _VenuePhoto.fromJson(Map<String, dynamic> json) => _$VenuePhotoFromJson(json);

@override final  String id;
@override@JsonKey(name: 'venue_id') final  String venueId;
@override final  String url;
@override@JsonKey(name: 'uploaded_by') final  String uploadedBy;
@override@JsonKey(name: 'is_primary') final  bool isPrimary;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of VenuePhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VenuePhotoCopyWith<_VenuePhoto> get copyWith => __$VenuePhotoCopyWithImpl<_VenuePhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VenuePhotoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VenuePhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.venueId, venueId) || other.venueId == venueId)&&(identical(other.url, url) || other.url == url)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,venueId,url,uploadedBy,isPrimary,createdAt);

@override
String toString() {
  return 'VenuePhoto(id: $id, venueId: $venueId, url: $url, uploadedBy: $uploadedBy, isPrimary: $isPrimary, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$VenuePhotoCopyWith<$Res> implements $VenuePhotoCopyWith<$Res> {
  factory _$VenuePhotoCopyWith(_VenuePhoto value, $Res Function(_VenuePhoto) _then) = __$VenuePhotoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'venue_id') String venueId, String url,@JsonKey(name: 'uploaded_by') String uploadedBy,@JsonKey(name: 'is_primary') bool isPrimary,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$VenuePhotoCopyWithImpl<$Res>
    implements _$VenuePhotoCopyWith<$Res> {
  __$VenuePhotoCopyWithImpl(this._self, this._then);

  final _VenuePhoto _self;
  final $Res Function(_VenuePhoto) _then;

/// Create a copy of VenuePhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? venueId = null,Object? url = null,Object? uploadedBy = null,Object? isPrimary = null,Object? createdAt = freezed,}) {
  return _then(_VenuePhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,venueId: null == venueId ? _self.venueId : venueId // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$FoodCategory {

 int get id; String get key; String get name;@JsonKey(name: 'image_url') String? get imageUrl; List<FoodItem> get items;
/// Create a copy of FoodCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoodCategoryCopyWith<FoodCategory> get copyWith => _$FoodCategoryCopyWithImpl<FoodCategory>(this as FoodCategory, _$identity);

  /// Serializes this FoodCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoodCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,key,name,imageUrl,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'FoodCategory(id: $id, key: $key, name: $name, imageUrl: $imageUrl, items: $items)';
}


}

/// @nodoc
abstract mixin class $FoodCategoryCopyWith<$Res>  {
  factory $FoodCategoryCopyWith(FoodCategory value, $Res Function(FoodCategory) _then) = _$FoodCategoryCopyWithImpl;
@useResult
$Res call({
 int id, String key, String name,@JsonKey(name: 'image_url') String? imageUrl, List<FoodItem> items
});




}
/// @nodoc
class _$FoodCategoryCopyWithImpl<$Res>
    implements $FoodCategoryCopyWith<$Res> {
  _$FoodCategoryCopyWithImpl(this._self, this._then);

  final FoodCategory _self;
  final $Res Function(FoodCategory) _then;

/// Create a copy of FoodCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? key = null,Object? name = null,Object? imageUrl = freezed,Object? items = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<FoodItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [FoodCategory].
extension FoodCategoryPatterns on FoodCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoodCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoodCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoodCategory value)  $default,){
final _that = this;
switch (_that) {
case _FoodCategory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoodCategory value)?  $default,){
final _that = this;
switch (_that) {
case _FoodCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String key,  String name, @JsonKey(name: 'image_url')  String? imageUrl,  List<FoodItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoodCategory() when $default != null:
return $default(_that.id,_that.key,_that.name,_that.imageUrl,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String key,  String name, @JsonKey(name: 'image_url')  String? imageUrl,  List<FoodItem> items)  $default,) {final _that = this;
switch (_that) {
case _FoodCategory():
return $default(_that.id,_that.key,_that.name,_that.imageUrl,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String key,  String name, @JsonKey(name: 'image_url')  String? imageUrl,  List<FoodItem> items)?  $default,) {final _that = this;
switch (_that) {
case _FoodCategory() when $default != null:
return $default(_that.id,_that.key,_that.name,_that.imageUrl,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FoodCategory implements FoodCategory {
  const _FoodCategory({required this.id, required this.key, required this.name, @JsonKey(name: 'image_url') this.imageUrl, final  List<FoodItem> items = const []}): _items = items;
  factory _FoodCategory.fromJson(Map<String, dynamic> json) => _$FoodCategoryFromJson(json);

@override final  int id;
@override final  String key;
@override final  String name;
@override@JsonKey(name: 'image_url') final  String? imageUrl;
 final  List<FoodItem> _items;
@override@JsonKey() List<FoodItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of FoodCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoodCategoryCopyWith<_FoodCategory> get copyWith => __$FoodCategoryCopyWithImpl<_FoodCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FoodCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoodCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,key,name,imageUrl,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'FoodCategory(id: $id, key: $key, name: $name, imageUrl: $imageUrl, items: $items)';
}


}

/// @nodoc
abstract mixin class _$FoodCategoryCopyWith<$Res> implements $FoodCategoryCopyWith<$Res> {
  factory _$FoodCategoryCopyWith(_FoodCategory value, $Res Function(_FoodCategory) _then) = __$FoodCategoryCopyWithImpl;
@override @useResult
$Res call({
 int id, String key, String name,@JsonKey(name: 'image_url') String? imageUrl, List<FoodItem> items
});




}
/// @nodoc
class __$FoodCategoryCopyWithImpl<$Res>
    implements _$FoodCategoryCopyWith<$Res> {
  __$FoodCategoryCopyWithImpl(this._self, this._then);

  final _FoodCategory _self;
  final $Res Function(_FoodCategory) _then;

/// Create a copy of FoodCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? key = null,Object? name = null,Object? imageUrl = freezed,Object? items = null,}) {
  return _then(_FoodCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<FoodItem>,
  ));
}


}


/// @nodoc
mixin _$FoodItem {

 int get id;@JsonKey(name: 'category_id') int get categoryId; String get key; String get name;@JsonKey(name: 'is_custom') bool get isCustom;
/// Create a copy of FoodItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoodItemCopyWith<FoodItem> get copyWith => _$FoodItemCopyWithImpl<FoodItem>(this as FoodItem, _$identity);

  /// Serializes this FoodItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoodItem&&(identical(other.id, id) || other.id == id)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,categoryId,key,name,isCustom);

@override
String toString() {
  return 'FoodItem(id: $id, categoryId: $categoryId, key: $key, name: $name, isCustom: $isCustom)';
}


}

/// @nodoc
abstract mixin class $FoodItemCopyWith<$Res>  {
  factory $FoodItemCopyWith(FoodItem value, $Res Function(FoodItem) _then) = _$FoodItemCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'category_id') int categoryId, String key, String name,@JsonKey(name: 'is_custom') bool isCustom
});




}
/// @nodoc
class _$FoodItemCopyWithImpl<$Res>
    implements $FoodItemCopyWith<$Res> {
  _$FoodItemCopyWithImpl(this._self, this._then);

  final FoodItem _self;
  final $Res Function(FoodItem) _then;

/// Create a copy of FoodItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? categoryId = null,Object? key = null,Object? name = null,Object? isCustom = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FoodItem].
extension FoodItemPatterns on FoodItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoodItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoodItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoodItem value)  $default,){
final _that = this;
switch (_that) {
case _FoodItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoodItem value)?  $default,){
final _that = this;
switch (_that) {
case _FoodItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'category_id')  int categoryId,  String key,  String name, @JsonKey(name: 'is_custom')  bool isCustom)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoodItem() when $default != null:
return $default(_that.id,_that.categoryId,_that.key,_that.name,_that.isCustom);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'category_id')  int categoryId,  String key,  String name, @JsonKey(name: 'is_custom')  bool isCustom)  $default,) {final _that = this;
switch (_that) {
case _FoodItem():
return $default(_that.id,_that.categoryId,_that.key,_that.name,_that.isCustom);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'category_id')  int categoryId,  String key,  String name, @JsonKey(name: 'is_custom')  bool isCustom)?  $default,) {final _that = this;
switch (_that) {
case _FoodItem() when $default != null:
return $default(_that.id,_that.categoryId,_that.key,_that.name,_that.isCustom);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FoodItem implements FoodItem {
  const _FoodItem({required this.id, @JsonKey(name: 'category_id') required this.categoryId, required this.key, required this.name, @JsonKey(name: 'is_custom') this.isCustom = false});
  factory _FoodItem.fromJson(Map<String, dynamic> json) => _$FoodItemFromJson(json);

@override final  int id;
@override@JsonKey(name: 'category_id') final  int categoryId;
@override final  String key;
@override final  String name;
@override@JsonKey(name: 'is_custom') final  bool isCustom;

/// Create a copy of FoodItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoodItemCopyWith<_FoodItem> get copyWith => __$FoodItemCopyWithImpl<_FoodItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FoodItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoodItem&&(identical(other.id, id) || other.id == id)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,categoryId,key,name,isCustom);

@override
String toString() {
  return 'FoodItem(id: $id, categoryId: $categoryId, key: $key, name: $name, isCustom: $isCustom)';
}


}

/// @nodoc
abstract mixin class _$FoodItemCopyWith<$Res> implements $FoodItemCopyWith<$Res> {
  factory _$FoodItemCopyWith(_FoodItem value, $Res Function(_FoodItem) _then) = __$FoodItemCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'category_id') int categoryId, String key, String name,@JsonKey(name: 'is_custom') bool isCustom
});




}
/// @nodoc
class __$FoodItemCopyWithImpl<$Res>
    implements _$FoodItemCopyWith<$Res> {
  __$FoodItemCopyWithImpl(this._self, this._then);

  final _FoodItem _self;
  final $Res Function(_FoodItem) _then;

/// Create a copy of FoodItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? categoryId = null,Object? key = null,Object? name = null,Object? isCustom = null,}) {
  return _then(_FoodItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$Badge {

 String get level;// base | bronze | silver | gold | platinum
 int get count;
/// Create a copy of Badge
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BadgeCopyWith<Badge> get copyWith => _$BadgeCopyWithImpl<Badge>(this as Badge, _$identity);

  /// Serializes this Badge to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Badge&&(identical(other.level, level) || other.level == level)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,level,count);

@override
String toString() {
  return 'Badge(level: $level, count: $count)';
}


}

/// @nodoc
abstract mixin class $BadgeCopyWith<$Res>  {
  factory $BadgeCopyWith(Badge value, $Res Function(Badge) _then) = _$BadgeCopyWithImpl;
@useResult
$Res call({
 String level, int count
});




}
/// @nodoc
class _$BadgeCopyWithImpl<$Res>
    implements $BadgeCopyWith<$Res> {
  _$BadgeCopyWithImpl(this._self, this._then);

  final Badge _self;
  final $Res Function(Badge) _then;

/// Create a copy of Badge
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? level = null,Object? count = null,}) {
  return _then(_self.copyWith(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Badge].
extension BadgePatterns on Badge {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Badge value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Badge() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Badge value)  $default,){
final _that = this;
switch (_that) {
case _Badge():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Badge value)?  $default,){
final _that = this;
switch (_that) {
case _Badge() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String level,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Badge() when $default != null:
return $default(_that.level,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String level,  int count)  $default,) {final _that = this;
switch (_that) {
case _Badge():
return $default(_that.level,_that.count);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String level,  int count)?  $default,) {final _that = this;
switch (_that) {
case _Badge() when $default != null:
return $default(_that.level,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Badge extends Badge {
  const _Badge({required this.level, this.count = 0}): super._();
  factory _Badge.fromJson(Map<String, dynamic> json) => _$BadgeFromJson(json);

@override final  String level;
// base | bronze | silver | gold | platinum
@override@JsonKey() final  int count;

/// Create a copy of Badge
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BadgeCopyWith<_Badge> get copyWith => __$BadgeCopyWithImpl<_Badge>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BadgeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Badge&&(identical(other.level, level) || other.level == level)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,level,count);

@override
String toString() {
  return 'Badge(level: $level, count: $count)';
}


}

/// @nodoc
abstract mixin class _$BadgeCopyWith<$Res> implements $BadgeCopyWith<$Res> {
  factory _$BadgeCopyWith(_Badge value, $Res Function(_Badge) _then) = __$BadgeCopyWithImpl;
@override @useResult
$Res call({
 String level, int count
});




}
/// @nodoc
class __$BadgeCopyWithImpl<$Res>
    implements _$BadgeCopyWith<$Res> {
  __$BadgeCopyWithImpl(this._self, this._then);

  final _Badge _self;
  final $Res Function(_Badge) _then;

/// Create a copy of Badge
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? level = null,Object? count = null,}) {
  return _then(_Badge(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
