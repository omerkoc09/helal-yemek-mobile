# Google Sign-In (Firebase) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Firebase credential dosyalarını kullanarak backend ve Flutter mobil uygulamaya çalışır hâlde Google Sign-In desteği eklemek.

**Architecture:** Backend `auth_service.go`'da `LoginWithGoogle()` ve config `GoogleClientID` alanı zaten mevcut — sadece `.env`'de değer eksik. Mobile tarafında `signInWithGoogle()` yazılmış ama iOS URL scheme ve Android Google Services Gradle plugin eksik. Kullanıcı Firebase Console'dan credential dosyalarını sağlayacak; bu plan kod altyapısını hazırlar ve credential'ların nereye konulacağını netleştirir.

**Tech Stack:** Go + Fiber (backend), Flutter + Riverpod (mobile), google_sign_in ^7.2.0, Firebase Console, Google Services Gradle plugin 4.4.x, google.golang.org/api/idtoken (backend token doğrulama)

---

## Dosya Haritası

| Dosya | İşlem | Neden |
|-------|-------|-------|
| `backend/.env` | Modify | `GOOGLE_CLIENT_ID=` placeholder ekle |
| `mobile/ios/Runner/Info.plist` | Modify | `CFBundleURLTypes` (REVERSED_CLIENT_ID) ve `GIDServerClientID` ekle |
| `mobile/android/settings.gradle.kts` | Modify | `com.google.gms.google-services` plugin declare et |
| `mobile/android/app/build.gradle.kts` | Modify | Google Services plugin'i uygula |
| `mobile/ios/Runner/GoogleService-Info.plist` | **Kullanıcı koyar** | Firebase Console'dan indirilir |
| `mobile/android/app/google-services.json` | **Kullanıcı koyar** | Firebase Console'dan indirilir |

---

## Task 1: Backend — GOOGLE_CLIENT_ID placeholder ekle

**Files:**
- Modify: `backend/.env`

> Bu task'ta test yoktur — config değişikliği. Değerin doğru yüklenip yüklenmediği Task 5'te (entegrasyon) doğrulanır.

- [ ] **Step 1: `.env`'e `GOOGLE_CLIENT_ID` satırını ekle**

`backend/.env` dosyasını aç. Mevcut `GOOGLE_MAPS_API_KEY` satırının altına şunu ekle:

```
# Google OAuth 2.0 Web Client ID (Firebase Console → Authentication → Sign-in method → Google → Web SDK configuration)
GOOGLE_CLIENT_ID=
```

Değeri şimdi boş bırak; Firebase kurulumu (Task 4) bittikten sonra doldurulacak.

- [ ] **Step 2: Config'in alanı okuduğunu teyit et**

`backend/internal/config/config.go` dosyasında şu satır zaten var:

```go
GoogleClientID: os.Getenv("GOOGLE_CLIENT_ID"),
```

Ve `backend/internal/services/auth_service.go` içinde:

```go
func NewAuthService(userRepo *repository.UserRepo, jwtSecret, googleClientID string) *AuthService {
    return &AuthService{
        ...
        googleClientID: googleClientID,
    }
}
```

Başka değişiklik gerekmez — altyapı hazır.

- [ ] **Step 3: Commit**

```bash
git add backend/.env
git commit -m "config: add GOOGLE_CLIENT_ID placeholder to .env"
```

---

## Task 2: iOS — Google Sign-In URL Scheme ve Server Client ID

**Files:**
- Modify: `mobile/ios/Runner/Info.plist`

> iOS'ta Google Sign-In redirect callback için URL scheme zorunludur. `REVERSED_CLIENT_ID`, `GoogleService-Info.plist`'ten gelir (örn. `com.googleusercontent.apps.123456-abc`). `GIDServerClientID`, backend'in ID token'ı doğrulamak için kullandığı web client ID'dir.

- [ ] **Step 1: `Info.plist`'e URL scheme ve server client ID ekle**

`mobile/ios/Runner/Info.plist` dosyasında kapanış `</dict>` tag'inden hemen önce şunu ekle:

