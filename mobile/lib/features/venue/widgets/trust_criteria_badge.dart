import 'package:flutter/material.dart';

import '../../../core/models/venue.dart';
import '../../../core/theme/app_theme.dart';

/// Bir güven kriterinin amblem tarzı rozeti: dairesel çerçeve + kritere özel
/// ikon + kısa etiket. İkonlar Flutter'ın gömülü Material setinden gelir
/// (asset/indirme yok). Açıklama varsa tıklayınca dialog açılır.
class TrustCriteriaBadge extends StatelessWidget {
  final TrustCriteria criteria;

  const TrustCriteriaBadge({super.key, required this.criteria});

  static const double _emblemSize = 56;
  static const double _slotWidth = 76;

  @override
  Widget build(BuildContext context) {
    final style = _styleForKey(criteria.key);
    final hasDescription =
        criteria.description != null && criteria.description!.isNotEmpty;

    return Semantics(
      button: hasDescription,
      label: criteria.name,
      child: InkWell(
        onTap: hasDescription ? () => _showDescription(context, style) : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _slotWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Emblem(color: style.color, icon: style.icon),
              const SizedBox(height: 6),
              Text(
                criteria.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDescription(BuildContext context, _BadgeStyle style) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _Emblem(color: style.color, icon: style.icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(criteria.name, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Text(criteria.description!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

/// Dairesel amblem: ince renkli halka + hafif renkli iç dolgu + merkez ikon.
class _Emblem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;

  const _Emblem({
    required this.color,
    required this.icon,
    this.size = TrustCriteriaBadge._emblemSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.9), width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

class _BadgeStyle {
  final IconData icon;
  final Color color;

  const _BadgeStyle(this.icon, this.color);
}

/// Bilinmeyen (admin-ekli) kriterler için renk paleti. Key'den deterministik
/// seçilir; böylece jenerik gri yerine anlamlı ve tutarlı bir renk çıkar.
const List<Color> _fallbackPalette = [
  Color(0xFF00897B), // teal
  Color(0xFF1E88E5), // mavi
  Color(0xFF7E57C2), // mor
  Color(0xFFF59E0B), // amber
  Color(0xFF43A047), // yeşil
  Color(0xFFE53935), // kırmızı
];

/// Kritere özel ikon + renk. Bilinmeyen key'ler için deterministik renkli
/// fallback (ikon jenerik, renk key'e göre kararlı).
_BadgeStyle _styleForKey(String key) {
  switch (key) {
    case 'trust_certified':
      return const _BadgeStyle(Icons.verified, AppTheme.pinApproved);
    case 'known_owner':
      return const _BadgeStyle(Icons.storefront, AppTheme.primary);
    case 'no_boycott_products':
      return const _BadgeStyle(Icons.do_not_disturb, AppTheme.error);
    case 'no_alcohol':
      return const _BadgeStyle(Icons.no_drinks, Color(0xFF7E57C2));
    case 'clean_maintained':
      return const _BadgeStyle(Icons.cleaning_services, Color(0xFF00897B));
    case 'visited_by_guide':
      return const _BadgeStyle(Icons.pin_drop, Color(0xFF1E88E5));
    case 'long_standing':
      return const _BadgeStyle(Icons.workspace_premium, Color(0xFFF59E0B));
    default:
      final color =
          _fallbackPalette[key.hashCode.abs() % _fallbackPalette.length];
      return _BadgeStyle(Icons.verified_user, color);
  }
}

/// Güven kriterlerini tek satırda dizer; satıra sığmazsa yatay kaydırılır.
class TrustCriteriaBadges extends StatelessWidget {
  final List<TrustCriteria> criteria;

  const TrustCriteriaBadges({super.key, required this.criteria});

  @override
  Widget build(BuildContext context) {
    if (criteria.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < criteria.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            TrustCriteriaBadge(criteria: criteria[i]),
          ],
        ],
      ),
    );
  }
}
