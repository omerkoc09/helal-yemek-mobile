import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Toast türü — ikon ve renk paletini belirler.
enum ToastType { success, error, info }

/// Ekranın üstünden kayarak gelen, kendiliğinden kaybolan bildirim.
///
/// Material `SnackBar` yerine kullanılır: alt navigasyonu ve sayfa içeriğini
/// kapatmaz, marka paletiyle uyumludur.
///
/// ```dart
/// AppToast.success(context, 'Doğrulamanız kaydedildi, teşekkürler!');
/// AppToast.error(context, 'Doğrulama başarısız, tekrar deneyin');
/// ```
class AppToast {
  AppToast._();

  static const Duration _defaultDuration = Duration(seconds: 2);
  static const Duration _errorDuration = Duration(milliseconds: 3500);

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void success(BuildContext context, String message) =>
      show(context, message, type: ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: ToastType.error);

  static void info(BuildContext context, String message) =>
      show(context, message, type: ToastType.info);

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration? duration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Aynı anda tek toast: öncekini anında kaldır.
    _dismiss();

    final effectiveDuration =
        duration ?? (type == ToastType.error ? _errorDuration : _defaultDuration);

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        // Süre dolmadan kullanıcı yukarı sürüklerse erken kapat.
        onDismiss: _dismiss,
      ),
    );

    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(effectiveDuration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({Color background, IconData icon}) get _style => switch (widget.type) {
        ToastType.success => (
            background: AppTheme.pinApproved,
            icon: Icons.check_circle_rounded,
          ),
        ToastType.error => (
            background: AppTheme.error,
            icon: Icons.error_rounded,
          ),
        ToastType.info => (
            background: AppTheme.primary,
            icon: Icons.info_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Dismissible(
            key: const ValueKey('app_toast'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(style.icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
