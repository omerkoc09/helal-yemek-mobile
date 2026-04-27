import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import 'admin_provider_utils.dart';

class VenueReport {
  final String id;
  final String venueId;
  final String venueName;
  final String venueCity;
  final String? addedByName;
  final String? addedByEmail;
  final DateTime venueAddedAt;
  final String userId;
  final String reporterName;
  final String reporterEmail;
  final String reason;
  final String? description;
  final String status;
  final DateTime createdAt;

  const VenueReport({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.venueCity,
    this.addedByName,
    this.addedByEmail,
    required this.venueAddedAt,
    required this.userId,
    required this.reporterName,
    required this.reporterEmail,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory VenueReport.fromJson(Map<String, dynamic> json) => VenueReport(
        id: json['id'] as String,
        venueId: json['venue_id'] as String,
        venueName: json['venue_name'] as String,
        venueCity: json['venue_city'] as String,
        addedByName: json['added_by_name'] as String?,
        addedByEmail: json['added_by_email'] as String?,
        venueAddedAt: DateTime.parse(json['venue_added_at'] as String),
        userId: json['user_id'] as String,
        reporterName: json['reporter_name'] as String,
        reporterEmail: json['reporter_email'] as String,
        reason: json['reason'] as String,
        description: json['description'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  VenueReport copyWith({String? status}) => VenueReport(
        id: id,
        venueId: venueId,
        venueName: venueName,
        venueCity: venueCity,
        addedByName: addedByName,
        addedByEmail: addedByEmail,
        venueAddedAt: venueAddedAt,
        userId: userId,
        reporterName: reporterName,
        reporterEmail: reporterEmail,
        reason: reason,
        description: description,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  bool get isResolved => status == 'resolved';
}

class VenueReportsState {
  final List<VenueReport> reports;
  final bool isLoading;
  final String? error;

  const VenueReportsState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
  });

  VenueReportsState copyWith({
    List<VenueReport>? reports,
    bool? isLoading,
    String? error,
  }) {
    return VenueReportsState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class VenueReportsNotifier extends Notifier<VenueReportsState> {
  @override
  VenueReportsState build() => const VenueReportsState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiEndpoints.adminVenueReports);
      final reports =
          parseList<VenueReport>(response.data, VenueReport.fromJson);
      state = state.copyWith(reports: reports, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Şikayetler yüklenemedi.',
      );
    }
  }

  Future<bool> resolve(String reportId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(ApiEndpoints.adminResolveVenueReport(reportId));
      state = state.copyWith(
        reports: state.reports
            .map((r) => r.id == reportId ? r.copyWith(status: 'resolved') : r)
            .toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final venueReportsProvider =
    NotifierProvider<VenueReportsNotifier, VenueReportsState>(
  VenueReportsNotifier.new,
);
