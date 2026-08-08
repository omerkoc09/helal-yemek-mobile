#!/usr/bin/env bash
#
# İtimat — yedekten geri yükleme.
#
#   ./restore.sh backups/itimat_2026-08-02_0200.sql.gz
#
# Bu scripti YAZMAK yetmez, PROVA ETMEK gerekir. Test edilmemiş bir geri
# yükleme prosedürü, olmayan yedekle aynı şeydir. README'de prova adımı var.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ $# -ne 1 ]]; then
	echo "Kullanım: $0 <yedek-dosyasi.sql.gz>" >&2
	echo "Mevcut yedekler:" >&2
	ls -1t backups/*.sql.gz 2>/dev/null | head -10 >&2 || echo "  (yok)" >&2
	exit 1
fi

FILE="$1"
[[ -f "$FILE" ]] || { echo "HATA: dosya yok: $FILE" >&2; exit 1; }

ENV_FILE="$SCRIPT_DIR/.env.production"
[[ -f "$ENV_FILE" ]] || { echo "HATA: $ENV_FILE yok." >&2; exit 1; }

# backup.sh ile aynı gerekçe: env dosyası source edilmiyor (SMTP_FROM içindeki
# "<" karakteri shell'i kırıyor), yalnızca gereken anahtarlar okunuyor.
read_env() {
	local key="$1" val
	val="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
	val="${val%\"}"; val="${val#\"}"
	printf '%s' "$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
}

POSTGRES_USER="$(read_env POSTGRES_USER)"
POSTGRES_DB="$(read_env POSTGRES_DB)"
DOMAIN="$(read_env DOMAIN)"

# Bozuk dosyayla veritabanının üstüne yazmak, elimizdeki çalışan veriyi de
# kaybettirir. Önce dosyayı doğrula.
gzip -t "$FILE" || { echo "HATA: yedek bozuk." >&2; exit 1; }

echo "⚠️  DİKKAT: '$POSTGRES_DB' veritabanının MEVCUT İÇERİĞİ SİLİNECEK."
echo "    Yedek: $FILE"
read -r -p "    Devam etmek için 'evet' yazın: " CONFIRM
[[ "$CONFIRM" == "evet" ]] || { echo "İptal edildi."; exit 1; }

# API'yi durdur: geri yükleme sırasında yazma yaparsa veri tutarsız kalır.
echo "API durduruluyor..."
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" stop api

echo "Geri yükleniyor..."
# Dump --clean --if-exists ile alındığı için mevcut nesneleri kendisi düşürür.
gzip -dc "$FILE" | docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" \
	exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1

echo "API yeniden başlatılıyor..."
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" start api

echo "Tamamlandı. Doğrulama: curl -fsS https://api.${DOMAIN}/ready"
