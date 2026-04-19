import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/food_discovery/screens/food_discovery_screen.dart';
import '../../features/venue/screens/venue_detail_screen.dart';
import '../../features/venue/screens/city_venues_screen.dart';
import '../../features/guide/screens/add_venue_screen.dart';
import '../../features/guide/screens/my_venues_screen.dart';
import '../../features/guide/screens/edit_venue_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/pending_venues_screen.dart';
import '../../features/admin/screens/venue_review_screen.dart';
import '../../features/admin/screens/guide_applications_screen.dart';
import '../../features/admin/screens/all_venues_screen.dart';
import '../../features/admin/screens/audit_log_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/all_venues_screen.dart' as home;
import '../../features/home/screens/venue_filter_screen.dart';
import '../../features/home/screens/venue_cuisines_screen.dart';
import '../../features/home/screens/venue_results_screen.dart';
import '../../shared/widgets/app_header.dart';

// Route isimleri
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String map = '/map';
  static const String foodDiscovery = '/food-discovery';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String venueDetail = '/venue/:id';
  static const String cityVenues = '/city/:city';
  static const String editProfile = '/edit-profile';
  static const String addVenue = '/add-venue';
  static const String myVenues = '/my-venues';
  static const String editVenue = '/venue/:id/edit';
  static const String allVenues = '/venues/all';
  static const String adminDashboard = '/admin';
  static const String adminPendingVenues = '/admin/pending-venues';
  static const String adminVenueReview = '/admin/venue/:id';
  static const String adminApplications = '/admin/applications';
  static const String adminAllVenues = '/admin/all-venues';
  static const String adminAuditLog = '/admin/audit-log';
  static const String adminUsers = '/admin/users';
  static const String venueFilter = '/venues/filter';
  static const String venueFilterCuisines = '/venues/filter/cuisines';
  static const String venueFiltered = '/venues/filtered';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      if (authState.status == AuthStatus.unknown) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && (isAuthRoute || isSplash)) {
        return authState.isAdmin ? AppRoutes.adminDashboard : AppRoutes.home;
      }

      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      if (isAdminRoute && !authState.isAdmin) {
        return AppRoutes.home;
      }

      final guideRoutes = [AppRoutes.addVenue, AppRoutes.myVenues];
      final isGuideRoute = guideRoutes.contains(state.matchedLocation) ||
          state.matchedLocation.endsWith('/edit');
      if (isGuideRoute && !authState.isGuide && !authState.isAdmin) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashPlaceholder(),
      ),

      // Auth
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Ana sekmeler — ShellRoute ile bottom nav + AppHeader
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.map,
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          // Header'dan erişilebilir sayfalar (tab ikonları yok ama shell içinde)
          GoRoute(
            path: AppRoutes.favorites,
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: AppRoutes.foodDiscovery,
            builder: (context, state) => const FoodDiscoveryScreen(),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (context, state) => const SearchScreen(),
          ),
        ],
      ),

      // Tümünü Gör (nearby / popular)
      GoRoute(
        path: AppRoutes.allVenues,
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          return home.AllVenuesScreen(
            type: type == 'popular'
                ? home.AllVenuesType.popular
                : type == 'city'
                    ? home.AllVenuesType.city
                    : home.AllVenuesType.nearby,
          );
        },
      ),

      // Filtre / sıralama akışı
      GoRoute(
        path: AppRoutes.venueFilter,
        builder: (context, state) {
          final fromHome = state.uri.queryParameters['fromHome'] == 'true';
          return VenueFilterScreen(fromHome: fromHome);
        },
      ),
      GoRoute(
        path: AppRoutes.venueFilterCuisines,
        builder: (context, state) => const VenueCuisinesScreen(),
      ),
      GoRoute(
        path: AppRoutes.venueFiltered,
        builder: (context, state) => const VenueResultsScreen(),
      ),

      // Detay sayfaları
      GoRoute(
        path: AppRoutes.venueDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VenueDetailScreen(venueId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.cityVenues,
        builder: (context, state) {
          final city = Uri.decodeComponent(state.pathParameters['city']!);
          return CityVenuesScreen(city: city);
        },
      ),

      // Profile
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Guide
      GoRoute(
        path: AppRoutes.addVenue,
        builder: (context, state) => const AddVenueScreen(),
      ),
      GoRoute(
        path: AppRoutes.myVenues,
        builder: (context, state) => const MyVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.editVenue,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditVenueScreen(venueId: id);
        },
      ),

      // Admin
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAllVenues,
        builder: (context, state) => const AllVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminPendingVenues,
        builder: (context, state) => const PendingVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminVenueReview,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VenueReviewScreen(venueId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.adminApplications,
        builder: (context, state) => const GuideApplicationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAuditLog,
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) => const UsersScreen(),
      ),
    ],
  );
});

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final showBottomNav = _isTabRoute(location);

    return Scaffold(
      appBar: const AppHeader(),
      body: child,
      bottomNavigationBar: showBottomNav
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex(location),
              onTap: (index) => _onTap(context, index),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Ana Sayfa'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: Icon(Icons.map),
                    label: 'Harita'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profil'),
              ],
            )
          : null,
    );
  }

  bool _isTabRoute(String location) {
    return location == AppRoutes.home ||
        location.startsWith(AppRoutes.map) ||
        location == AppRoutes.profile ||
        location == AppRoutes.favorites ||
        location == AppRoutes.foodDiscovery ||
        location == AppRoutes.search;
  }

  int _currentIndex(String location) {
    if (location.startsWith(AppRoutes.map)) return 1;
    if (location == AppRoutes.profile) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.map);
      case 2:
        context.go(AppRoutes.profile);
    }
  }
}
