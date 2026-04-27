package main

import (
	"log"

	"github.com/gofiber/fiber/v2"
	fiberlogger "github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"

	"github.com/omerkoc/caiz-mi/internal/config"
	"github.com/omerkoc/caiz-mi/internal/database"
	"github.com/omerkoc/caiz-mi/internal/handlers"
	"github.com/omerkoc/caiz-mi/internal/middleware"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

func main() {
	cfg := config.Load()

	// Migration'ları çalıştır
	if err := database.RunMigrations(cfg.DatabaseURL); err != nil {
		log.Fatalf("migration hatası: %v", err)
	}
	log.Println("migration'lar başarıyla çalıştırıldı")

	// Veritabanı havuzu
	pool, err := database.NewPool(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("veritabanı bağlantısı kurulamadı: %v", err)
	}
	defer pool.Close()
	log.Println("veritabanı bağlantısı kuruldu")

	// Repository katmanı
	userRepo := repository.NewUserRepo(pool)
	venueRepo := repository.NewVenueRepo(pool)
	reviewRepo := repository.NewReviewRepo(pool)
	favoriteRepo := repository.NewFavoriteRepo(pool)
	correctionRepo := repository.NewCorrectionRepo(pool)
	guideRepo := repository.NewGuideRepo(pool)
	auditRepo := repository.NewAuditRepo(pool)
	referralRepo := repository.NewReferralRepo(pool)
	venueReportRepo := repository.NewVenueReportRepo(pool)

	// Service katmanı
	authService := services.NewAuthService(userRepo, cfg.JWTSecret, cfg.GoogleClientID)
	storageService := services.NewStorageService("./uploads", cfg.StorageURL+"/static")
	placesService := services.NewPlacesService(cfg.GoogleMapsAPIKey)

	// Handler katmanı
	authHandler := handlers.NewAuthHandler(authService)
	venueHandler := handlers.NewVenueHandler(venueRepo, storageService, placesService)
	reviewHandler := handlers.NewReviewHandler(reviewRepo)
	favoriteHandler := handlers.NewFavoriteHandler(favoriteRepo)
	correctionHandler := handlers.NewCorrectionHandler(correctionRepo, auditRepo)
	guideHandler := handlers.NewGuideHandler(guideRepo, venueRepo, referralRepo)
	adminHandler := handlers.NewAdminHandler(venueRepo, guideRepo, userRepo, auditRepo, referralRepo)
	venueReportHandler := handlers.NewVenueReportHandler(venueReportRepo)

	// Fiber uygulaması
	app := fiber.New(fiber.Config{
		AppName:   "Caiz mi? API v1",
		BodyLimit: 10 * 1024 * 1024, // 10 MB (fotoğraf yükleme için)
	})

	app.Use(recover.New())
	app.Use(fiberlogger.New())

	// Sağlık kontrolü
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"service": "caiz-mi-api",
		})
	})

	// API v1
	api := app.Group("/api/v1")

	// Statik dosyalar (yüklenen fotoğraflar)
	app.Static("/static", "./uploads")

	// Auth endpoint'leri (public)
	auth := api.Group("/auth")
	auth.Post("/register", authHandler.Register)
	auth.Post("/login", authHandler.Login)
	auth.Post("/google", authHandler.GoogleLogin)
	auth.Post("/apple", authHandler.AppleLogin)

	// Auth endpoint'leri (korumalı)
	auth.Post("/refresh", authHandler.Refresh)
	auth.Get("/me", middleware.Auth(cfg.JWTSecret), authHandler.Me)
	auth.Put("/profile", middleware.Auth(cfg.JWTSecret), authHandler.UpdateProfile)

	// Venue endpoint'leri (public)
	api.Get("/venues", venueHandler.List)
	api.Get("/venues/nearby", venueHandler.ListNearby)
	api.Get("/venues/popular", venueHandler.ListPopular)
	api.Get("/venues/by-category/:categoryId", venueHandler.ListByCategory)
	api.Get("/venues/place-preview",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.PlacePreview,
	)
	api.Get("/venues/:id", venueHandler.Detail)
	api.Get("/criteria", venueHandler.ListCriteria)
	api.Get("/food-categories", venueHandler.ListFoodCategories)

	// Venue endpoint'leri (Guide + Admin)
	api.Post("/venues",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		middleware.GuideSubmitLimit(),
		venueHandler.Create,
	)
	api.Post("/venues/:id/photos",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.UploadPhoto,
	)
	api.Delete("/venues/:id/photos/:photoId",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.DeletePhoto,
	)
	api.Put("/venues/:id",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.Update,
	)
	api.Post("/food-categories/:id/items",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.CreateCustomFoodItem,
	)
	api.Post("/venues/:id/confirm",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.ConfirmVenue,
	)

	// Review endpoint'leri
	api.Get("/venues/:id/reviews", reviewHandler.List)
	api.Post("/venues/:id/reviews",
		middleware.Auth(cfg.JWTSecret),
		reviewHandler.Create,
	)
	api.Put("/venues/:id/reviews/:reviewId",
		middleware.Auth(cfg.JWTSecret),
		reviewHandler.Update,
	)
	api.Delete("/venues/:id/reviews/:reviewId",
		middleware.Auth(cfg.JWTSecret),
		reviewHandler.Delete,
	)

	// Favorite endpoint'leri
	fav := api.Group("/favorites", middleware.Auth(cfg.JWTSecret))
	fav.Get("/", favoriteHandler.List)
	fav.Post("/:venueId", favoriteHandler.Add)
	fav.Delete("/:venueId", favoriteHandler.Remove)

	// Venue report endpoint'leri
	api.Post("/venues/:id/reports",
		middleware.Auth(cfg.JWTSecret),
		venueReportHandler.Create,
	)

	// Correction endpoint'leri (Guide)
	api.Post("/venues/:id/corrections",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		correctionHandler.Create,
	)

	// Guide endpoint'leri
	guide := api.Group("/guide", middleware.Auth(cfg.JWTSecret))
	guide.Post("/apply", guideHandler.Apply)
	guide.Get("/my-venues",
		middleware.RequireRole("guide", "admin"),
		guideHandler.MyVenues,
	)
	guide.Get("/my-referral-code",
		middleware.RequireRole("guide", "admin"),
		guideHandler.MyReferralCode,
	)

	// Admin endpoint'leri
	admin := api.Group("/admin",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("admin"),
	)

	// Venues
	admin.Get("/venues", adminHandler.ListAllVenues)
	admin.Get("/venues/pending", adminHandler.ListPendingVenues)
	admin.Put("/venues/:id", adminHandler.UpdateVenue)
	admin.Delete("/venues/:id", adminHandler.DeleteVenue)
	admin.Put("/venues/:id/approve", adminHandler.ApproveVenue)
	admin.Put("/venues/:id/reject", adminHandler.RejectVenue)

	// Corrections
	admin.Get("/corrections", correctionHandler.ListPending)
	admin.Put("/corrections/:id", correctionHandler.Review)

	// Guide başvuruları
	admin.Get("/applications", adminHandler.ListApplications)
	admin.Put("/applications/:id/approve", adminHandler.ApproveApplication)
	admin.Put("/applications/:id/reject", adminHandler.RejectApplication)

	// Venue reports
	admin.Get("/venue-reports", venueReportHandler.AdminList)
	admin.Put("/venue-reports/:id/resolve", venueReportHandler.AdminResolve)

	// Audit log + kullanıcılar
	admin.Get("/audit-logs", adminHandler.ListAuditLogs)
	admin.Get("/users", adminHandler.ListUsers)
	admin.Put("/users/:id", adminHandler.UpdateUser)
	admin.Delete("/users/:id", adminHandler.DeleteUser)

	log.Printf("sunucu başlatılıyor: :%s", cfg.Port)
	log.Fatal(app.Listen(":" + cfg.Port))
}
