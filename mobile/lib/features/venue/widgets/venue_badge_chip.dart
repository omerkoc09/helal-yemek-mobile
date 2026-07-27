import 'package:flutter/material.dart' hide Badge;
import '../../../core/models/venue.dart';

/// Mekanın "kaç bağımsız rehber teyit etti" güvenini gösterir.
/// Bu, "Onaylandı" (admin/geçerlilik) göstergesinden AYRI bir kavramdır:
/// burada sosyal kanıt (kaç rehber) somut sayıyla anlatılır — seviye adı yok.
/// compact=true: kart/harita için küçük chip. compact=false: detay için tam satır.
class VenueBadgeChip extends StatelessWidget {
  final Badge? badge;
  final bool compact;

  const VenueBadgeChip({super.key, required this.badge, this.compact = false});

  /// Madalya rengi — "Onaylandı" yeşilinden ayrışsın diye amber/altın tonu.
  static const Color _medalColor = Color(0xFFE0A800);

  @override
  Widget build(BuildContext context) {
    final b = badge;
    // Henüz başka rehber doğrulamadıysa (sadece ekleyen) hiçbir şey gösterme.
    if (b == null || b.isBase) {
      return const SizedBox.shrink();
    }

    // confirmation_count ekleyeni HARİÇ tutar; kullanıcıya gösterirken ekleyen
    // rehberi de dahil ederiz (o da mekana kefil olan bir rehberdir).
    final total = b.count + 1;

    if (compact) {
      // Belirgin, sarı harici zemin: doğrulama rozetini öne çıkarır.
      const bg = Color(0xFF2E7D32); // koyu yeşil (güven/onay tonu)
      return Chip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: bg,
        side: BorderSide.none,
        avatar: const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
        label: Text('$total',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    // Detay: somut, dürüst sayı. Seviye adı yok.
    return InkWell(
      onTap: () => _showInfo(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium, color: _medalColor, size: 20),
            const SizedBox(width: 6),
            Text('$total rehber doğruladı',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
        title: const Text('Rehber Doğrulaması'),
        content: const Text(
          'Bu sayı, mekanı ekleyen rehber dahil, bu dönemde mekanı bizzat teyit eden '
          'yerel rehber sayısını gösterir. Ne kadar çok rehber doğrularsa mekan o kadar '
          'güvenilirdir. Dönem yenilendikçe rehberler mekanı tekrar doğrular; böylece sayı '
          'her zaman güncel güveni yansıtır.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
        ],
      ),
    );
  }
}
