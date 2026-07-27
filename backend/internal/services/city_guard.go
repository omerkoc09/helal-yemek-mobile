package services

import "github.com/omerkoc/itimat-mobile/internal/models"

// CheckCityAllowed — rehberin şehri (guideCity) ile mekanın şehrini (venueCity)
// karşılaştırır. resolved, mekanın 81 il içinde çözülen kanonik ilidir (allowed=false
// iken hata mesajında kullanılır).
//
// Belirsizlikte izin verilir (admin onayına kalır):
//   - guideCity nil/boş → allowed=true
//   - venueCity 81 ilden birine çözülemez → allowed=true
// Kesin farklı ilde reddedilir.
func CheckCityAllowed(guideCity *string, venueCity string) (allowed bool, resolved string) {
	if guideCity == nil || *guideCity == "" {
		return true, ""
	}
	venueCanonical, ok := models.NormalizeCity(venueCity)
	if !ok {
		return true, ""
	}
	guideCanonical, ok := models.NormalizeCity(*guideCity)
	if !ok {
		// guide_city beklenmedik biçimde çözülemiyorsa engelleme yapma, izin ver (savunmacı).
		return true, ""
	}
	if venueCanonical == guideCanonical {
		return true, venueCanonical
	}
	return false, venueCanonical
}
