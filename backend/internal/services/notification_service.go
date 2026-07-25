package services

import (
	"context"
	"fmt"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type NotificationService struct {
	notifRepo *repository.NotificationRepo
	email     EmailService
}

func NewNotificationService(notifRepo *repository.NotificationRepo, email EmailService) *NotificationService {
	return &NotificationService{notifRepo: notifRepo, email: email}
}

// SendVerificationWarning — VERIFICATION_WARNING_DAYS kadar kala uyarı: DB kaydı + email.
func (s *NotificationService) SendVerificationWarning(ctx context.Context, v *models.VenueForScheduler) error {
	n := &models.Notification{
		UserID: v.AddedBy,
		Type:   models.NotificationTypeVerificationWarning,
		Title:  fmt.Sprintf("“%s” için doğrulama zamanı yaklaşıyor", v.Name),
		Body:   fmt.Sprintf("“%s” mekanının doğrulama süresi yakında dolacak. Lütfen uygulamadan onaylayın.", v.Name),
		Data:   map[string]string{"venue_id": v.ID, "venue_name": v.Name},
	}
	if err := s.notifRepo.Create(ctx, n); err != nil {
		return fmt.Errorf("uyarı bildirimi kaydedilemedi: %w", err)
	}

	htmlBody := warningEmailHTML(v.GuideName, v.Name)
	_ = s.email.Send(v.GuideEmail, n.Title, htmlBody) // email hatası scheduler'ı durdurmaz
	return nil
}

// SendSuspensionNotice — mekan askıya alındı: DB kaydı + email.
func (s *NotificationService) SendSuspensionNotice(ctx context.Context, v *models.VenueForScheduler) error {
	n := &models.Notification{
		UserID: v.AddedBy,
		Type:   models.NotificationTypeVenueSuspended,
		Title:  fmt.Sprintf("“%s” askıya alındı", v.Name),
		Body:   fmt.Sprintf("“%s” mekanı doğrulama yapılmadığı için askıya alındı. Uygulamadan doğrulayarak yeniden aktif edebilirsiniz.", v.Name),
		Data:   map[string]string{"venue_id": v.ID, "venue_name": v.Name},
	}
	if err := s.notifRepo.Create(ctx, n); err != nil {
		return fmt.Errorf("askıya alma bildirimi kaydedilemedi: %w", err)
	}

	htmlBody := suspensionEmailHTML(v.GuideName, v.Name)
	_ = s.email.Send(v.GuideEmail, n.Title, htmlBody)
	return nil
}

func warningEmailHTML(guideName, venueName string) string {
	return fmt.Sprintf(`<!DOCTYPE html><html><body>
<p>Merhaba %s,</p>
<p>Eklediğiniz <strong>"%s"</strong> mekanının doğrulama süresi <strong>14 gün içinde</strong> dolacak.</p>
<p>Mekanın hâlâ helal kriterlerini karşıladığını uygulamadan teyit etmenizi rica ederiz.</p>
<p>Doğrulamayı yapmazsanız mekan 14 gün sonra askıya alınacaktır.</p>
<p>Uygulamayı açın → Mekan Detayı → Doğrula</p>
<br><p>— Caiz mi? ekibi</p>
</body></html>`, guideName, venueName)
}

func suspensionEmailHTML(guideName, venueName string) string {
	return fmt.Sprintf(`<!DOCTYPE html><html><body>
<p>Merhaba %s,</p>
<p><strong>"%s"</strong> mekanı doğrulama yapılmadığı için <strong>askıya alınmıştır</strong>.</p>
<p>Mekan artık diğer kullanıcılara gösterilmemektedir.</p>
<p>Uygulamayı açıp doğrulamayı tamamlarsanız mekan otomatik olarak yeniden aktif olur.</p>
<br><p>— Caiz mi? ekibi</p>
</body></html>`, guideName, venueName)
}