```xml
	<!-- Google Sign-In: REVERSED_CLIENT_ID değerini GoogleService-Info.plist'ten al -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>REVERSED_CLIENT_ID_BURAYA</string>
			</array>
		</dict>
	</array>
	<!-- Google Sign-In: Firebase Console → Authentication → Google → Web SDK configuration → Web client ID -->
	<key>GIDServerClientID</key>
	<string>WEB_CLIENT_ID_BURAYA</string>
```

`REVERSED_CLIENT_ID_BURAYA` ve `WEB_CLIENT_ID_BURAYA` değerleri Task 4 sonrası gerçek değerlerle değiştirilecek.

- [ ] **Step 2: Commit**

```bash
git add mobile/ios/Runner/Info.plist
git commit -m "config(ios): add Google Sign-In URL scheme and server client ID placeholders"
```

---

## Task 3: Android — Google Services Gradle Plugin

**Files:**
- Modify: `mobile/android/settings.gradle.kts`
- Modify: `mobile/android/app/build.gradle.kts`

> `google-services` plugin, `google-services.json` dosyasını okuyarak Google SDK'larını otomatik konfigüre eder. Android'de Google Sign-In için zorunludur.

- [ ] **Step 1: `settings.gradle.kts`'e Google Services plugin'i declare et**

`mobile/android/settings.gradle.kts` dosyasında mevcut `plugins { ... }` bloğunu bul:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
```

Şu satırı ekleyerek güncelle:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

- [ ] **Step 2: `app/build.gradle.kts`'e plugin'i uygula**

`mobile/android/app/build.gradle.kts` dosyasında mevcut `plugins { ... }` bloğunu bul:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
```

Şu satırı ekleyerek güncelle:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
```

- [ ] **Step 3: Build'in başarılı olduğunu kontrol et**

```bash
cd mobile
flutter build apk --debug 2>&1 | tail -20
```

Beklenen çıktı: `BUILD SUCCESSFUL` veya `✓ Built build/...`

> **Not:** `google-services.json` henüz yok, bu nedenle şu hata çıkabilir: `File google-services.json is missing.` Bu beklenen bir durumdur — Task 4'te dosya eklenecek.

- [ ] **Step 4: Commit**

```bash
git add mobile/android/settings.gradle.kts mobile/android/app/build.gradle.kts
git commit -m "config(android): add Google Services Gradle plugin"
```

---

## Task 4: Firebase Kurulumu (Kullanıcı Aksiyonu)

> Bu task otomatik uygulanamaz — Firebase Console'da elle yapılması gereken adımlar içerir.

- [ ] **Step 1: Firebase projesi oluştur**

1. [Firebase Console](https://console.firebase.google.com)'a git
2. "Add project" → proje adı: `caizmi` (veya istediğin isim)
3. Google Analytics'i dilersen aktif et → Continue

- [ ] **Step 2: Authentication'ı etkinleştir**

Firebase Console → Build → Authentication → Get started → Sign-in method → Google → Enable → Save

Bu ekranda **Web SDK configuration** bölümündeki **Web client ID** değerini kopyala ve güvenli bir yere kaydet — Task 5'te kullanacaksın.

- [ ] **Step 3: iOS uygulamasını kaydet**

Firebase Console → Project settings → Your apps → Add app → iOS

- Bundle ID: `com.caizmi.caiz_mi`
- App nickname: `Caiz Mi iOS`
- App Store ID: (boş bırakabilirsin)

Download `GoogleService-Info.plist` → `mobile/ios/Runner/` klasörüne koy (Xcode'dan da ekleyebilirsin).

`GoogleService-Info.plist` içinden şu değerleri not al:
- `REVERSED_CLIENT_ID`: `com.googleusercontent.apps.XXXXXXXX-xxxx...` formatında
- `CLIENT_ID`: iOS OAuth client ID

- [ ] **Step 4: Android uygulamasını kaydet**

Firebase Console → Project settings → Your apps → Add app → Android

- Package name: `com.caizmi.caiz_mi`
- App nickname: `Caiz Mi Android`
- Debug signing certificate SHA-1: Aşağıdaki komutla al:

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android \
  | grep SHA1
```

