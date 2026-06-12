# Web Admin Paneli — Tasarım Dokümanı

> Tarih: 2026-06-12
> Durum: Onaylandı (uygulama planı bekleniyor)

## 1. Amaç ve Bağlam

Şu an admin yönetimi mobil uygulama (Flutter) içindeki ekranlardan yapılıyor. Kullanıcı ve mekan
sayısı arttıkça mobil ekranlar (tablo, filtre, bulk işlem, grafik eksikliği) yetersiz kalıyor.

Çözüm: Mevcut `go-template2-2` Vuetify (Vue 3) admin template'inin **sadece frontend'ini** alıp,
caiz_mi reposuna taşımak ve mevcut caiz_mi Fiber backend'ine (`/api/v1`) bağlamak. Template'in
kendi Go (Haytek) backend'i **tamamen atılır** — caiz_mi backend'i tek doğru kaynak (single source
of truth) olarak kalır, mobil ile aynı veritabanını paylaşır.

### Karar Gerekçeleri
- **Backend dokunulmazlığı:** caiz_mi backend'i canlıya gidiyor; admin paneli için backend'e
  dokunmuyoruz. Mobil regresyon riski sıfır.
- **Tek kaynak:** İki backend bakım yükü (iki migration, iki deploy, veri senkron sorunu) ortadan kalkar.
- **Template değeri frontend'de:** Hazır layout, tema, auth flow, tablo/CRUD bileşeni (`extable`).

## 2. Proje Yerleşimi

```
caiz_mi/
├── backend/          (DOKUNULMAZ — mevcut Fiber API, port 8080, /api/v1)
├── mobile/           (DOKUNULMAZ — Flutter)
└── admin-panel/      (YENİ — go-template2-2/frontend/idare buraya kopyalanır)
    └── src/...
```

- `admin-panel/` caiz_mi reposunun içinde ayrı klasör (tek repo, bağımsız deploy).
- Template'in Go backend'i (`go-template2-2/backend`) kopyalanmaz.

## 3. Backend Format Uyumu — Karar: Frontend'i caiz_mi'ye uyarla

caiz_mi backend'i **düz JSON** döner (liste için JSON dizisi, tekil için JSON obje). Wrapper yok.
Template ise Haytek'in zarflı formatını bekler:
`{ data, data_count, error_code, error_message }`.

**Karar:** Backend'e dokunmadan, frontend'in API katmanı caiz_mi formatına uyarlanır.
Pagination/arama/sıralama **client-side** yapılır (admin liste boyutları makul; performans baskısı yok).
İleride bir liste gerçekten devasa olursa (örn. audit_logs), o spesifik endpoint'e backend'de
`?page=&limit=` eklenir — şimdi YAGNI.

## 4. Auth & ApiService Uyarlaması

### caiz_mi auth gerçekleri
- `POST /api/v1/auth/login` → `{access_token, refresh_token}` (template ile uyumlu ✓)
- `POST /api/v1/auth/refresh` → `{access_token, refresh_token}` (düz, `data.data` değil)
- `GET /api/v1/auth/me` → düz user objesi (template `user/me` + `data.data` bekliyor)
- Kullanıcı `id`: **UUID string** (template `number` bekliyor)
- Rol: string `'traveler' | 'guide' | 'admin'` (template int `1`/`10` bekliyor)

