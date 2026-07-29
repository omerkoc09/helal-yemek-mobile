import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  bool _showMoreOptions = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // Brand içeriği — ekranın üst %55'inde ortalı
          Positioned.fill(
            bottom: MediaQuery.of(context).size.height * 0.45,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo/logo_with_name/screen-3.png',
                      height: 400,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Beyaz alt kart — gradientin üzerine biner, köşeler gradient'i gösterir
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE48420), Color(0xFFBF6010)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
            child: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kaydol veya giriş yap',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Devam etmek için tercih ettiğiniz yöntemi seçin',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Google butonu
                      _SocialButton(
                        onTap: isLoading
                            ? null
                            : () => ref.read(authProvider.notifier).signInWithGoogle(),
                        backgroundColor: Colors.white,
                        borderColor: const Color(0xFFDADCE0),
                        isLoading: isLoading,
                        logo: _GoogleLogo(),
                        label: 'Google ile devam et',
                        labelColor: const Color(0xFF1F1F1F),
                      ),
                      const SizedBox(height: 12),

                      // Facebook butonu (tasarım)
                      _SocialButton(
                        onTap: null,
                        backgroundColor: const Color(0xFF1877F2),
                        borderColor: const Color(0xFF1877F2),
                        isLoading: false,
                        logo: _FacebookLogo(),
                        label: 'Facebook ile devam et',
                        labelColor: Colors.white,
                      ),
                      const SizedBox(height: 20),

                      // Hata mesajı
                      if (authState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            authState.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // Daha fazla yöntem
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _showMoreOptions = !_showMoreOptions),
                          child: Text(
                            _showMoreOptions
                                ? 'Daha az yöntem'
                                : 'Daha fazla yöntem görüntüle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Genişleyen ek yöntemler
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOut,
                        child: _showMoreOptions
                            ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  _ExpandedOptionButton(
                                    icon: Icons.mail_outline,
                                    label: 'E-posta ile devam et',
                                    onTap: () => context.push(AppRoutes.login),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final bool isLoading;
  final Widget logo;
  final String label;
  final Color labelColor;

  const _SocialButton({
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.isLoading,
    required this.logo,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: logo,
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ExpandedOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ExpandedOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/google_logo.svg',
      width: 22,
      height: 22,
    );
  }
}

class _FacebookLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/facebook_logo.svg',
      width: 20,
      height: 20,
    );
  }
}
