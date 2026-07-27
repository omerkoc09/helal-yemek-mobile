import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/auth/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr', null);
  await GoogleSignIn.instance.initialize();
  runApp(const ProviderScope(child: ItimatApp()));
}

class ItimatApp extends ConsumerStatefulWidget {
  const ItimatApp({super.key});

  @override
  ConsumerState<ItimatApp> createState() => _ItimatAppState();
}

class _ItimatAppState extends ConsumerState<ItimatApp> {
  @override
  void initState() {
    super.initState();
    // Uygulama başladığında auth durumunu kontrol et
    Future.microtask(() {
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        ref.read(notificationProvider.notifier).fetchUnreadCount();
      }
    });

    return MaterialApp.router(
      title: 'İtimat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
