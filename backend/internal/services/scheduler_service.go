package services

import (
	"context"
	"log"
	"time"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

type SchedulerService struct {
	venueRepo    *repository.VenueRepo
	verifLogRepo *repository.VerificationLogRepo
	notifService *NotificationService
	runHour      int
	warningDays  int
}

func NewSchedulerService(
	venueRepo *repository.VenueRepo,
	verifLogRepo *repository.VerificationLogRepo,
	notifService *NotificationService,
	runHour, warningDays int,
) *SchedulerService {
	return &SchedulerService{
		venueRepo:    venueRepo,
		verifLogRepo: verifLogRepo,
		notifService: notifService,
		runHour:      runHour,
		warningDays:  warningDays,
	}
}

// Start — context iptal edilene kadar her gece runHour'da çalışır.
func (s *SchedulerService) Start(ctx context.Context) {
	log.Printf("scheduler başlatıldı, her gece %02d:00'da çalışacak", s.runHour)
	for {
		next := s.nextRunTime()
		select {
		case <-ctx.Done():
			log.Println("scheduler durduruldu")
			return
		case <-time.After(time.Until(next)):
			log.Println("doğrulama döngüsü başlıyor...")
			s.runVerificationCycle(ctx)
		}
	}
}

func (s *SchedulerService) nextRunTime() time.Time {
	return s.nextRunTimeFrom(time.Now())
}

func (s *SchedulerService) nextRunTimeFrom(now time.Time) time.Time {
	next := time.Date(now.Year(), now.Month(), now.Day(), s.runHour, 0, 0, 0, now.Location())
	if now.After(next) {
		next = next.Add(24 * time.Hour)
	}
	return next
}

func (s *SchedulerService) runVerificationCycle(ctx context.Context) {
	// Faz 1: Uyarı
	warnings, err := s.venueRepo.FindDueForWarning(ctx, s.warningDays)
	if err != nil {
		log.Printf("scheduler uyarı sorgusu hatası: %v", err)
	} else {
		for _, v := range warnings {
			if err := s.notifService.SendVerificationWarning(ctx, v); err != nil {
				log.Printf("uyarı gönderilemedi (venue %s): %v", v.ID, err)
				continue
			}
			_ = s.venueRepo.UpdateLastNotified(ctx, v.ID)
			_ = s.verifLogRepo.Create(ctx, v.ID, v.AddedBy, "warning_sent")
			log.Printf("uyarı gönderildi: venue=%s guide=%s", v.ID, v.AddedBy)
		}
	}

	// Faz 2: Askıya alma
	suspensions, err := s.venueRepo.FindDueForSuspension(ctx)
	if err != nil {
		log.Printf("scheduler askıya alma sorgusu hatası: %v", err)
	} else {
		for _, v := range suspensions {
			if err := s.venueRepo.SuspendForVerification(ctx, v.ID); err != nil {
				log.Printf("mekan askıya alınamadı (venue %s): %v", v.ID, err)
				continue
			}
			if err := s.notifService.SendSuspensionNotice(ctx, v); err != nil {
				log.Printf("askıya alma bildirimi gönderilemedi (venue %s): %v", v.ID, err)
			}
			_ = s.verifLogRepo.Create(ctx, v.ID, v.AddedBy, "suspended")
			log.Printf("mekan askıya alındı: venue=%s guide=%s", v.ID, v.AddedBy)
		}
	}
}
