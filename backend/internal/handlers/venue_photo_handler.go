package handlers

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

const (
	// photoFetchTimeout — Google'dan fotoğrafı indirmek için üst sınır.
	// İstek Fiber'ın context'ine bağlanamaz (handler dönünce iptal olur),
	// bu yüzden kendi zaman aşımını taşır.
	photoFetchTimeout = 10 * time.Second

	// maxPhotoBytes — bellekte tutulacak azami görsel boyutu. Places
	// fotoğrafları birkaç yüz KB; sınır kötü niyetli/bozuk yanıtlara karşı.
	maxPhotoBytes = 10 << 20 // 10 MB

	// maxGooglePhotosPerVenue — mekan oluştururken Google'dan indirilecek azami
	// fotoğraf sayısı. Sınır bilinçli küçük: Places içeriğini depolama zaten
	// ToS gri alanı; yüzeyi dar tutuyoruz (bkz. 2026-08-01 tasarım kararı).
	maxGooglePhotosPerVenue = 3

	// maxVenuePhotos — bir mekandaki toplam fotoğraf sınırı (Google + yükleme).
	// Upload artık mevcutları silmiyor; sınırsız birikmeyi bu engeller.
	maxVenuePhotos = 5
)

// UploadPhoto godoc
// POST /api/v1/venues/:id/photos  (Guide + Admin)
func (h *VenueHandler) UploadPhoto(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	// Mekanın var olup olmadığını kontrol et
	if _, err := h.venueRepo.FindByID(c.Context(), venueID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekan doğrulanamadı"})
	}

	fileHeader, err := c.FormFile("photo")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "photo alanı gereklidir"})
	}

	// Ekleme politikası: yükleme mevcut fotoğrafları ARTIK silmiyor (eski "tek
	// fotoğraf" politikası çoklu Google fotoğrafıyla çelişiyordu — tek yükleme
	// galeriyi yok ederdi). Sınır kontrolü dosya depoya yazılmadan ÖNCE yapılır
	// ki reddedilen istek arkasında sahipsiz dosya bırakmasın.
	existing, err := h.venueRepo.GetPhotosByVenueID(c.Context(), venueID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "fotoğraflar okunamadı"})
	}
	if len(existing) >= maxVenuePhotos {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": fmt.Sprintf("bir mekanda en fazla %d fotoğraf olabilir; önce bir fotoğraf silin", maxVenuePhotos),
		})
	}

	file, err := fileHeader.Open()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "dosya açılamadı"})
	}
	defer file.Close()

	url, err := h.storageService.Upload(c.Context(), file, fileHeader.Filename)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	photo := &models.VenuePhoto{
		VenueID:    venueID,
		URL:        url,
		UploadedBy: userID,
		// Kapak yalnızca mekanın İLK fotoğrafı; sonrakiler galeriye eklenir.
		IsPrimary: len(existing) == 0,
	}
	if err := h.venueRepo.AddPhoto(c.Context(), photo); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "fotoğraf kaydedilemedi"})
	}

	return c.Status(fiber.StatusCreated).JSON(photo)
}

// DeletePhoto godoc
// DELETE /api/v1/venues/:id/photos/:photoId  (Guide/Admin)
func (h *VenueHandler) DeletePhoto(c *fiber.Ctx) error {
	venueID := c.Params("id")
	photoID := c.Params("photoId")

	photo, err := h.venueRepo.FindPhotoByID(c.Context(), photoID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "fotoğraf bulunamadı"})
	}

	if err := h.venueRepo.DeletePhoto(c.Context(), photoID, venueID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "fotoğraf silinemedi"})
	}

	// Kapak silindiyse mekan kapaksız kalmasın: kalanların en eskisi kapak olur.
	// Hata mekan/silme akışını bozmamalı, ama sessiz de geçilmemeli.
	if photo.IsPrimary {
		if err := h.venueRepo.PromoteAnyPhotoToPrimary(c.Context(), venueID); err != nil {
			log.Printf("[VENUE] kapak devri başarısız (venue=%s): %v", venueID, err)
		}
	}

	// Fiziksel dosyayı da sil
	_ = h.storageService.Delete(c.Context(), photo.URL)

	return c.SendStatus(fiber.StatusNoContent)
}

