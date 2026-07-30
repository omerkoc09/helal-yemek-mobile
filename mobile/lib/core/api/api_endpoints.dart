import 'package:flutter/foundation.dart';

class ApiEndpoints {
  ApiEndpoints._();

  /// Derleme sırasında ezilebilir:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
  /// Fiziksel cihazda test ederken de bu kullanılır (host makinenin LAN IP'si).
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL — `--dart-define` verilmişse o, yoksa platforma göre dev varsayılanı.
  static final String baseUrl =
      _envBaseUrl.isNotEmpty ? _envBaseUrl : _devBaseUrl;

  /// Android EMÜLATÖRÜNDE `localhost` emülatörün kendisini gösterir, host makineyi
  /// değil; host'a `10.0.2.2` üzerinden erişilir. iOS simülatörü host'un ağını
  /// paylaştığı için `localhost` orada çalışır — bu yüzden fark bugüne kadar
  /// görünmedi. Fiziksel cihazda ikisi de çalışmaz, `--dart-define` şart.
  static String get _devBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String googleAuth = '/auth/google';
  static const String refreshToken = '/auth/refresh';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

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
  static const String guideMyConfirmations = '/guide/my-confirmations';
  static const String guideMyApplication = '/guide/my-application';

  // Home feed
  static const String venuesNearby = '/venues/nearby';
  static const String venuesPopular = '/venues/popular';
  static const String venuesCities = '/venues/cities';
  static const String venuesDistricts = '/venues/districts';

  // Food Categories
  static const String foodCategories = '/food-categories';
  static String venuesByCategory(int categoryId) =>
      '/venues/by-category/$categoryId';

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
