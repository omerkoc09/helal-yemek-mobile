/// Mekan detayına giderken `extra` ile taşınan ön bilgi.
///
/// Listede zaten elimizde olan isim/şehir, detay yüklenirken iskelet ekranda
/// gösterilir; kullanıcı boş bir ekran yerine hangi mekana girdiğini görür.
/// Detay verisi gelince yerini gerçek içeriğe bırakır.
class VenueDetailPreview {
  final String name;
  final String? city;

  const VenueDetailPreview({required this.name, this.city});
}
