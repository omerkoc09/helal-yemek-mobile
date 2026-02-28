package main

import (
	"log"

	"github.com/omerkoc/caiz-mi/internal/config"
	"github.com/omerkoc/caiz-mi/internal/database"
)

func main() {
	cfg := config.Load()

	if cfg.DatabaseURL == "" {
		log.Fatal("DATABASE_URL ortam değişkeni tanımlı değil")
	}

	if err := database.RunMigrations(cfg.DatabaseURL); err != nil {
		log.Fatalf("Migration hatası: %v", err)
	}
	log.Println("Migration'lar başarıyla tamamlandı")
}
