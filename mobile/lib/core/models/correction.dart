import 'package:freezed_annotation/freezed_annotation.dart';

part 'correction.freezed.dart';
part 'correction.g.dart';

@freezed
abstract class Correction with _$Correction {
  const factory Correction({
    required String id,
    @JsonKey(name: 'venue_id') required String venueId,
    @JsonKey(name: 'suggested_by') required String suggestedBy,
    @JsonKey(name: 'field_name') required String fieldName,
    @JsonKey(name: 'old_value') String? oldValue,
    @JsonKey(name: 'new_value') required String newValue,
    @Default('pending') String status,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    String? note,
    @JsonKey(name: 'venue_name') String? venueName,
    @JsonKey(name: 'suggested_by_name') String? suggestedByName,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Correction;

  factory Correction.fromJson(Map<String, dynamic> json) =>
      _$CorrectionFromJson(json);
}