Download `google-services.json` → `mobile/android/app/` klasörüne koy.

---

## Task 5: Credential'ları Yerleştir ve Test Et

**Files:**
- Modify: `mobile/ios/Runner/Info.plist` (placeholder'ları gerçek değerlerle değiştir)
- Modify: `backend/.env` (GOOGLE_CLIENT_ID doldur)
- Add: `mobile/ios/Runner/GoogleService-Info.plist` (Task 4'te indirildi)
- Add: `mobile/android/app/google-services.json` (Task 4'te indirildi)

- [ ] **Step 1: iOS `Info.plist` placeholder'larını doldur**

`mobile/ios/Runner/Info.plist` içinde Task 2'de eklediğin bölümde:

- `REVERSED_CLIENT_ID_BURAYA` → `GoogleService-Info.plist`'teki `REVERSED_CLIENT_ID` değeri
- `WEB_CLIENT_ID_BURAYA` → Firebase Console → Authentication → Google → Web SDK config → Web client ID

- [ ] **Step 2: Backend `.env`'e Web client ID'yi yaz**

`backend/.env` dosyasında:

```
GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID_HERE
```

Web client ID formatı: `123456789-xxxxxxxxxxxx.apps.googleusercontent.com`

- [ ] **Step 3: iOS build'ini al ve test et**

```bash
cd mobile
flutter run -d <ios-device-id>
```

Login ekranında Google butonuna bas:
- Google hesap seçim ekranı açılmalı
- Hesap seçilince token alınmalı ve backend'e gönderilmeli
- Uygulama authenticated state'e geçmeli

- [ ] **Step 4: Android build'ini al ve test et**

```bash
cd mobile
flutter run -d <android-device-id>
```

Login ekranında Google butonuna bas — aynı akış geçerli.

- [ ] **Step 5: Backend'i test et**

```bash
# Backend'i başlat (GOOGLE_CLIENT_ID dolu olmalı)
cd backend
go run ./cmd/server/main.go

# Başka terminalden: geçerli bir Google ID token ile test et
# (Flutter'dan alınan token'ı kullanabilirsin)
curl -X POST http://localhost:8080/api/v1/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token": "FLUTTER_DAN_ALINAN_TOKEN"}'
```

Beklenen yanıt:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ..."
}
```

- [ ] **Step 6: Commit**

```bash
git add mobile/ios/Runner/Info.plist backend/.env
# NOT: GoogleService-Info.plist ve google-services.json genellikle .gitignore'a eklenir
# Eğer bunları commit etmek istemiyorsan aşağıdaki .gitignore adımını uygula
git commit -m "feat: configure Google Sign-In with Firebase credentials"
```

- [ ] **Step 7 (Opsiyonel): Credential dosyalarını .gitignore'a ekle**

Firebase credential dosyaları hassas bilgi içerir. Repo'ya commit etmek istemiyorsan:

`mobile/.gitignore` dosyasına ekle:

```
ios/Runner/GoogleService-Info.plist
android/app/google-services.json
```

```bash
git add mobile/.gitignore
git commit -m "chore: gitignore Firebase credential files"
```

---

## Özet: Nereye Ne Girecek

| Değer | Kaynak | Nerede Kullanılır |
|-------|--------|-------------------|
| Web client ID | Firebase Console → Auth → Google → Web SDK config | `backend/.env` → `GOOGLE_CLIENT_ID` ve `Info.plist` → `GIDServerClientID` |
| REVERSED_CLIENT_ID | `GoogleService-Info.plist` → `REVERSED_CLIENT_ID` key | `Info.plist` → `CFBundleURLSchemes` |
| `GoogleService-Info.plist` | Firebase Console → iOS app download | `mobile/ios/Runner/` klasörü |
| `google-services.json` | Firebase Console → Android app download | `mobile/android/app/` klasörü |
