package config

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL      string
	JWTSecret        string
	Port             string
	StorageURL       string
	StorageBucket    string
	GoogleClientID   string
	GoogleMapsAPIKey string

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

		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USER"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     getEnv("SMTP_FROM", "Caiz mi? <noreply@caizmi.com>"),

		VerificationPeriodDays:  getEnvInt("VERIFICATION_PERIOD_DAYS", 2),
		VerificationWarningDays: getEnvInt("VERIFICATION_WARNING_DAYS", 1),
		SchedulerRunHour:        getEnvInt("SCHEDULER_RUN_HOUR", 2),
	}
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
