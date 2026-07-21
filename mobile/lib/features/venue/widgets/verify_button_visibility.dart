/// Yeniden doğrulama butonunun görünürlük eşiği.
///
/// Backend, doğrulama süresi dolmadan [_verificationWarningDays] gün önce
/// "doğrulaman yaklaştı" uyarısını gönderir (VERIFICATION_WARNING_DAYS).
/// Buton da uyarıyla aynı anda çıksın diye aynı eşik burada kullanılır.
/// Backend tarafında bu değer değişirse burayı da güncelle.
const int _verificationWarningDays = 14;

bool shouldShowVerifyButton(
  String? currentUserId,
  String addedBy,
  String status, {
  DateTime? verificationDueAt,
}) {
  if (currentUserId == null) return false;
  if (currentUserId != addedBy) return false;
  if (status == 'suspended') return true;
  if (status == 'approved' && verificationDueAt != null) {
    // Gün yerine süre karşılaştırması: inDays tam güne yuvarladığı için
    // kısa periyotlarda (ör. 2 gün) butonu çok erken gösterirdi.
    final remaining = verificationDueAt.difference(DateTime.now());
    return remaining <= const Duration(days: _verificationWarningDays);
  }
  return false;
}
