class ApiEndpoints {
  ApiEndpoints._();

  // Base URL — geliştirme ortamı için
  static const String baseUrl = 'http://localhost:3000/api/v1';

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
  static String venueDirectionClick(String venueId) =>
      '/venues/$venueId/direction-click';

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
  static const String guideMyApplication = '/guide/my-application';

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
  static String venueConfirm(String id) => '/venues/$id/confirm';
  static const String venueCheckDuplicate = '/venues/check-duplicate';

  // Misc
  static const String criteria = '/criteria';
  static const String placePreview = '/venues/place-preview';
}
