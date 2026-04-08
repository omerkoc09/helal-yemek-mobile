package services

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
)

// StorageService — fotoğraf yükleme işlemlerini yönetir.
// Şu an local disk'e kaydeder; ileride S3 ile değiştirilebilir.
type StorageService struct {
	baseDir    string // örn: "./uploads"
	baseURL    string // örn: "http://localhost:8080/static"
	httpClient *http.Client
}

func NewStorageService(baseDir, baseURL string) *StorageService {
	_ = os.MkdirAll(baseDir, 0755)
	return &StorageService{
		baseDir:    baseDir,
		baseURL:    baseURL,
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}
}

// Upload — dosyayı diske kaydeder, erişim URL'sini döndürür.
func (s *StorageService) Upload(_ context.Context, file multipart.File, filename string) (string, error) {
	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
		return "", fmt.Errorf("desteklenmeyen dosya türü: %s", ext)
	}

	uniqueName := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().UnixMilli(), ext)
	destPath := filepath.Join(s.baseDir, uniqueName)

	dest, err := os.Create(destPath)
	if err != nil {
		return "", fmt.Errorf("dosya oluşturulamadı: %w", err)
	}
	defer dest.Close()

	if _, err := io.Copy(dest, file); err != nil {
		return "", fmt.Errorf("dosya yazılamadı: %w", err)
	}

	return fmt.Sprintf("%s/%s", strings.TrimRight(s.baseURL, "/"), uniqueName), nil
}

// DownloadAndStore — uzak bir URL'den fotoğrafı indirir, diske kaydeder ve kendi URL'sini döndürür.
// Google Places Photo API gibi redirect'li URL'leri de destekler.
func (s *StorageService) DownloadAndStore(ctx context.Context, photoURL string) (string, error) {
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
	destPath := filepath.Join(s.baseDir, uniqueName)

	dest, err := os.Create(destPath)
	if err != nil {
		return "", fmt.Errorf("dosya oluşturulamadı: %w", err)
	}
	defer dest.Close()

	if _, err := io.Copy(dest, resp.Body); err != nil {
		return "", fmt.Errorf("dosya yazılamadı: %w", err)
	}

	return fmt.Sprintf("%s/%s", strings.TrimRight(s.baseURL, "/"), uniqueName), nil
}

// Delete — dosyayı diskten siler.
func (s *StorageService) Delete(_ context.Context, fileURL string) error {
	filename := filepath.Base(fileURL)
	return os.Remove(filepath.Join(s.baseDir, filename))
}
