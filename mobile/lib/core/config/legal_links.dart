/// Uygulama sürümü — profildeki "Hakkında" bölümünde gösterilir.
///
/// `pubspec.yaml`'daki `version:` ile ELLE eşit tutulmalı. package_info_plus
/// bağımlılığı eklemek yerine sabit tercih edildi: tek bir metin için ek paket
/// ve platform kanalı maliyeti gereksiz. Sürüm yükseltirken ikisi birlikte
/// güncellenmeli.
const String appVersion = '1.0.0';

/// Yasal doküman adresleri — tek kaynak.
///
/// Metinler uygulamaya GÖMÜLMEZ, web'de barındırılır. İki nedeni var:
///  1. Apple ve Google, mağaza listesinde gizlilik politikası için bir URL ister;
///     uygulama içi ekran bu şartı karşılamaz. Adres zaten var olmak zorunda.
///  2. Metin değişince uygulama güncellemesi ve mağaza incelemesi gerekmez —
///     kullanıcı her açtığında güncel sürümü görür.
///
/// Derleme sırasında ezilebilir (ör. staging alan adı):
///   flutter run --dart-define=LEGAL_BASE_URL=https://staging.caizmi.com
class LegalLinks {
  LegalLinks._();

  static const String _envBaseUrl = String.fromEnvironment('LEGAL_BASE_URL');

  /// Yasal sayfaların yayınlandığı kök adres.
  static final String baseUrl =
      _envBaseUrl.isNotEmpty ? _envBaseUrl : 'https://caizmi.com';

  /// Gizlilik politikası — mağaza listesinde de bu adres verilmeli.
  static String get privacyPolicy => '$baseUrl/gizlilik';

  /// Kullanım şartları (kullanıcı sözleşmesi).
  static String get termsOfService => '$baseUrl/kullanim-sartlari';

  /// KVKK aydınlatma metni.
  static String get kvkkNotice => '$baseUrl/kvkk';

  /// Destek / iletişim adresi.
  static const String supportEmail = 'destek@caizmi.com';
}
