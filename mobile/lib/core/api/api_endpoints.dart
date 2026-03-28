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
  static String venuePhotos(String id) => '/venues/$id/photos';
  static String venuePhoto(String venueId, String photoId) =>
      '/venues/$venueId/photos/$photoId';

  // Reviews
  static String venueReviews(String venueId) => '/venues/$venueId/reviews';
  static String venueReview(String venueId, String reviewId) =>
      '/venues/$venueId/reviews/$reviewId';

  // Favorites
  static const String favorites = '/favorites';
  static String favorite(String venueId) => '/favorites/$venueId';

  // Guide
  static const String guideApply = '/guide/apply';
  static const String guideMyVenues = '/guide/my-venues';
  static const String guideMyReferralCode = '/guide/my-referral-code';

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
  static const String adminUsers = '/admin/users';
  static String adminUser(String id) => '/admin/users/$id';

  // Food Categories
  static const String foodCategories = '/food-categories';
  static String venuesByCategory(int categoryId) =>
      '/venues/by-category/$categoryId';
  static String foodCategoryItems(String id) => '/food-categories/$id/items';

  // Misc
  static const String criteria = '/criteria';
}
