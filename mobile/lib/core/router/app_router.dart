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
import '../../features/venue/models/venue_detail_preview.dart';
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
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
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
          loc == AppRoutes.onboarding ||
          loc == AppRoutes.forgotPassword ||
          loc == AppRoutes.resetPassword;
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
          // Rehber sekmesi — shell içinde kalır (bottom nav + AppHeader korunur)
          GoRoute(
            path: AppRoutes.myVenues,
            builder: (context, state) => const MyVenuesScreen(),
          ),
          // Tümünü Gör (nearby / popular) — shell içinde: AppHeader + alt nav korunur
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
        ],
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
          // Listeden gelindiyse isim/şehir `extra` ile taşınır ve yükleme
          // iskeletinde gösterilir. Bildirim/derin bağlantıda null olur.
          final preview = state.extra is VenueDetailPreview
              ? state.extra as VenueDetailPreview
              : null;
          return VenueDetailScreen(
            venueId: id,
            previewName: preview?.name,
            previewCity: preview?.city,
          );
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
    final authState = ref.watch(authProvider);
    final hasGuideFeatures = authState.isGuide || authState.isAdmin;

    if (!showBottomNav) {
      return Scaffold(appBar: const AppHeader(), body: child);
    }

    if (hasGuideFeatures) {
      return _GuideShell(location: location, child: child);
    }

    return _TravelerShell(location: location, child: child);
  }

  bool _isTabRoute(String location) {
    return location == AppRoutes.home ||
        location.startsWith(AppRoutes.map) ||
        location == AppRoutes.profile ||
        location == AppRoutes.favorites ||
        location == AppRoutes.foodDiscovery ||
        location == AppRoutes.search ||
        location == AppRoutes.myVenues ||
        location == AppRoutes.allVenues;
  }
}

class _TravelerShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _TravelerShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final nav = _FloatingNavBar(
      centerIcon: Icons.explore,
      onCenterTap: () => context.go(AppRoutes.map),
      isCenterActive: location.startsWith(AppRoutes.map),
      items: [
        _NavItem(Icons.home_outlined, Icons.home, 'Ana Sayfa',
            location == AppRoutes.home, () => context.go(AppRoutes.home)),
        _NavItem(Icons.favorite_outline, Icons.favorite, 'Favoriler',
            location == AppRoutes.favorites, () => context.go(AppRoutes.favorites)),
        _NavItem(Icons.search_outlined, Icons.search, 'Ara',
            location == AppRoutes.search, () => context.go(AppRoutes.search)),
        _NavItem(Icons.person_outline, Icons.person, 'Profil',
            location == AppRoutes.profile, () => context.go(AppRoutes.profile)),
      ],
      primary: primary,
    );

    return Scaffold(
      extendBody: true,
      appBar: const AppHeader(),
      body: Stack(
        children: [
          child,
          Positioned(left: 0, right: 0, bottom: 0, child: nav),
        ],
      ),
    );
  }
}

class _GuideShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _GuideShell({required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final nav = _FloatingNavBar(
      centerIcon: Icons.add,
      onCenterTap: () => context.go(AppRoutes.addVenue),
      isCenterActive: location == AppRoutes.addVenue,
      items: [
        _NavItem(Icons.home_outlined, Icons.home, 'Ana Sayfa',
            location == AppRoutes.home, () => context.go(AppRoutes.home)),
        _NavItem(Icons.map_outlined, Icons.map, 'Harita',
            location.startsWith(AppRoutes.map), () => context.go(AppRoutes.map)),
        _NavItem(Icons.store_outlined, Icons.store, 'Mekanlarım',
            location == AppRoutes.myVenues, () => context.go(AppRoutes.myVenues)),
        _NavItem(Icons.person_outline, Icons.person, 'Profil',
            location == AppRoutes.profile, () => context.go(AppRoutes.profile)),
      ],
      primary: primary,
    );

    return Scaffold(
      extendBody: true,
      appBar: const AppHeader(),
      body: Stack(
        children: [
          child,
          Positioned(left: 0, right: 0, bottom: 0, child: nav),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem(this.icon, this.activeIcon, this.label, this.isActive, this.onTap);
}

class _FloatingNavBar extends StatelessWidget {
  final IconData centerIcon;
  final VoidCallback onCenterTap;
  final bool isCenterActive;
  final List<_NavItem> items;
  final Color primary;

  const _FloatingNavBar({
    required this.centerIcon,
    required this.onCenterTap,
    required this.isCenterActive,
    required this.items,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final unselected = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF78350F).withValues(alpha: 0.4);
    final left = items.sublist(0, 2);
    final right = items.sublist(2);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ...left.map((item) => _PillNavItem(item: item, primary: primary, unselected: unselected)),
              // Center FAB
              GestureDetector(
                onTap: onCenterTap,
                child: Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isCenterActive ? primary.withValues(alpha:0.85) : primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha:0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(centerIcon, color: Colors.white, size: 26),
                ),
              ),
              ...right.map((item) => _PillNavItem(item: item, primary: primary, unselected: unselected)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final _NavItem item;
  final Color primary;
  final Color unselected;

  const _PillNavItem({
    required this.item,
    required this.primary,
    required this.unselected,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: item.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            item.isActive
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.activeIcon, color: primary, size: 22),
                  )
                : Icon(item.icon, color: unselected, size: 22),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                color: item.isActive ? primary : unselected,
                fontWeight: item.isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
