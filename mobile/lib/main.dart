import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/auth/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleSignIn.instance.initialize();
  runApp(const ProviderScope(child: CaizMiApp()));
}

class CaizMiApp extends ConsumerStatefulWidget {
  const CaizMiApp({super.key});

  @override
  ConsumerState<CaizMiApp> createState() => _CaizMiAppState();
}

class _CaizMiAppState extends ConsumerState<CaizMiApp> {
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

    return MaterialApp.router(
      title: 'Caiz mi?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
