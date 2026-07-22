package config

import (
	"errors"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

// MinJWTSecretLength — HS256 imzalama anahtarı için kabul edilen en kısa uzunluk.
const MinJWTSecretLength = 32

var (
	ErrJWTSecretMissing   = errors.New("JWT_SECRET tanımlı değil")
	ErrJWTSecretTooShort  = errors.New("JWT_SECRET çok kısa")
	ErrDatabaseURLMissing = errors.New("DATABASE_URL tanımlı değil")
)

type Config struct {
	DatabaseURL      string
	JWTSecret        string
	Port             string
	StorageURL       string
	StorageBucket    string
	GoogleClientID   string
	GoogleMapsAPIKey string

	// CORS — admin paneli (web) için izinli origin'ler (virgülle ayrılmış)
	CORSAllowOrigins string

	// SMTP
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPassword string
	SMTPFrom     string

	// Scheduler
	VerificationPeriodDays  int
	VerificationWarningDays int
	SchedulerRunHour        int

	// Loglama
	LogFormat string // "json" (prod) | "text" (geliştirme)
	LogLevel  string // debug | info | warn | error
}

func Load() *Config {
	_ = godotenv.Load()
	return &Config{
		DatabaseURL:      os.Getenv("DATABASE_URL"),
		JWTSecret:        os.Getenv("JWT_SECRET"),
		Port:             getEnv("PORT", "8080"),
		StorageURL:       os.Getenv("STORAGE_URL"),
		StorageBucket:    os.Getenv("STORAGE_BUCKET"),
		GoogleClientID:   os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleMapsAPIKey: os.Getenv("GOOGLE_MAPS_API_KEY"),

		// Varsayılan: tüm origin'lere izin ver (AllowCredentials=false olduğu için güvenli).
		// Production'da CORS_ALLOW_ORIGINS env ile spesifik origin'lere kısıtlanır.
		// Not: Fiber CORS, "http://*" gibi host'suz wildcard'ı reddeder; "tümü" için tek geçerli değer "*".
		CORSAllowOrigins: getEnv("CORS_ALLOW_ORIGINS", "*"),

		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USER"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     getEnv("SMTP_FROM", "Caiz mi? <noreply@caizmi.com>"),

		VerificationPeriodDays:  getEnvInt("VERIFICATION_PERIOD_DAYS", 180),
		VerificationWarningDays: getEnvInt("VERIFICATION_WARNING_DAYS", 14),
		SchedulerRunHour:        getEnvInt("SCHEDULER_RUN_HOUR", 2),

		// Varsayılan json: prod'da log toplama araçları için. Geliştirmede
		// LOG_FORMAT=text daha okunaklı.
		LogFormat: getEnv("LOG_FORMAT", "json"),
		LogLevel:  getEnv("LOG_LEVEL", "info"),
	}
}

// Validate — süreç ayağa kalkmadan önce zorunlu ayarları doğrular.
//
// JWT_SECRET özellikle kritik: tanımsızsa Go boş string döndürür ve HS256 boş
// anahtarla sorunsuz imzalayıp doğrular. Uygulama hatasız açılır ama herkes
// istediği kullanıcı adına token üretebilir. Bu yüzden burada fail-fast yapılır —
// sessiz çalışmaktansa hiç açılmaması yeğdir.
func (c *Config) Validate() error {
	if strings.TrimSpace(c.JWTSecret) == "" {
		return ErrJWTSecretMissing
	}
	if len(c.JWTSecret) < MinJWTSecretLength {
		return ErrJWTSecretTooShort
	}
	if strings.TrimSpace(c.DatabaseURL) == "" {
		return ErrDatabaseURLMissing
	}
	return nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
