class ApiEndpoints {
  ApiEndpoints._();

  // Base URL — geliştirme ortamı için
  static const String baseUrl = 'http://localhost:8080/api/v1';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String googleAuth = '/auth/google';
  static const String appleAuth = '/auth/apple';
  static const String refreshToken = '/auth/refresh';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/profile';

  // Venues
  static const String venues = '/venues';
  static String venueDetail(String id) => '/venues/$id';

  // Reviews
  static String venueReviews(String venueId) => '/venues/$venueId/reviews';

  // Reports
  static String venueReports(String venueId) => '/venues/$venueId/reports';
  static String venueReview(String venueId, String reviewId) =>
      '/venues/$venueId/reviews/$reviewId';

  // Favorites
  static const String favorites = '/favorites';
  static String favorite(String venueId) => '/favorites/$venueId';

  // Guide
  static const String guideApply = '/guide/apply';
  static const String guideMyVenues = '/guide/my-venues';
  static const String guideMyReferralCode = '/guide/my-referral-code';
  static const String guideMyApplication = '/guide/my-application';

  // Admin
  static const String adminVenues = '/admin/venues';
  static const String adminPendingVenues = '/admin/venues/pending';
  static String adminVenue(String id) => '/admin/venues/$id';
  static String adminApproveVenue(String id) => '/admin/venues/$id/approve';
  static String adminRejectVenue(String id) => '/admin/venues/$id/reject';
  static const String adminApplications = '/admin/applications';
  static String adminApproveApplication(String id) =>
      '/admin/applications/$id/approve';
  static String adminRejectApplication(String id) =>
      '/admin/applications/$id/reject';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminVenueReports = '/admin/venue-reports';
  static String adminResolveVenueReport(String id) =>
      '/admin/venue-reports/$id/resolve';
  static const String adminUsers = '/admin/users';
  static String adminUser(String id) => '/admin/users/$id';

  // Home feed
  static const String venuesNearby = '/venues/nearby';
  static const String venuesPopular = '/venues/popular';
  static const String venuesCities = '/venues/cities';

  // Food Categories
  static const String foodCategories = '/food-categories';
  static String venuesByCategory(int categoryId) =>
      '/venues/by-category/$categoryId';
  static String foodCategoryItems(String id) => '/food-categories/$id/items';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';

  // Venue verify
  static String venueVerify(String id) => '/venues/$id/verify';

  // Admin verification logs
  static const String adminVerificationLogs = '/admin/verification-logs';
  static String adminReactivateVenue(String id) => '/admin/venues/$id/reactivate';

  // Misc
  static const String criteria = '/criteria';
  static const String placePreview = '/venues/place-preview';
}
