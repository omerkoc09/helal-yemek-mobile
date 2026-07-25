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
	periodDays   int
}

func NewSchedulerService(
	venueRepo *repository.VenueRepo,
	verifLogRepo *repository.VerificationLogRepo,
	notifService *NotificationService,
	runHour, warningDays, periodDays int,
) *SchedulerService {
	return &SchedulerService{
		venueRepo:    venueRepo,
		verifLogRepo: verifLogRepo,
		notifService: notifService,
		runHour:      runHour,
		warningDays:  warningDays,
		periodDays:   periodDays,
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

// RunNow — test ve manuel tetikleme için döngüyü hemen çalıştırır.
func (s *SchedulerService) RunNow(ctx context.Context) {
	s.runVerificationCycle(ctx)
}

func (s *SchedulerService) runVerificationCycle(ctx context.Context) {
	// Faz 0: Rozet yeniden hesaplama — confirmation_count zamanla bayatlar
	// (ConfirmVenue anında yazılan sayı, doğrulamalar periodDays penceresi
	// dışına çıktıkça güncelliğini yitirir). Bu adım tüm onaylı mekanlar
	// için sayacı taze pencereye göre yeniden hesaplar.
	if affected, err := s.venueRepo.RecomputeConfirmationCounts(ctx, s.periodDays); err != nil {
		log.Printf("scheduler rozet yeniden hesaplama hatası: %v", err)
	} else {
		log.Printf("rozet sayaçları yeniden hesaplandı: %d mekan güncellendi", affected)
	}

	// Faz 1: Uyarı
	warnings, err := s.venueRepo.FindDueForWarning(ctx, s.warningDays, s.periodDays)
	if err != nil {
		log.Printf("scheduler uyarı sorgusu hatası: %v", err)
	} else {
		for _, v := range warnings {
			for _, rec := range v.Recipients {
				if err := s.notifService.SendVerificationWarning(ctx, v, rec); err != nil {
					log.Printf("uyarı gönderilemedi (venue %s, guide %s): %v", v.ID, rec.GuideID, err)
				}
			}
			// Spam önleme ve log yalnızca mekan başına bir kez.
			_ = s.venueRepo.UpdateLastNotified(ctx, v.ID)
			_ = s.verifLogRepo.Create(ctx, v.ID, v.AddedBy, "warning_sent")
			log.Printf("uyarı gönderildi: venue=%s alıcı=%d", v.ID, len(v.Recipients))
		}
	}

	// Faz 2: Askıya alma
	suspensions, err := s.venueRepo.FindDueForSuspension(ctx, s.periodDays)
	if err != nil {
		log.Printf("scheduler askıya alma sorgusu hatası: %v", err)
	} else {
		for _, v := range suspensions {
			if err := s.venueRepo.SuspendForVerification(ctx, v.ID); err != nil {
				log.Printf("mekan askıya alınamadı (venue %s): %v", v.ID, err)
				continue
			}
			for _, rec := range v.Recipients {
				if err := s.notifService.SendSuspensionNotice(ctx, v, rec); err != nil {
					log.Printf("askıya alma bildirimi gönderilemedi (venue %s, guide %s): %v", v.ID, rec.GuideID, err)
				}
			}
			_ = s.verifLogRepo.Create(ctx, v.ID, v.AddedBy, "suspended")
			log.Printf("mekan askıya alındı: venue=%s alıcı=%d", v.ID, len(v.Recipients))
		}
	}
}
