import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;

  /// Akıştaki toplam adım sayısı (link, detay, kriter, mutfak).
  static const _stepCount = 4;
  static const _circleSize = 28.0;

  const StepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final inactive = AppTheme.textSecondary.withValues(alpha: 0.2);

    // Daire ve bağlayıcı çizgiler dönüşümlü diziliyor: ilk ve son daire
    // kenarlara hizalanır, çizgiler yalnızca iki daire ARASINDA kalır.
    // Çizgiyi dairenin soluna koyup her adımı Expanded'a sarmak, ilk adımda
    // çizgi olmadığı halde boşluk bırakıp diziyi kopuk gösteriyordu.
    final children = <Widget>[];
    for (var index = 0; index < _stepCount; index++) {
      if (index > 0) {
        // Segment, solundaki adım tamamlandıysa dolu görünür.
        children.add(
          Expanded(
            child: Container(
              height: 2,
              color: index <= currentStep ? AppTheme.primary : inactive,
            ),
          ),
        );
      }
      children.add(_buildCircle(index, inactive));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(children: children),
    );
  }

  Widget _buildCircle(int index, Color inactive) {
    final isActive = index == currentStep;
    final isCompleted = index < currentStep;

    return Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        color: isCompleted || isActive ? AppTheme.primary : inactive,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : AppTheme.textSecondary,
                ),
              ),
      ),
    );
  }
}
