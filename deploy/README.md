# İtimat — Üretim Dağıtımı

Sunucu: **Hetzner CX22** (2 vCPU / 4 GB) veya dengi bir VPS.
Yığın: Docker Compose ile **Postgres+PostGIS · Go API · Caddy** (otomatik TLS).
Depolama: **Cloudflare R2** · Mail: **Resend**

Bu klasördeki dosyalar yerelde uçtan uca denendi (bkz. en alttaki
"Doğrulama kaydı") — sunucuda ilk kez çalıştırılan, denenmemiş kod değildir.

---

## 0. Mimari

```
                     ┌──────────── VPS ────────────────────┐
  api.<domain>  ───► │  Caddy :443  ──► api:8080 (Go)      │
admin.<domain>  ───► │      │            │                 │
                     │      └► /srv/admin│ (Vue dist)      │
                     │                   ▼                 │
                     │              db:5432 (PostGIS)      │
                     └──────────────┬──────────────────────┘
                                    │ fotoğraflar + yedekler
                                    ▼
                           Cloudflare R2 (S3 uyumlu)
```

Dışarıya yalnızca **80/443** açıktır. API ve veritabanı portları yayınlanmaz;
DB'ye erişim yalnızca compose ağı içinden veya SSH tüneliyle olur.

---

## 1. Ön hazırlık (hesaplar)

Sırayla halledilecek, hiçbiri kod işi değil:

1. **Domain** al (Cloudflare Registrar / Namecheap).
2. **VPS** al (Hetzner: Nürnberg veya Helsinki, Ubuntu 24.04).
3. **Cloudflare R2**: iki bucket → `itimat-photos`, `itimat-backups`.
   "Manage R2 API Tokens" ile erişim anahtarı üret.