### Değişiklikler
**`src/services/ApiService.ts`:**
- `ApiResponse<T>` wrapper kaldırılır; metodlar `[error, data]` döner, `data` = backend cevabının kendisi.
- Hata yakalama caiz_mi formatına göre: `error.response.data.error` okunur (`error_message` yerine).
- `refresh()`: `data.data.access_token` → `data.access_token`; refresh URL `auth/refresh`.
- `get()`: Haytek query parametreleri (`columns`, `column_types`, `sort_*`) kaldırılır; sade istek
  (client-side filtreleme yapılacağı için query backend'e gönderilmez).

**`src/store/user.ts`:**
- `User.id: number` → `string` (UUID).
- `UserRole = 'admin' | 'teacher' | 'parent'` → `'traveler' | 'guide' | 'admin'`.
- `updateUser()`: `auth/me` çağrısı, wrapper'sız `data`.

**Admin guard:** Login sonrası `role !== 'admin'` ise reddet + logout. Panel yalnızca admin rolüne açık.

**`.env.development`:** `VITE_API_BASE_URL=http://localhost:8080/api/v1`

## 5. extable Bileşeni — Karar: Koru, caiz_mi'ye uyarla

`extable` yetenekli, hazır bir CRUD bileşeni (liste + pagination + sıralama + arama + ekle/düzenle
modal + sil onayı + FormData upload). Korunur, caiz_mi'ye uyarlanır:

- `fetchData()`: caiz_mi'nin düz dizisini alır; `resp.data`/`resp.data_count` yerine dizinin kendisi + `.length`.
- Pagination/arama/sıralama **client-side** (tüm liste bellekte filtrelenir/sayfalanır/sıralanır).
- `apiUrl` her admin kaynağına işaret eder (`admin/venues`, `admin/users`, ...).
- `onEdit`: `GET /:id`'i olmayan kaynaklarda satır verisi doğrudan kullanılır (ekstra fetch yok).
- Modal + form + FormData deseni korunur (mekan düzenleme, fotoğraf upload için değerli).

Tüm liste ekranları bu tek bileşenin üzerine kurulur; hazır CRUD deseni korunur.

## 6. Ekranlar & Endpoint Eşlemesi

Tüm endpointler caiz_mi'de **zaten mevcut** (`backend/cmd/api/main.go`, `/api/v1/admin/*`).
Yeni backend gerekmiyor.

| Ekran | Endpoint(ler) | İşlemler |
|-------|--------------|----------|
| **Dashboard** | mevcut listelerden client-side sayım | Toplam mekan/kullanıcı/bekleyen/başvuru kartları |
| **Mekanlar** | `GET /admin/venues`, `PUT/DELETE /admin/venues/:id`, `.../approve`, `.../reject`, `.../reactivate` | Liste, durum filtresi, onay/red, düzenle, sil, reaktive |
| **Bekleyen Mekanlar** | `GET /admin/venues/pending`, approve/reject | Hızlı onay kuyruğu |
| **Kullanıcılar** | `GET /admin/users`, `PUT/DELETE /admin/users/:id` | Liste, rol değiştir, aktif/pasif, sil (admin kendini silemez) |
| **Guide Başvuruları** | `GET /admin/applications`, `.../approve`, `.../reject` | Liste, onay/red |
| **Düzeltmeler** | `GET /admin/corrections`, `PUT /admin/corrections/:id` | İnceleme, onay/red |
| **Mekan Raporları** | `GET /admin/venue-reports`, `.../resolve` | Liste, çözümle |
| **Audit Log** | `GET /admin/audit-logs` | Salt-okunur işlem geçmişi |
| **Doğrulama Logları** | `GET /admin/verification-logs?tab=`, `POST /admin/scheduler/run` | Tab'lı görünüm, manuel scheduler tetikleme |

### Ortak Desen
- Her liste ekranı = `extable` (client-side pagination/arama/sıralama) + satır aksiyonları.
- Onay popup'ı: template'in `sweetalert2` (`utils/Popup.ts`) — zaten kurulu.
- Navigasyon: sol menü (`layouts/default.vue`) bu 9 öğeyle yeniden düzenlenir.
- Hata/yükleme: `Popup.ts` + Vuetify loading state'leri.

## 7. Kapsam Dışı (YAGNI)
- Backend'e herhangi bir değişiklik (yeni endpoint, wrapper, pagination) — gerçek ihtiyaç doğmadıkça yok.
- Server-side query/pagination — şu an client-side yeterli.
- Yeni admin özellikleri (bulk approve vb.) — mevcut endpoint setiyle sınırlıyız; sonraki iterasyon.
- Template'in kullanılmayan örnek sayfaları (`second-page`, `version`, örnek `users.vue` mock'ları) temizlenir.

## 8. Doğrulama
- `admin-panel/` `npm run dev` ile ayağa kalkar, caiz_mi backend (8080) çalışırken admin login başarılı.
- admin olmayan kullanıcı login'de reddedilir.
- Her ekran ilgili `/admin/*` endpointinden veri çeker; onay/red/sil/düzenle aksiyonları backend'e işler.
- Token expire olunca `auth/refresh` ile sessiz yenileme çalışır.
