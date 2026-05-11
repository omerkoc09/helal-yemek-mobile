import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    String? surname,
    String? phone,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    required String role,
    @Default('email') String provider,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _User;

  const User._();

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  bool get isTraveler => role == 'traveler';
  bool get isGuide => role == 'guide';
  bool get isAdmin => role == 'admin';
}
