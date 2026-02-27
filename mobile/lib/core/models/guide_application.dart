import 'package:freezed_annotation/freezed_annotation.dart';

part 'guide_application.freezed.dart';
part 'guide_application.g.dart';

@freezed
abstract class GuideApplication with _$GuideApplication {
  const factory GuideApplication({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @Default('pending') String status,
    String? note,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'user_name') String? userName,
    @JsonKey(name: 'user_email') String? userEmail,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _GuideApplication;

  const GuideApplication._();

  factory GuideApplication.fromJson(Map<String, dynamic> json) =>
      _$GuideApplicationFromJson(json);

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