// BackfillGooglePhotos godoc
// POST /api/v1/venues/:id/photos/backfill  (Admin)
//
// Mekanın Google fotoğraflarını place_id üzerinden yeniden çeker.
//
// Neden gerekli: foto proxy'sine geçildiğinde mekan oluşturma akışı sessizce
// kırılmıştı (göreli proxy adresi SSRF guard'ına takılıyor, hata log'a yazılıp
// yutuluyordu). Bu dönemde eklenen mekanlar fotoğrafsız kaldı; kod düzeltmesi
// yalnızca YENİ mekanları kurtarır. Bu uç mevcutları telafi eder.
//
// Mekanda fotoğraf varsa dokunmaz (yanlışlıkla çoğaltmayı önler).
func (h *VenueHandler) BackfillGooglePhotos(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	if h.placesService == nil || h.storageService == nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"error": "places veya depolama servisi kullanılamıyor",
		})
	}

	venue, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
	}
	if venue.GooglePlaceID == nil || *venue.GooglePlaceID == "" {
		return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
			"error": "mekanın google place_id'si yok",
		})
	}

	existing, err := h.venueRepo.GetPhotosByVenueID(c.Context(), venueID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "fotoğraflar okunamadı"})
	}
	if len(existing) > 0 {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{
			"error": "mekanın zaten fotoğrafı var",
		})
	}

	components, err := h.placesService.GetAddressComponents(*venue.GooglePlaceID)
	if err != nil || components == nil || len(components.PhotoReferences) == 0 {
		return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
			"error": "google'da bu mekan için fotoğraf bulunamadı",
		})
	}

	refs := components.PhotoReferences
	if len(refs) > maxGooglePhotosPerVenue {
		refs = refs[:maxGooglePhotosPerVenue]
	}

	added := 0
	for _, ref := range refs {
		fetchCtx, cancel := context.WithTimeout(context.Background(), photoFetchTimeout)
		body, contentType, fetchErr := h.placesService.FetchPhoto(fetchCtx, ref, defaultPhotoWidth)
		if fetchErr != nil {
			cancel()
			log.Printf("[VENUE] backfill fotoğraf alınamadı (venue=%s): %v", venueID, fetchErr)
			continue
		}
		storedURL, storeErr := h.storageService.StoreStream(
			c.Context(), io.LimitReader(body, maxPhotoBytes), contentType,
		)
		body.Close()
		cancel()
		if storeErr != nil {
			log.Printf("[VENUE] backfill fotoğraf kaydedilemedi (venue=%s): %v", venueID, storeErr)
			continue
		}

		photo := &models.VenuePhoto{
			VenueID:    venueID,
			URL:        storedURL,
			UploadedBy: userID,
			IsPrimary:  added == 0,
		}
		if err := h.venueRepo.AddPhoto(c.Context(), photo); err == nil {
			added++
		}
	}

	if added == 0 {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "fotoğraf eklenemedi"})
	}

	photos, _ := h.venueRepo.GetPhotosByVenueID(c.Context(), venueID)
	return c.JSON(fiber.Map{"added": added, "photos": photos})
}

// SetPrimaryPhoto godoc
// PUT /api/v1/venues/:id/photos/:photoId/primary  (Admin)
//
// Mekanın kapak fotoğrafını değiştirir. Kapak, mekanın listelerde ve kartlarda
// görünen yüzü; ekleme sırasında "ilk seçilen" olarak belirleniyor ama sonradan
// düzeltilebilmesi gerekiyor.
func (h *VenueHandler) SetPrimaryPhoto(c *fiber.Ctx) error {
	venueID := c.Params("id")
	photoID := c.Params("photoId")

	if err := h.venueRepo.SetPrimaryPhoto(c.Context(), photoID, venueID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			// Fotoğraf yok ya da başka mekana ait — ikisi de istemci hatası.
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "fotoğraf bulunamadı"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "kapak fotoğrafı güncellenemedi"})
	}

	photos, err := h.venueRepo.GetPhotosByVenueID(c.Context(), venueID)
	if err != nil {
		return c.SendStatus(fiber.StatusNoContent)
	}
	return c.JSON(photos)
}

// PlacePhotoProxy godoc
// GET /api/v1/places/photo?ref=<photo_reference>&w=800  (Guide/Admin)
//
// Google Places fotoğrafını sunucu üzerinden geçirir.
//
// Neden proxy: önceden fotoğraf adresleri doğrudan Google'a işaret ediyor ve
// API anahtarı sorgu parametresinde İSTEMCİYE gidiyordu. Anahtar hem sunucudan
// hem de her kullanıcının cihazından kullanıldığı için Cloud Console'da hiçbir
// uygulama kısıtlaması alamıyordu (IP kısıtı mobili, paket kısıtı sunucuyu
// kırardı). Artık anahtar yalnızca sunucuda kalıyor ve kısıtlanabiliyor.
//
// Yetki: rota seviyesinde guide/admin. Anahtar sızmasa bile uç herkese açık
// olsaydı, kotayı isteyen tüketebilirdi.
func (h *VenueHandler) PlacePhotoProxy(c *fiber.Ctx) error {
	if h.placesService == nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"error": "places servisi kullanılamıyor",
		})
	}

	ref := c.Query("ref")
	if ref == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ref zorunludur"})
	}

	width := c.QueryInt("w", defaultPhotoWidth)
	if width < minPhotoWidth {
		width = minPhotoWidth
	}
	if width > maxPhotoWidth {
		width = maxPhotoWidth
	}

	// Fiber'ın request context'i handler dönünce geri dönüştürülür; arka plandaki
	// Google isteği bu context'e bağlı olduğu için stream'i handler'dan SONRA
	// yazdırmak (SendStream) bağlantıyı ortada kestiriyordu. Üstelik
	// `defer body.Close()` gövdeyi daha okunmadan kapatıyordu. İstemci bu yüzden
	// HTTP status'ü olmayan, yarıda kesilmiş bir yanıt alıyordu.
	// Çözüm: görseli handler içinde tamamen oku, tam gövde olarak gönder.
	// Fotoğraflar birkaç yüz KB olduğundan bellekte tutmak güvenli.
	ctx, cancel := context.WithTimeout(context.Background(), photoFetchTimeout)
	defer cancel()

	body, contentType, err := h.placesService.FetchPhoto(ctx, ref, width)
	if err != nil {
		log.Printf("[VENUE] places fotoğrafı alınamadı: %v", err)
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "fotoğraf alınamadı"})
	}
	defer body.Close()

	data, err := io.ReadAll(io.LimitReader(body, maxPhotoBytes))
	if err != nil {
		log.Printf("[VENUE] places fotoğrafı okunamadı: %v", err)
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "fotoğraf alınamadı"})
	}

	if contentType == "" {
		contentType = "image/jpeg"
	}
	c.Set(fiber.HeaderContentType, contentType)
	// photo_reference sabit bir görsele işaret eder; uzun cache hem Places
	// kotasını hem gecikmeyi düşürür. private: paylaşımlı cache'lerde
	// tutulmasın (uç yetkiye bağlı).
	c.Set(fiber.HeaderCacheControl, "private, max-age=86400")

	return c.Send(data)
}
