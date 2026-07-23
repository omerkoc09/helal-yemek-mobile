package services

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// s3BlobStore — S3 uyumlu nesne depolama arka ucu.
//
// minio-go tercih edildi (aws-sdk-go-v2 yerine): S3 API'si standart olduğu için
// aynı kod AWS S3, Cloudflare R2, DigitalOcean Spaces ve MinIO ile çalışır,
// bağımlılık yükü belirgin şekilde daha az.
//
// Bilinen sınır: statik erişim anahtarı kullanır. AWS'de IAM rol tabanlı
// kimlik (anahtarsız) gerekirse aws-sdk-go-v2'ye geçilmeli — bu geçiş
// BlobStore arayüzünün arkasında kalır, çağıran kod etkilenmez.
type s3BlobStore struct {
	client     *minio.Client
	bucket     string
	publicBase string // CDN veya bucket'ın genel adresi
}

// S3Config — S3 arka ucu ayarları.
type S3Config struct {
	Endpoint   string // "s3.amazonaws.com", "<hesap>.r2.cloudflarestorage.com", "localhost:9000"
	AccessKey  string
	SecretKey  string
	Bucket     string
	Region     string
	UseSSL     bool
	PublicBase string // boşsa endpoint+bucket'tan türetilir
}

// NewS3BlobStore — S3 uyumlu arka uç kurar.
// Bucket'ın varlığı burada DOĞRULANIR; yanlış yapılandırma prod'da ilk fotoğraf
// yüklenene kadar gizli kalmasın diye açılışta hata verilir.
func NewS3BlobStore(ctx context.Context, cfg S3Config) (BlobStore, error) {
	if cfg.Endpoint == "" || cfg.Bucket == "" {
		return nil, fmt.Errorf("S3 endpoint ve bucket zorunludur")
	}

	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
		Region: cfg.Region,
	})
	if err != nil {
		return nil, fmt.Errorf("S3 istemcisi oluşturulamadı: %w", err)
	}

	exists, err := client.BucketExists(ctx, cfg.Bucket)
	if err != nil {
		return nil, fmt.Errorf("S3 bucket kontrolü başarısız: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("S3 bucket bulunamadı: %s", cfg.Bucket)
	}

	publicBase := strings.TrimRight(cfg.PublicBase, "/")
	if publicBase == "" {
		scheme := "http"
		if cfg.UseSSL {
			scheme = "https"
		}
		publicBase = fmt.Sprintf("%s://%s/%s", scheme, cfg.Endpoint, cfg.Bucket)
	}

	return &s3BlobStore{client: client, bucket: cfg.Bucket, publicBase: publicBase}, nil
}

func (s *s3BlobStore) Put(ctx context.Context, key string, r io.Reader, contentType string) error {
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	// Boyut bilinmiyor (-1): minio çok parçalı yüklemeye geçer.
	_, err := s.client.PutObject(ctx, s.bucket, key, r, -1, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return fmt.Errorf("S3'e yazılamadı: %w", err)
	}
	return nil
}

func (s *s3BlobStore) Delete(ctx context.Context, key string) error {
	if err := s.client.RemoveObject(ctx, s.bucket, key, minio.RemoveObjectOptions{}); err != nil {
		return fmt.Errorf("S3'ten silinemedi: %w", err)
	}
	return nil
}

func (s *s3BlobStore) PublicURL(key string) string {
	return fmt.Sprintf("%s/%s", s.publicBase, strings.TrimLeft(key, "/"))
}
