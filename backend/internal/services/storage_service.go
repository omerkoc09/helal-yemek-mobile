package services

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
)

// StorageService — fotoğraf yükleme işlemlerini yönetir.
// Şu an local disk'e kaydeder; ileride S3 ile değiştirilebilir.
type StorageService struct {
	baseDir string // örn: "./uploads"
	baseURL string // örn: "http://localhost:8080/static"
}

func NewStorageService(baseDir, baseURL string) *StorageService {
	_ = os.MkdirAll(baseDir, 0755)
	return &StorageService{baseDir: baseDir, baseURL: baseURL}
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

// Delete — dosyayı diskten siler.
func (s *StorageService) Delete(_ context.Context, fileURL string) error {
	filename := filepath.Base(fileURL)
	return os.Remove(filepath.Join(s.baseDir, filename))
}
