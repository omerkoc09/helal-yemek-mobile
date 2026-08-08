#!/usr/bin/env bash
#
# İtimat — günlük veritabanı yedeği.
#
# pg_dump → gzip → R2. Yerelde de son N günlük kopya tutulur (hızlı geri dönüş
# için); R2 kopyası sunucunun tamamen kaybolduğu senaryo içindir.
#
# Cron kurulumu ve rclone yapılandırması: deploy/README.md → "Yedekleme"
#
# set -u: tanımsız değişken kullanımı hata versin (yanlış yola yazmayı önler).
# pipefail: pg_dump | gzip zincirinde pg_dump patlarsa script başarısız saysın —
#           bu olmadan bozuk/boş bir yedek "başarılı" görünür.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env.production"
if [[ ! -f "$ENV_FILE" ]]; then
	echo "HATA: $ENV_FILE yok. Yedekleme yapılamaz." >&2
	exit 1
fi

# Env dosyası `source` EDİLMİYOR: SMTP_FROM gibi değerler "<" içeriyor ve
# tırnaksız yazıldığında shell bunu yönlendirme sanıp scripti kırıyor (yerel
# denemede yaşandı). Bunun yerine yalnızca ihtiyacımız olan anahtarlar
# satır satır, yorum ve boşluklar ayıklanarak okunuyor.
read_env() {
	local key="$1" default="${2:-}" val
	val="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
	# Baştaki/sondaki tırnak ve boşlukları temizle.
	val="${val%\"}"; val="${val#\"}"
	val="${val%\'}"; val="${val#\'}"
	val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	printf '%s' "${val:-$default}"
}

POSTGRES_USER="$(read_env POSTGRES_USER)"
POSTGRES_DB="$(read_env POSTGRES_DB)"
BACKUP_BUCKET="$(read_env BACKUP_BUCKET itimat-backups)"
BACKUP_RETENTION_DAYS="$(read_env BACKUP_RETENTION_DAYS 7)"

if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_DB" ]]; then
	echo "HATA: POSTGRES_USER / POSTGRES_DB $ENV_FILE içinde bulunamadı." >&2
	exit 1
fi

BACKUP_DIR="$SCRIPT_DIR/backups"
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y-%m-%d_%H%M)"
FILE="$BACKUP_DIR/itimat_${STAMP}.sql.gz"

echo "[$(date '+%F %T')] Yedek alınıyor: $FILE"

# Dump container İÇİNDE çalışır: DB portu dışa açık olmadığı için host'tan
# doğrudan pg_dump çalıştırılamaz (ve çalıştırılmamalı).
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" \
	exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists \
	| gzip -9 > "$FILE"

# ── Yedeği DOĞRULA ────────────────────────────────────────────────────────────
# "Yedek alındı" demek yetmez; bozuk gzip veya boş dump da dosya üretir.
if ! gzip -t "$FILE" 2>/dev/null; then
	echo "HATA: yedek bozuk (gzip testi başarısız): $FILE" >&2
	rm -f "$FILE"
	exit 1
fi

# İçerik gerçekten tablo taşıyor mu? Boş/yarım dump'ı burada yakalarız.
if ! gzip -dc "$FILE" | grep -q "CREATE TABLE"; then
	echo "HATA: yedekte tablo yok, dump eksik görünüyor: $FILE" >&2
	rm -f "$FILE"
	exit 1
fi

SIZE="$(du -h "$FILE" | cut -f1)"
echo "[$(date '+%F %T')] Yedek doğrulandı ($SIZE)"

# ── R2'ye yükle ───────────────────────────────────────────────────────────────
# rclone yoksa yerel yedek yine alınmış olur; sessizce geçmeyip uyarıyoruz.
if command -v rclone >/dev/null 2>&1; then
	if rclone copy "$FILE" "r2:${BACKUP_BUCKET}/" 2>&1; then
		echo "[$(date '+%F %T')] R2'ye yüklendi: ${BACKUP_BUCKET}/$(basename "$FILE")"
	else
		echo "UYARI: R2 yüklemesi BAŞARISIZ — yerel kopya duruyor: $FILE" >&2
	fi
else
	echo "UYARI: rclone kurulu değil, yedek yalnızca YERELDE. Sunucu kaybolursa yedek de kaybolur." >&2
fi

# ── Rotasyon ──────────────────────────────────────────────────────────────────
RETENTION="${BACKUP_RETENTION_DAYS:-7}"
find "$BACKUP_DIR" -name 'itimat_*.sql.gz' -mtime "+${RETENTION}" -delete
echo "[$(date '+%F %T')] ${RETENTION} günden eski yerel yedekler temizlendi."

if command -v rclone >/dev/null 2>&1; then
	rclone delete "r2:${BACKUP_BUCKET}/" --min-age "${RETENTION}d" 2>/dev/null \
		|| echo "UYARI: R2 rotasyonu yapılamadı." >&2
fi

echo "[$(date '+%F %T')] Tamamlandı."
