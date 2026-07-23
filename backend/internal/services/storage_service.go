package services

import (
	"context"
	"fmt"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
)

// StorageService — fotoğraf yükleme işlemlerini yönetir.
// Şu an local disk'e kaydeder; ileride S3 ile değiştirilebilir.
//
// Upload/DownloadAndStore artık TAM URL değil, dosya ANAHTARI (key) döndürür;
// anahtar veritabanına yazılır ve genel URL okuma anında PublicURL ile üretilir.
//
// Neden: tam URL saklandığında ortam her değiştiğinde veri migrasyonu gerekiyordu.
// Android emülatörü için localhost -> LAN IP değişiminde bu bedel bir kez ödendi
// (ve food_categories tablosu o sırada gözden kaçtı). Prod'a geçiş ve S3 taşıması
// aynı bedeli tekrar doğururdu.
type StorageService struct {
	blobs      BlobStore
	httpClient *http.Client
}

// NewStorageService — yerel disk arka ucuyla servis kurar (geriye dönük imza).
func NewStorageService(baseDir, baseURL string) *StorageService {
	return NewStorageServiceWithBackend(NewLocalBlobStore(baseDir, baseURL))
}

// NewStorageServiceWithBackend — arka ucu dışarıdan verilen servis.
// S3/MinIO'ya geçerken yalnızca burası değişir; politika katmanı aynı kalır.
func NewStorageServiceWithBackend(blobs BlobStore) *StorageService {
	return &StorageService{
		blobs: blobs,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
			// Places Photo API isteği googleusercontent.com'a yönlendirir; bu
			// meşru. Ancak yönlendirme hedefi denetlenmezse allowlist delinir:
			// izinli bir host, saldırganın seçtiği iç adrese redirect edebilir.
			// Bu yüzden her adım yeniden doğrulanır.
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 10 {
					return fmt.Errorf("çok fazla yönlendirme")
				}
				return validateRemotePhotoURL(req.URL.String())
			},
		},
	}
}

// PublicURL — depolanmış anahtarı istemcinin erişebileceği tam URL'e çevirir.
//
// Geriye dönük uyumluluk: anahtar zaten "http://" veya "https://" ile başlıyorsa
// (migration öncesinden kalan eski kayıtlar) olduğu gibi döndürülür. Böylece
// migration uygulanmamış bir ortamda fotoğraflar kırılmaz.
// Boş anahtar boş string döner — çağıran taraf "görsel yok" durumunu ayırt edebilsin.
func (s *StorageService) PublicURL(key string) string {
	if key == "" {
		return ""
	}
	if strings.HasPrefix(key, "http://") || strings.HasPrefix(key, "https://") {
		return key
	}
	return s.blobs.PublicURL(key)
}

// Upload — dosyayı diske kaydeder, dosya ANAHTARINI döndürür (tam URL değil).
func (s *StorageService) Upload(_ context.Context, file multipart.File, filename string) (string, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
		return "", fmt.Errorf("desteklenmeyen dosya türü: %s", ext)
	}

	uniqueName := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().UnixMilli(), ext)

	if err := s.blobs.Put(context.Background(), uniqueName, file, contentTypeForExt(ext)); err != nil {
		return "", err
	}
	return uniqueName, nil
}

// contentTypeForExt — S3 gibi arka uçlarda doğru Content-Type şart:
// yanlışsa tarayıcı görseli indirmeye çalışır, göstermek yerine.
func contentTypeForExt(ext string) string {
	switch ext {
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	default:
		return "image/jpeg"
	}
}

// DownloadAndStore — uzak bir URL'den fotoğrafı indirir, diske kaydeder ve kendi URL'sini döndürür.
// Google Places Photo API gibi redirect'li URL'leri de destekler.
func (s *StorageService) DownloadAndStore(ctx context.Context, photoURL string) (string, error) {
	// SSRF koruması: adres kullanıcıdan geliyor, doğrulanmadan fetch edilemez.
	if err := validateRemotePhotoURL(photoURL); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, photoURL, nil)
	if err != nil {
		return "", fmt.Errorf("istek oluşturulamadı: %w", err)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("fotoğraf indirilemedi: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("fotoğraf indirme başarısız, status: %d", resp.StatusCode)
	}

	// İçerik tipinden uzantıyı belirle
	contentType := resp.Header.Get("Content-Type")
	ext := ".jpg"
	switch {
	case strings.Contains(contentType, "png"):
		ext = ".png"
	case strings.Contains(contentType, "webp"):
		ext = ".webp"
	}

	uniqueName := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().UnixMilli(), ext)

	if err := s.blobs.Put(ctx, uniqueName, resp.Body, contentTypeForExt(ext)); err != nil {
		return "", err
	}
	return uniqueName, nil
}

// Delete — dosyayı diskten siler.
// Delete — anahtarla (veya geriye dönük uyumluluk için tam URL'le) dosyayı siler.
// filepath.Base her iki biçimde de doğru dosya adını verir ve aynı zamanda
// path traversal'a karşı korur ("../../etc/passwd" -> "passwd").
func (s *StorageService) Delete(ctx context.Context, keyOrURL string) error {
	return s.blobs.Delete(ctx, filepath.Base(keyOrURL))
}
