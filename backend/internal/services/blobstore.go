package services

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// BlobStore — ham dosya depolama arka ucu (yerel disk, S3, MinIO, R2...).
//
// StorageService ile ayrımın mantığı: uzantı doğrulama, anahtar üretimi ve
// SSRF koruması arka uçtan BAĞIMSIZ politikalardır ve StorageService'te kalır.
// Burada yalnızca baytların nereye yazıldığı ve nasıl adreslendiği değişir.
type BlobStore interface {
	// Put — anahtarla veri yazar. contentType boş olabilir.
	Put(ctx context.Context, key string, r io.Reader, contentType string) error
	// Delete — anahtarla veriyi siler.
	Delete(ctx context.Context, key string) error
	// PublicURL — anahtarı istemcinin erişebileceği adrese çevirir.
	PublicURL(key string) string
}

// ── Yerel disk arka ucu ──────────────────────────────────────────────────────

type localBlobStore struct {
	baseDir string // örn: "./uploads"
	baseURL string // örn: "http://localhost:8080/static"
}

// NewLocalBlobStore — dosyaları yerel diske yazan arka uç.
//
// UYARI: container katmanı kalıcı değildir. Prod'da ya volume bağlanmalı ya da
// S3 arka ucuna geçilmelidir; aksi halde her restart'ta fotoğraflar kaybolur.
func NewLocalBlobStore(baseDir, baseURL string) BlobStore {
	_ = os.MkdirAll(baseDir, 0o755)
	return &localBlobStore{baseDir: baseDir, baseURL: baseURL}
}

func (l *localBlobStore) Put(_ context.Context, key string, r io.Reader, _ string) error {
	// filepath.Base path traversal'a karşı korur ("../../etc/passwd" -> "passwd").
	dest, err := os.Create(filepath.Join(l.baseDir, filepath.Base(key)))
	if err != nil {
		return fmt.Errorf("dosya oluşturulamadı: %w", err)
	}
	defer dest.Close()

	if _, err := io.Copy(dest, r); err != nil {
		return fmt.Errorf("dosya yazılamadı: %w", err)
	}
	return nil
}

func (l *localBlobStore) Delete(_ context.Context, key string) error {
	return os.Remove(filepath.Join(l.baseDir, filepath.Base(key)))
}

func (l *localBlobStore) PublicURL(key string) string {
	return fmt.Sprintf("%s/%s", strings.TrimRight(l.baseURL, "/"), strings.TrimLeft(key, "/"))
}