4. **Resend**: hesap aç, domaini doğrula (DNS'e DKIM/SPF kayıtları), API anahtarı al.

### DNS kayıtları

| Tip | Ad | Değer |
|-----|-----|-------|
| A | `api` | sunucu IP |
| A | `admin` | sunucu IP |

> Cloudflare kullanıyorsan bu iki kaydı **DNS only** (gri bulut) yap. Proxy (turuncu
> bulut) açıkken Caddy Let's Encrypt doğrulamasını tamamlayamaz.

---

## 2. Sunucu kurulumu

```bash
ssh root@<sunucu-ip>

# Sistem güncel + Docker
apt update && apt upgrade -y
curl -fsSL https://get.docker.com | sh

# Güvenlik duvarı: yalnız SSH ve web
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable

# Yedeklerin R2'ye gitmesi için
apt install -y rclone
```

**SSH sertleştirme** (şiddetle önerilir) — `/etc/ssh/sshd_config` içinde
`PermitRootLogin prohibit-password` ve `PasswordAuthentication no`, ardından
`systemctl restart ssh`. Öncesinde SSH anahtarınla girebildiğinden emin ol.

---

## 3. Yapılandırma

```bash
git clone <repo-url> /opt/itimat
cd /opt/itimat/deploy

cp .env.production.example .env.production
chmod 600 .env.production     # secret dosyası, başkası okumasın
nano .env.production          # her satırın açıklaması dosyanın içinde
```

Rastgele değerleri üret:

```bash
openssl rand -base64 24   # POSTGRES_PASSWORD
openssl rand -base64 48   # JWT_SECRET  (en az 32 karakter, kısaysa uygulama açılmaz)
```

> **Tırnak kuralı:** `SMTP_FROM` gibi `<` `>` içeren değerler tırnak içinde
> yazılmalı (`"İtimat <noreply@ornek.com>"`). Şablonda öyle; bozarsan yedekleme
> scripti bu dosyayı okurken hata verir.

### rclone (yedekler için)

```bash
rclone config
# n) yeni remote → ad: r2 → tür: s3 → sağlayıcı: Cloudflare
# access_key_id / secret_access_key: R2 anahtarların
# endpoint: <hesap-id>.r2.cloudflarestorage.com
rclone lsd r2:            # bucket'ları listeliyorsa yapılandırma doğru
```

---

## 4. Admin panelini derle

Panel statik dosya olarak servis edilir; derleme çıktısı compose tarafından
bağlanır. **Bu adım atlanırsa `admin.<domain>` boş/404 döner.**

```bash
cd /opt/itimat/admin-panel
npm ci
VITE_API_BASE_URL=https://api.<domain>/api/v1 npm run build   # → dist/
```

> `VITE_API_BASE_URL` derleme anında gömülür; domain değişirse panel yeniden
> derlenmelidir.

---

## 5. İlk deploy

```bash
cd /opt/itimat/deploy
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

Sırasıyla: db ayağa kalkar → sağlıklı olunca api başlar (migration'ları kendisi
koşar) → Caddy sertifikaları alır (ilk sefer ~30 sn).

### Doğrulama

```bash
curl -fsS https://api.<domain>/ready
# beklenen: {"database":"ok","service":"itimat-api","status":"ready"}

curl -fsS -o /dev/null -w '%{http_code}\n' https://api.<domain>/api/v1/auth/me
# beklenen: 401  (korumalı uç — kimliksiz erişilemiyor)

curl -fsS https://admin.<domain>/ | head -3
# beklenen: panelin index.html'i

docker compose -f docker-compose.prod.yml --env-file .env.production ps
# api ve db "healthy" görünmeli
```

> `/health` ile `/ready` farkı: `/health` yalnızca sürecin ayakta olduğunu söyler
> ve **bilerek DB'ye dokunmaz**; `/ready` veritabanını da kontrol eder. Deploy
> doğrulamasında `/ready` kullan.

---

## 6. Güncelleme

```bash
cd /opt/itimat
git pull
cd admin-panel && VITE_API_BASE_URL=https://api.<domain>/api/v1 npm run build   # panel değiştiyse
cd ../deploy
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build api
```

> **Restart ≠ yeni kod.** Süreç ayakta diye yeni sürüm çalışıyor sanma — bu hata
> daha önce yaşandı (`docs/progress.md`, 2026-08-01). Güncelleme sonrası o sürümde
> gerçekten değişen bir davranışı test et; en azından:
> `docker compose ... logs api --since 2m` ile yeni başlangıç loglarını gör.

---

## 7. Yedekleme

`backup.sh`: `pg_dump` → gzip → doğrulama → R2 → 7 günlük rotasyon.
Yedek **bozuksa veya içi boşsa script hata verir ve dosyayı siler** — sessizce
"başarılı" demez.

Cron (her gece 03:00 — scheduler 02:00'da çalıştığı için çakışmaz):

```bash
crontab -e
0 3 * * * /opt/itimat/deploy/backup.sh >> /var/log/itimat-backup.log 2>&1
```

### Geri yükleme provası (ATLAMA)

Test edilmemiş yedek, olmayan yedekle aynıdır. Kurulumdan sonra **bir kez** prova yap:

```bash
./backup.sh                                   # yedek al
./restore.sh backups/itimat_<tarih>.sql.gz    # geri yükle ('evet' onayı ister)
curl -fsS https://api.<domain>/ready          # sonrasında sağlıklı mı?
```

`restore.sh` geri yükleme boyunca API'yi durdurur (yarı yazılmış veri olmasın),
sonra yeniden başlatır.

---

## 8. İşletme

**Loglar**
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production logs -f api
docker compose -f docker-compose.prod.yml --env-file .env.production logs --since 1h api
```
Uygulama JSON formatında loglar; Caddy erişim logları `caddy_data` volume'ünde.

**Veritabanına elle bağlanma** (port dışa açık değil — SSH tüneli):
```bash
docker compose -f docker-compose.prod.yml --env-file .env.production exec db \
  psql -U itimat -d itimat
```

**Disk takibi** — fotoğraflar R2'de ama Docker imajları ve loglar birikir:
```bash
df -h && docker system df
docker system prune -f          # kullanılmayan imaj/katman temizliği
```

---

## 9. Bilinen tuzaklar

| Belirti | Sebep | Çözüm |
|---|---|---|
| Mail gitmiyor ama hata da yok | `SMTP_USER`/`SMTP_PASSWORD` boş → Noop devrede, kod yalnızca loga basılır | `.env.production` doldur, **gerçek** şifre sıfırlama isteğiyle test et |
| Mail yine gitmiyor, log'da hata | Yanlış SMTP bilgisi sessizce yutuluyor | `logs api \| grep -i mail`; Resend'de domain doğrulanmış mı bak |
| Fotoğraflar restart'ta kayboluyor | `S3_ENDPOINT` boş → yerel disk, container katmanı kalıcı değil | R2 ayarlarını doldur |
| Fotoğraflar 404 | `S3_PUBLIC_BASE` yanlış | R2'deki genel URL ile birebir aynı olmalı |
| Panelde sayfa yenileyince 404 | SPA fallback | Caddyfile'daki `try_files` satırı duruyor mu |
| Panel boş / 404 | `admin-panel/dist` derlenmemiş | Adım 4'ü çalıştır |
| Sertifika alınamıyor | Cloudflare proxy açık veya DNS yayılmamış | Kaydı "DNS only" yap, `dig api.<domain>` ile doğrula |
| Panelden API'ye istek CORS hatası | `CORS_ALLOW_ORIGINS` ≠ panelin gerçek origin'i | Compose bunu `https://admin.${DOMAIN}` olarak verir; DOMAIN doğru mu bak |

---

## Doğrulama kaydı (2026-08-02, yerel)

Bu klasördeki her şey sunucuya çıkmadan önce yerelde çalıştırıldı:

- `docker compose config` geçerli; imaj **derlendi**, db+api ayağa kalktı.
- **Migration'lar koştu** → 22 tablo, PostGIS 3.4 aktif (`postgis_version()`).
- `/ready` → `{"database":"ok",...}`, `/api/v1/venues` gerçek sorgu döndü,
  korumalı uç **401** verdi.
- `caddy validate` → "Valid configuration" (uyarısız); SPA fallback ve güvenlik
  başlıkları HTTPS üzerinden test edildi.
- **Yedek → sil → geri yükle** döngüsü: silinen kayıt geri geldi, API sağlıklı kaldı.

Bu sırada bulunup düzeltilen iki gerçek hata:

1. **Healthcheck kırıktı** — `localhost` alpine'da önce IPv6'ya (`::1`) çözülüyor,
   uygulama IPv4'te dinliyor → container sonsuza dek "unhealthy" kalırdı.
   `127.0.0.1` ile düzeltildi.
2. **Yedekleme scripti hiç çalışmıyordu** — env dosyası `source` edilince
   `SMTP_FROM` içindeki `<` shell yönlendirmesi sanılıyordu. Scriptler artık
   dosyayı source etmiyor, gereken anahtarları ayrıştırarak okuyor.
