package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL    string
	JWTSecret      string
	Port           string
	StorageURL     string
	StorageBucket  string
	GoogleClientID string
}

func Load() *Config {
	_ = godotenv.Load()
	return &Config{
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		JWTSecret:      os.Getenv("JWT_SECRET"),
		Port:           getEnv("PORT", "8080"),
		StorageURL:     os.Getenv("STORAGE_URL"),
		StorageBucket:  os.Getenv("STORAGE_BUCKET"),
		GoogleClientID: os.Getenv("GOOGLE_CLIENT_ID"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
