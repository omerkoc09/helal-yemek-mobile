import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Mekan detayı yüklenirken gösterilen iskelet ekran.
///
/// Boş bir spinner yerine gerçek sayfanın yerleşimini taklit eder; böylece
/// içerik geldiğinde sıçrama hissi olmaz. Listeden gelen [name] ve [city]
/// biliniyorsa gri kutu yerine doğrudan yazılır — kullanıcı hangi mekana
/// girdiğini anında görür.
class VenueDetailSkeleton extends StatefulWidget {
  final String? name;
  final String? city;

  const VenueDetailSkeleton({super.key, this.name, this.city});

  @override
  State<VenueDetailSkeleton> createState() => _VenueDetailSkeletonState();
}

class _VenueDetailSkeletonState extends State<VenueDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: widget.name != null
                  ? Text(
                      widget.name!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    )
                  : null,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _Shimmer(
                    controller: _controller,
                    child: const ColoredBox(color: AppTheme.border),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum rozeti + son doğrulama
                  Row(
                    children: [
                      _Bone(controller: _controller, width: 110, height: 32),
                      const SizedBox(width: 8),
                      _Bone(controller: _controller, width: 150, height: 32),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Rehber doğrulama satırı
                  _Bone(controller: _controller, width: 170, height: 20),
                  const SizedBox(height: 12),

                  // Puan
                  _Bone(controller: _controller, width: 140, height: 22),
                  const SizedBox(height: 16),

                  // Adres — şehir biliniyorsa gerçek metni göster.
                  if (widget.city != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.city!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    )
                  else
                    _Bone(controller: _controller, width: 120, height: 20),
                  const SizedBox(height: 20),

                  // Güven kriterleri başlığı + rozetler
                  _Bone(controller: _controller, width: 130, height: 18),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Bone(
                        controller: _controller,
                        width: 64,
                        height: 64,
                        radius: 32,
                      ),
                      const SizedBox(width: 16),
                      _Bone(
                        controller: _controller,
                        width: 64,
                        height: 64,
                        radius: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Mutfaklar başlığı + chip'ler
                  _Bone(controller: _controller, width: 100, height: 18),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Bone(controller: _controller, width: 70, height: 28),
                      _Bone(controller: _controller, width: 56, height: 28),
                      _Bone(controller: _controller, width: 84, height: 28),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir gri iskelet bloğu.
class _Bone extends StatelessWidget {
  final AnimationController controller;
  final double width;
  final double height;
  final double radius;

  const _Bone({
    required this.controller,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      controller: controller,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// İskelet parçalarına yumuşak bir yanıp sönme verir.
class _Shimmer extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _Shimmer({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    return FadeTransition(opacity: animation, child: child);
  }
}
