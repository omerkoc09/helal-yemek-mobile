import 'package:flutter/material.dart' hide Badge;
import '../../../core/models/venue.dart';

/// Mekanın dönemsel güven rozetini gösterir.
/// compact=true: kart/harita için küçük chip. compact=false: detay için tam gösterim.
class VenueBadgeChip extends StatelessWidget {
  final Badge? badge;
  final bool compact;

  const VenueBadgeChip({super.key, required this.badge, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final b = badge;

    if (compact) {
      if (b == null || b.isBase) return const SizedBox.shrink();
      return Chip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Color(b.colorValue).withValues(alpha: 0.15),
        avatar: Icon(Icons.verified, size: 16, color: Color(b.colorValue)),
        label: Text('${b.count}',
            style: TextStyle(color: Color(b.colorValue), fontWeight: FontWeight.bold)),
      );
    }

    // Detay görünümü
    if (b == null || b.isBase) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Henüz başka rehber doğrulamadı',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return InkWell(
      onTap: () => _showInfo(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.verified, color: Color(b.colorValue)),
            const SizedBox(width: 8),
            Text('${b.labelTr} Rozet',
                style: TextStyle(
                    color: Color(b.colorValue), fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Text('· Bu dönem ${b.count} rehber doğruladı',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 16, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Güven Rozeti'),
        content: const Text(
            'Bu rozet, mekanı bu doğrulama döneminde teyit eden rehber sayısını gösterir. '
            'Dönem yenilendikçe rehberler mekanı yeniden doğrular.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
        ],
      ),
    );
  }
}
