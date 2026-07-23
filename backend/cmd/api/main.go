package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	fiberlogger "github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"

	"github.com/omerkoc/caiz-mi/internal/config"
	"github.com/omerkoc/caiz-mi/internal/database"
	"github.com/omerkoc/caiz-mi/internal/handlers"
	"github.com/omerkoc/caiz-mi/internal/logging"
	"github.com/omerkoc/caiz-mi/internal/middleware"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

// shutdownTimeout — kapanış sinyalinden sonra açık isteklere tanınan süre.
// Bu süre dolarsa kalan bağlantılar zorla kapatılır.
const shutdownTimeout = 15 * time.Second

// readinessTimeout — /ready ucundaki DB ping'inin en fazla bekleyeceği süre.
// Orkestratörün probe timeout'undan kısa olmalı ki cevap zamanında dönsün.
const readinessTimeout = 2 * time.Second

func main() {
	cfg := config.Load()

	// Loglamayı en başta kur: bundan sonraki tüm log çıktıları (stdlib log
	// paketi dahil) yapılandırılmış formata döner.
	logging.Setup(cfg.LogFormat, cfg.LogLevel)

	// Zorunlu ayarlar — eksikse hiç açılma. Özellikle JWT_SECRET: boşken HS256
	// boş anahtarla imzalar, uygulama sorunsuz çalışıyor görünür ama tüm
	// kimlik doğrulama sahtelenebilir hâle gelir.
	if err := cfg.Validate(); err != nil {
		log.Fatalf("yapılandırma hatası: %v", err)
	}

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
	venueReportRepo := repository.NewVenueReportRepo(pool)
	notifRepo     := repository.NewNotificationRepo(pool)
	verifLogRepo  := repository.NewVerificationLogRepo(pool)
	loginRepo     := repository.NewLoginRepo(pool)
	directionRepo := repository.NewDirectionClickRepo(pool)

	// Service katmanı
	authService := services.NewAuthService(userRepo, loginRepo, cfg.JWTSecret, cfg.GoogleClientID)
	// Depolama arka ucu: S3_ENDPOINT tanımlıysa S3, değilse yerel disk.
	// S3 yapılandırması hatalıysa BURADA fail-fast yapılır — aksi halde sorun
	// ilk fotoğraf yüklenene kadar gizli kalır ve kullanıcı hatasıyla karışır.
	var storageService *services.StorageService
	if cfg.S3Enabled() {
		s3Store, err := services.NewS3BlobStore(context.Background(), services.S3Config{
			Endpoint:   cfg.S3Endpoint,
			AccessKey:  cfg.S3AccessKey,
			SecretKey:  cfg.S3SecretKey,
			Bucket:     cfg.StorageBucket,
			Region:     cfg.S3Region,
			UseSSL:     cfg.S3UseSSL,
			PublicBase: cfg.S3PublicBase,
		})
		if err != nil {
			log.Fatalf("S3 depolama kurulamadı: %v", err)
		}
		storageService = services.NewStorageServiceWithBackend(s3Store)
		log.Printf("depolama: S3 (bucket=%s)", cfg.StorageBucket)
	} else {
		storageService = services.NewStorageService("./uploads", cfg.StorageURL+"/static")
		log.Println("depolama: yerel disk (./uploads) — prod'da volume veya S3 gerekir")
	}

	// Fotoğraf ve kategori görselleri DB'de anahtar olarak saklanır; tam URL
	// okuma anında burada bağlanan çözücüyle üretilir. Bağlanmazsa istemciye
	// çıplak dosya adı gider — bu yüzden storageService oluşur oluşmaz bağlanıyor.
	venueRepo.WithURLResolver(storageService)
	placesService := services.NewPlacesService(cfg.GoogleMapsAPIKey)

	var emailSvc services.EmailService
	if cfg.SMTPUser != "" && cfg.SMTPPassword != "" {
		emailSvc = services.NewSMTPEmailService(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPassword, cfg.SMTPFrom)
	} else {
		emailSvc = services.NewNoopEmailService()
	}
	notifService := services.NewNotificationService(notifRepo, emailSvc)
	schedulerSvc := services.NewSchedulerService(venueRepo, verifLogRepo, notifService, cfg.SchedulerRunHour, cfg.VerificationWarningDays)

	// Handler katmanı
	authHandler := handlers.NewAuthHandler(authService)
	venueHandler := handlers.NewVenueHandler(venueRepo, userRepo, storageService, placesService, verifLogRepo, directionRepo, notifService, cfg.VerificationPeriodDays)
	reviewHandler := handlers.NewReviewHandler(reviewRepo)
	favoriteHandler := handlers.NewFavoriteHandler(favoriteRepo)
	correctionHandler := handlers.NewCorrectionHandler(correctionRepo, auditRepo)
	guideHandler := handlers.NewGuideHandler(guideRepo, venueRepo)
	adminHandler := handlers.NewAdminHandler(venueRepo, guideRepo, userRepo, auditRepo, verifLogRepo, reviewRepo, loginRepo, directionRepo, schedulerSvc, storageService, cfg.VerificationPeriodDays)
	venueReportHandler := handlers.NewVenueReportHandler(venueReportRepo)
	notifHandler := handlers.NewNotificationHandler(notifRepo)

	// Fiber uygulaması
	app := fiber.New(fiber.Config{
		AppName:   "Caiz mi? API v1",
		BodyLimit: 10 * 1024 * 1024, // 10 MB (fotoğraf yükleme için)
	})

	app.Use(recover.New())

	// HTTP erişim logları — uygulama loglarıyla aynı formatta (JSON) olsun ki
	// log toplama araçları tek şemayla işleyebilsin. Varsayılan fiberlogger
	// kendi metin formatını kullanır ve yapılandırılmış çıktıyı bozardı.
	// LOG_FORMAT=text seçildiğinde geliştirici için okunaklı biçime düşer.
	accessLogFormat := `{"time":"${time}","level":"INFO","msg":"http_request","method":"${method}","path":"${path}","status":${status},"latency":"${latency}","ip":"${ip}"}` + "\n"
	if strings.EqualFold(cfg.LogFormat, "text") {
		accessLogFormat = "${time} ${status} ${latency} ${method} ${path}\n"
	}
	app.Use(fiberlogger.New(fiberlogger.Config{
		Format:     accessLogFormat,
		TimeFormat: time.RFC3339,
		// Varsayılan ${latency} sabit genişlikte hizalanır ("   207µs");
		// JSON'da bu boşluk dolgusu gereksiz ve ayrıştırmayı zorlaştırır.
		CustomTags: map[string]fiberlogger.LogFunc{
			"latency": func(output fiberlogger.Buffer, c *fiber.Ctx, _ *fiberlogger.Data, _ string) (int, error) {
				return output.WriteString(time.Since(c.Context().Time()).String())
			},
		},
	}))

	// CORS — web admin paneli için (mobil native istemciyi etkilemez)
	app.Use(cors.New(cors.Config{
		AllowOrigins:     cfg.CORSAllowOrigins,
		AllowMethods:     "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders:     "Origin,Content-Type,Accept,Authorization",
		AllowCredentials: false,
	}))

	// Sağlık kontrolü
	// Liveness — süreç ayakta mı? Bilerek DB'ye DOKUNMAZ.
	// DB kontrolü buraya konsaydı, geçici bir veritabanı kesintisinde
	// orkestratör sağlıklı uygulama container'larını yeniden başlatır ve
	// durumu daha da kötüleştirirdi.
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "ok",
			"service": "caiz-mi-api",
		})
	})

	// Readiness — trafik alabilir mi? DB erişimini gerçekten sınar.
	// Başarısızsa 503 döner; orkestratör container'ı yeniden başlatmak yerine
	// yük dengeleyiciden çıkarır.
	app.Get("/ready", func(c *fiber.Ctx) error {
		// Takılı bir DB'de probe'un asılı kalmaması için kısa timeout.
		ctx, cancel := context.WithTimeout(c.Context(), readinessTimeout)
		defer cancel()

		if err := pool.Ping(ctx); err != nil {
			log.Printf("readiness başarısız: %v", err)
			return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
				"status":   "unavailable",
				"service":  "caiz-mi-api",
				"database": "unreachable",
			})
		}
		return c.JSON(fiber.Map{
			"status":   "ready",
			"service":  "caiz-mi-api",
			"database": "ok",
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

	// Auth endpoint'leri (korumalı)
	auth.Post("/refresh", authHandler.Refresh)
	auth.Get("/me", middleware.Auth(cfg.JWTSecret), authHandler.Me)
	auth.Put("/profile", middleware.Auth(cfg.JWTSecret), authHandler.UpdateProfile)

	// Venue endpoint'leri (public)
	api.Get("/venues", venueHandler.List)
	api.Get("/venues/nearby", venueHandler.ListNearby)
	api.Get("/venues/popular", venueHandler.ListPopular)
	api.Get("/venues/cities", venueHandler.ListCities)
	api.Get("/venues/by-category/:categoryId", venueHandler.ListByCategory)
	api.Get("/venues/place-preview",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.PlacePreview,
	)
	api.Post("/venues/preview-location",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.PreviewLocationFromLink,
	)
	// Google Places fotoğraf proxy'si — API anahtarı istemciye gitmesin diye.
	// place-preview ile aynı yetki seviyesinde: fotoğraflar yalnızca mekan
	// ekleme akışında kullanılıyor ve uç açık olsaydı kota tüketilebilirdi.
	api.Get("/places/photo",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.PlacePhotoProxy,
	)
	api.Get("/venues/check-duplicate",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.CheckDuplicate,
	)
	api.Get("/venues/:id",
		middleware.OptionalAuth(cfg.JWTSecret),
		venueHandler.Detail,
	)
	api.Post("/venues/:id/direction-click",
		middleware.OptionalAuth(cfg.JWTSecret),
		venueHandler.TrackDirectionClick,
	)
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
	api.Put("/venues/:id/verify",
		middleware.Auth(cfg.JWTSecret),
		middleware.RequireRole("guide", "admin"),
		venueHandler.Verify,
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

	// Notification endpoint'leri
	notif := api.Group("/notifications", middleware.Auth(cfg.JWTSecret))
	notif.Get("/", notifHandler.List)
	notif.Get("/unread-count", notifHandler.UnreadCount)
	notif.Put("/read-all", notifHandler.MarkAllRead)
	notif.Put("/:id/read", notifHandler.MarkRead)

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
	guide.Get("/my-application", guideHandler.MyApplication)
	guide.Get("/my-venues",
		middleware.RequireRole("guide", "admin"),
		guideHandler.MyVenues,
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
	admin.Get("/verification-logs", adminHandler.VerificationLogs)
	admin.Get("/venues/:id/verification-logs", adminHandler.GetVenueVerificationLogs)
	admin.Get("/venues/:id/confirming-guides", adminHandler.GetVenueConfirmingGuides)
	admin.Post("/scheduler/run", adminHandler.RunSchedulerNow)
	admin.Put("/venues/:id/reactivate", adminHandler.ReactivateVenue)

	// Corrections
	admin.Get("/corrections", correctionHandler.ListPending)
	admin.Put("/corrections/:id", correctionHandler.Review)

	// Guide başvuruları
	admin.Get("/applications", adminHandler.ListApplications)
	admin.Put("/applications/:id/approve", adminHandler.ApproveApplication)
	admin.Put("/applications/:id/reject", adminHandler.RejectApplication)
	admin.Get("/guides/by-city", adminHandler.GuidesByCity)
	admin.Get("/venues/by-city", adminHandler.VenuesByCity)

	// Venue reports
	admin.Get("/venue-reports", venueReportHandler.AdminList)
	admin.Put("/venue-reports/:id/resolve", venueReportHandler.AdminResolve)

	// Audit log + kullanıcılar
	admin.Get("/audit-logs", adminHandler.ListAuditLogs)
	admin.Get("/users", adminHandler.ListUsers)
	admin.Post("/users", adminHandler.CreateUser)
	admin.Put("/users/:id", adminHandler.UpdateUser)
	admin.Delete("/users/:id", adminHandler.DeleteUser)
	admin.Get("/users/:id", adminHandler.GetUser)
	admin.Put("/users/:id/password", adminHandler.UpdateUserPassword)
	admin.Get("/users/:id/venues", adminHandler.GetUserVenues)
	admin.Get("/users/:id/reviews", adminHandler.GetUserReviews)

	// Stats
	admin.Get("/stats/activity", adminHandler.GetActivityStats)

	// Yemek kategorileri
	admin.Get("/food-categories", adminHandler.ListFoodCategories)
	admin.Post("/food-categories", adminHandler.CreateFoodCategory)
	admin.Post("/food-categories/:id/image", adminHandler.UploadFoodCategoryImage)
	admin.Put("/food-categories/:id", adminHandler.UpdateFoodCategory)
	admin.Delete("/food-categories/:id", adminHandler.DeleteFoodCategory)
	admin.Post("/food-categories/:id/items", adminHandler.CreateFoodItem)
	admin.Put("/food-items/:id", adminHandler.UpdateFoodItem)
	admin.Delete("/food-items/:id", adminHandler.DeleteFoodItem)

	// Verification scheduler'ı başlat. Context, kapanış sinyalinde iptal edilir.
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	go schedulerSvc.Start(ctx)

	// Listen ayrı goroutine'de: ana akış kapanış sinyalini beklemeli.
	// Aksi halde (log.Fatal(app.Listen(...))) deploy/restart anında uçuşan
	// istekler ortadan kesilir ve yarım DB transaction'ları kalır.
	serverErr := make(chan error, 1)
	go func() {
		log.Printf("sunucu başlatılıyor: :%s", cfg.Port)
		if err := app.Listen(":" + cfg.Port); err != nil {
			serverErr <- err
		}
	}()

	select {
	case err := <-serverErr:
		log.Fatalf("sunucu başlatılamadı: %v", err)
	case <-ctx.Done():
		log.Println("kapanış sinyali alındı, açık istekler tamamlanıyor...")
		if err := app.ShutdownWithTimeout(shutdownTimeout); err != nil {
			log.Printf("düzgün kapanış başarısız: %v", err)
		} else {
			log.Println("sunucu düzgün şekilde kapandı")
		}
	}
}
