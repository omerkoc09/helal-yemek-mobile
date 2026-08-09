#!/usr/bin/env bash
#
# İtimat — Android release keystore üretimi (Yayın Adım 2.1).
#
#   cd mobile/android && ./create-keystore.sh
#
# Parolayı yalnızca SEN girersin; script parolayı hiçbir yere yazmaz, yalnızca
# keytool'a ve key.properties'e aktarır (ikisi de gitignore'lı).
#
# ⚠️ ÜRETİLEN DOSYAYI VE PAROLAYI KAYBETME. Play Store'a yüklenen her sürüm aynı
# anahtarla imzalanmak zorundadır; kaybı hâlinde uygulamayı GÜNCELLEYEMEZSİN.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

KEYSTORE="app/upload-keystore.jks"
ALIAS="upload"
PROPS="key.properties"

if [[ -f "$KEYSTORE" ]]; then
	echo "HATA: $KEYSTORE zaten var."
	echo "Üzerine yazmak İMZAYI DEĞİŞTİRİR ve Play güncellemelerini kırar."
	echo "Gerçekten yenilemek istiyorsan önce mevcut dosyayı güvenli bir yere taşı."
	exit 1
fi

command -v keytool >/dev/null || { echo "HATA: keytool bulunamadı (JDK kurulu mu?)" >&2; exit 1; }

echo "═══════════════════════════════════════════════════════════"
echo " Android release keystore üretimi"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Bir parola belirle (en az 6 karakter). Bu parolayı 1Password/Bitwarden"
echo "gibi bir parola yöneticisine KAYDET — kaybı telafi edilemez."
echo

# -s: ekrana yazılmaz. İki kez sorup eşleştiriyoruz: tek harflik bir yazım
# hatası, sonradan açılamayan bir keystore demek olurdu.
read -r -s -p "Parola: " PW1; echo
read -r -s -p "Parola (tekrar): " PW2; echo
[[ "$PW1" == "$PW2" ]] || { echo "HATA: parolalar eşleşmiyor." >&2; exit 1; }
[[ ${#PW1} -ge 6 ]] || { echo "HATA: parola en az 6 karakter olmalı." >&2; exit 1; }

echo
echo "Sertifika bilgileri (kullanıcıya GÖRÜNMEZ, boş bırakılabilir):"
read -r -p "Ad Soyad / Kuruluş [Itimat]: " CN; CN="${CN:-Itimat}"
read -r -p "Şehir [Istanbul]: " CITY; CITY="${CITY:-Istanbul}"
read -r -p "Ülke kodu [TR]: " COUNTRY; COUNTRY="${COUNTRY:-TR}"

echo
echo "Keystore üretiliyor..."

# -storepass/-keypass argüman olarak veriliyor; interaktif sorulmasın diye.
# 10000 gün (~27 yıl): Play, sertifikanın 2033'ten sonra dolmasını şart koşar.
keytool -genkeypair -v \
	-keystore "$KEYSTORE" \
	-alias "$ALIAS" \
	-keyalg RSA -keysize 2048 -validity 10000 \
	-storepass "$PW1" -keypass "$PW1" \
	-dname "CN=$CN, O=$CN, L=$CITY, C=$COUNTRY" \
	>/dev/null 2>&1

echo "✓ $KEYSTORE üretildi"

# key.properties — Gradle bunu okuyup release imzasına geçiyor.
cat > "$PROPS" <<PROPEOF
storePassword=$PW1
keyPassword=$PW1
keyAlias=$ALIAS
storeFile=upload-keystore.jks
PROPEOF
chmod 600 "$PROPS"
echo "✓ $PROPS yazıldı (chmod 600)"

echo
echo "═══════════════════════════════════════════════════════════"
echo " SHA-1 / SHA-256 parmak izleri"
echo "═══════════════════════════════════════════════════════════"
echo "SHA-1'i Firebase Console'a ekle, sonra google-services.json'ı yeniden indir."
echo
keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$PW1" 2>/dev/null \
	| grep -E "SHA1:|SHA256:"

echo
echo "═══════════════════════════════════════════════════════════"
echo " ⚠️  ŞİMDİ YEDEKLE"
echo "═══════════════════════════════════════════════════════════"
echo "  1. android/app/upload-keystore.jks  (dosya)"
echo "  2. parolası                          (parola yöneticisine)"
echo
echo "İkisi de git'e GİRMEZ (gitignore korumalı). Sunucun/diskin kaybolursa"
echo "yedeğin yoksa uygulamayı bir daha güncelleyemezsin."
