//go:build integration

package services

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
)

// newTestMinioClient — bucket kurulumu için doğrudan istemci.
func newTestMinioClient(t *testing.T, cfg S3Config) *minio.Client {
	t.Helper()
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		t.Fatalf("test istemcisi oluşturulamadı: %v", err)
	}
	return client
}

func minioMakeBucketOptions() minio.MakeBucketOptions { return minio.MakeBucketOptions{} }

// S3 arka ucunu GERÇEK bir S3 uyumlu sunucuya (MinIO) karşı sınar.
// Prod'da AWS S3 / Cloudflare R2 / DigitalOcean Spaces kullanılacak; S3 API'si
// standart olduğu için aynı kod hepsiyle çalışır.

const (
	testBucket    = "test-bucket"
	testAccessKey = "minioadmin"
	testSecretKey = "minioadmin"
)

// startMinIO — testlik MinIO konteyneri başlatır, endpoint döndürür.
func startMinIO(ctx context.Context, t *testing.T) string {
	t.Helper()

	req := testcontainers.ContainerRequest{
		Image:        "minio/minio:latest",
		ExposedPorts: []string{"9000/tcp"},
		Env: map[string]string{
			"MINIO_ROOT_USER":     testAccessKey,
			"MINIO_ROOT_PASSWORD": testSecretKey,
		},
		Cmd:        []string{"server", "/data"},
		WaitingFor: wait.ForHTTP("/minio/health/live").WithPort("9000/tcp").WithStartupTimeout(90 * time.Second),
	}

	container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})
	if err != nil {
		t.Fatalf("MinIO başlatılamadı: %v", err)
	}
	t.Cleanup(func() { _ = container.Terminate(context.Background()) })

	host, err := container.Host(ctx)
	if err != nil {
		t.Fatalf("host alınamadı: %v", err)
	}
	port, err := container.MappedPort(ctx, "9000")
	if err != nil {
		t.Fatalf("port alınamadı: %v", err)
	}
	return fmt.Sprintf("%s:%s", host, port.Port())
}

func TestS3BlobStore(t *testing.T) {
	ctx := context.Background()
	endpoint := startMinIO(ctx, t)

	cfg := S3Config{
		Endpoint:  endpoint,
		AccessKey: testAccessKey,
		SecretKey: testSecretKey,
		Bucket:    testBucket,
		UseSSL:    false,
	}

	// Bucket henüz yok: kurulum HATA vermeli. Yanlış yapılandırma ilk fotoğraf
	// yüklenene kadar gizli kalmamalı.
	t.Run("olmayan bucket ile kurulum başarısız", func(t *testing.T) {
		if _, err := NewS3BlobStore(ctx, cfg); err == nil {
			t.Fatal("olmayan bucket için hata beklenmişti")
		}
	})

	createBucket(ctx, t, cfg)

	store, err := NewS3BlobStore(ctx, cfg)
	if err != nil {
		t.Fatalf("S3 arka ucu kurulamadı: %v", err)
	}

	t.Run("yazılan nesne geri okunabilir", func(t *testing.T) {
		content := []byte("sahte-jpeg-verisi")
		key := "test-foto.jpg"

		if err := store.Put(ctx, key, bytes.NewReader(content), "image/jpeg"); err != nil {
			t.Fatalf("Put başarısız: %v", err)
		}

		// Genel URL üzerinden erişilebilmeli (bucket anonim okumaya açıldı).
		got := fetch(t, store.PublicURL(key))
		if !bytes.Equal(got, content) {
			t.Fatalf("içerik eşleşmiyor: %q", got)
		}
	})

	t.Run("Content-Type korunur", func(t *testing.T) {
		// Yanlış Content-Type tarayıcıyı görseli göstermek yerine indirmeye iter.
		key := "tip-testi.png"
		if err := store.Put(ctx, key, bytes.NewReader([]byte("png")), "image/png"); err != nil {
			t.Fatalf("Put başarısız: %v", err)
		}
		resp, err := http.Get(store.PublicURL(key))
		if err != nil {
			t.Fatalf("GET başarısız: %v", err)
		}
		defer resp.Body.Close()
		if ct := resp.Header.Get("Content-Type"); ct != "image/png" {
			t.Fatalf("Content-Type %q, beklenen image/png", ct)
		}
	})

	t.Run("silinen nesne erişilemez olur", func(t *testing.T) {
		key := "silinecek.jpg"
		if err := store.Put(ctx, key, bytes.NewReader([]byte("x")), "image/jpeg"); err != nil {
			t.Fatalf("Put başarısız: %v", err)
		}
		if err := store.Delete(ctx, key); err != nil {
			t.Fatalf("Delete başarısız: %v", err)
		}

		resp, err := http.Get(store.PublicURL(key))
		if err != nil {
			t.Fatalf("GET başarısız: %v", err)
		}
		defer resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			t.Fatal("silinen nesne hâlâ erişilebilir")
		}
	})

	t.Run("PublicURL anahtarı adrese çevirir", func(t *testing.T) {
		url := store.PublicURL("abc.jpg")
		if url == "" || url == "abc.jpg" {
			t.Fatalf("beklenmeyen URL: %q", url)
		}
	})
}

// createBucket — testlik bucket'ı oluşturur ve anonim okumaya açar.
func createBucket(ctx context.Context, t *testing.T, cfg S3Config) {
	t.Helper()
	client := newTestMinioClient(t, cfg)
	if err := client.MakeBucket(ctx, cfg.Bucket, minioMakeBucketOptions()); err != nil {
		t.Fatalf("bucket oluşturulamadı: %v", err)
	}
	policy := fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::%s/*"]}]}`, cfg.Bucket)
	if err := client.SetBucketPolicy(ctx, cfg.Bucket, policy); err != nil {
		t.Fatalf("bucket politikası ayarlanamadı: %v", err)
	}
}

func fetch(t *testing.T, url string) []byte {
	t.Helper()
	resp, err := http.Get(url)
	if err != nil {
		t.Fatalf("GET başarısız: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("gövde okunamadı: %v", err)
	}
	return body
}
