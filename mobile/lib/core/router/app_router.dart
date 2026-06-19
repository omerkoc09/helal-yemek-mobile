import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../../features/auth/screens/auth_gate_screen.dart';
import '../../features/auth/screens/location_permission_screen.dart';
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
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/all_venues_screen.dart' as home;
import '../../features/home/screens/venue_filter_screen.dart';
import '../../features/home/screens/venue_cuisines_screen.dart';
import '../../features/home/screens/venue_results_screen.dart';
import '../../shared/widgets/app_header.dart';
import '../../features/notifications/screens/notifications_screen.dart';

// Route isimleri
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
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
  static const String venueFilter = '/venues/filter';
  static const String venueFilterCuisines = '/venues/filter/cuisines';
  static const String venueFiltered = '/venues/filtered';
  static const String notifications = '/notifications';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == AppRoutes.auth ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.onboarding;
      final isSplash = loc == AppRoutes.splash;

      if (authState.status == AuthStatus.unknown) {
        return isSplash ? null : AppRoutes.splash;
      }

      if (!isAuthenticated && !isAuthRoute) {
        if (!authState.hasSeenOnboarding) return AppRoutes.onboarding;
        return AppRoutes.auth;
      }

      if (isAuthenticated && (isAuthRoute || isSplash)) {
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

      // Onboarding (ilk açılış — konum izni)
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const LocationPermissionScreen(),
      ),

      // Auth gate (Google / Facebook / daha fazla)
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthGateScreen(),
      ),

      // Email ile giriş
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

      // Notifications
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
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

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final showBottomNav = _isTabRoute(location);
    final isGuide = ref.watch(authProvider).isGuide;

    if (!showBottomNav) {
      return Scaffold(appBar: const AppHeader(), body: child);
    }

    if (isGuide) {
      return _GuideShell(location: location, child: child);
    }

    return Scaffold(
      appBar: const AppHeader(),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _travelerIndex(location),
        onTap: (index) => _travelerTap(context, index),
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
      ),
    );
  }

  bool _isTabRoute(String location) {
    return location == AppRoutes.home ||
        location.startsWith(AppRoutes.map) ||
        location == AppRoutes.profile ||
        location == AppRoutes.favorites ||
        location == AppRoutes.foodDiscovery ||
        location == AppRoutes.search ||
        location == AppRoutes.myVenues;
  }

  int _travelerIndex(String location) {
    if (location.startsWith(AppRoutes.map)) return 1;
    if (location == AppRoutes.profile) return 2;
    return 0;
  }

  void _travelerTap(BuildContext context, int index) {
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

class _GuideShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _GuideShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: const AppHeader(),
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRoutes.addVenue),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: theme.bottomNavigationBarTheme.backgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _GuideNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Ana Sayfa',
              isActive: location == AppRoutes.home,
              onTap: () => context.go(AppRoutes.home),
            ),
            _GuideNavItem(
              icon: Icons.map_outlined,
              activeIcon: Icons.map,
              label: 'Harita',
              isActive: location.startsWith(AppRoutes.map),
              onTap: () => context.go(AppRoutes.map),
            ),
            const SizedBox(width: 56),
            _GuideNavItem(
              icon: Icons.store_outlined,
              activeIcon: Icons.store,
              label: 'Mekanlarım',
              isActive: location == AppRoutes.myVenues,
              onTap: () => context.go(AppRoutes.myVenues),
            ),
            _GuideNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profil',
              isActive: location == AppRoutes.profile,
              onTap: () => context.go(AppRoutes.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GuideNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final unselected = theme.bottomNavigationBarTheme.unselectedItemColor!;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? primary : unselected,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? primary : unselected,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
