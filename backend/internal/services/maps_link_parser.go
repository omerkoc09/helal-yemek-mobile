package services

import (
	"errors"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// MapCoordinates — bir Google Maps linkinden çıkarılan konum bilgisi.
type MapCoordinates struct {
	Latitude  float64
	Longitude float64
	PlaceID   string // boş olabilir (yalnızca ChIJ formatı)
	PlaceName string // URL'den çıkarılan mekan adı, boş olabilir
}

// ErrInvalidMapsLink — link parse edilemediğinde döner.
var ErrInvalidMapsLink = errors.New("geçersiz veya çözümlenemeyen Google Maps linki")

// mapsLinkClient — kısa link redirect'lerini takip etmek için kullanılır.
// Redirect'leri otomatik takip etmez; Location header'ını elle okuyup
// tam Google Maps URL'ine ulaşana kadar (max 5) ilerler.
var mapsLinkClient = &http.Client{
	Timeout: 10 * time.Second,
	CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
		return http.ErrUseLastResponse
	},
}

var (
	// !8m2!3d{lat}!4d{lng} — mekanın tam pin koordinatı (en güvenilir).
	reData = regexp.MustCompile(`!8m2!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)`)
	// !3d{lat}!4d{lng} — pin koordinatı (kısa/embed URL).
	reEmbed = regexp.MustCompile(`!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)`)
	// /@lat,lng,zoom — kamera merkezi (pin değil, son çare).
	reAt = regexp.MustCompile(`/@(-?\d+\.?\d*),(-?\d+\.?\d*)`)
	// ?q=lat,lng | ?ll=lat,lng | ?query=lat,lng
	reQuery = regexp.MustCompile(`[?&](?:q|ll|query)=(-?\d+\.?\d*),(-?\d+\.?\d*)`)
	// /maps/place/lat,lng
	rePlaceCoord = regexp.MustCompile(`/maps/place/(-?\d+\.?\d*),(-?\d+\.?\d*)`)
	// place_id: !1sChIJ... — yalnızca ChIJ (gerçek Google place_id) formatı.
	// !1s0x...:0x... (hex feature ID) Google API'lerinde geçerli place_id DEĞİLDİR;
	// ?q=place_id: ile kullanılınca Google onu tanımayıp arama metnine düşürür.
	rePlaceID = regexp.MustCompile(`!1s(ChIJ[^!&]+)`)
	// /maps/place/<isim>/ — mekan adı (koordinat değilse).
	rePlaceName = regexp.MustCompile(`/maps/place/([^/@?]+)`)
	// Sadece rakam/virgül/nokta/eksi içeren değerler isim değil koordinattır.
	reNumericOnly = regexp.MustCompile(`^[\d.,\-]+$`)
)

// ParseMapsLink — bir Google Maps linkinden koordinat ve (varsa) place_id çıkarır.
// Kısa linkleri (maps.app.goo.gl vb.) redirect takibiyle tam URL'e çevirir.
func ParseMapsLink(link string) (*MapCoordinates, error) {
	trimmed := strings.TrimSpace(link)
	if trimmed == "" {
		return nil, ErrInvalidMapsLink
	}

	resolved, err := resolveMapsURL(trimmed)
	if err != nil || resolved == "" {
		return nil, ErrInvalidMapsLink
	}

	lat, lng, ok := extractCoordinates(resolved)
	if !ok {
		return nil, ErrInvalidMapsLink
	}

	coords := &MapCoordinates{Latitude: lat, Longitude: lng}
	if pid := extractPlaceID(resolved); pid != "" {
		coords.PlaceID = pid
	}
	coords.PlaceName = extractPlaceName(resolved)
	return coords, nil
}

// extractPlaceName — URL'den mekan adını çıkarır (örn. /maps/place/Sultan+Ahmet/@ →
// "Sultan Ahmet"). Koordinat gibi görünen değerleri reddeder.
func extractPlaceName(u string) string {
	m := rePlaceName.FindStringSubmatch(u)
	if m == nil {
		return ""
	}
	raw := strings.ReplaceAll(m[1], "+", " ")
	decoded, err := url.QueryUnescape(raw)
	if err != nil {
		decoded = raw
	}
	decoded = strings.TrimSpace(decoded)
	if decoded == "" || reNumericOnly.MatchString(decoded) {
		return ""
	}
	return decoded
}

// resolveMapsURL — kısa linkleri tam Google Maps URL'ine çevirir.
// Zaten tam URL ise olduğu gibi döndürür.
func resolveMapsURL(raw string) (string, error) {
	if isFullGoogleMapsURL(raw) {
		return raw, nil
	}
	if isShortMapsLink(raw) {
		return followRedirects(raw, 5)
	}
	// Bilinmeyen ama maps benzeri — yine de parse etmeyi dene.
	if strings.Contains(raw, "google") || strings.Contains(raw, "goo.gl") || strings.Contains(raw, "maps") {
		return raw, nil
	}
	return "", ErrInvalidMapsLink
}

// followRedirects — Location header'larını takip ederek tam URL'e ulaşır.
func followRedirects(raw string, maxRedirects int) (string, error) {
	current := raw
	if !strings.HasPrefix(current, "http") {
		current = "https://" + current
	}

	for i := 0; i < maxRedirects; i++ {
		if isFullGoogleMapsURL(current) {
			return current, nil
		}

		req, err := http.NewRequest(http.MethodGet, current, nil)
		if err != nil {
			return current, nil
		}
		// Bot benzeri istekleri engelleyen sunucular için tarayıcı UA'sı.
		req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; ItimatBot/1.0)")

		resp, err := mapsLinkClient.Do(req)
		if err != nil {
			return current, nil
		}
		resp.Body.Close()

		if resp.StatusCode < 300 || resp.StatusCode >= 400 {
			return current, nil
		}
		loc := resp.Header.Get("Location")
		if loc == "" {
			return current, nil
		}
		// Göreli redirect'i mutlak URL'e çevir.
		if next, err := resp.Request.URL.Parse(loc); err == nil {
			current = next.String()
		} else {
			current = loc
		}
	}
	return current, nil
}

func isFullGoogleMapsURL(u string) bool {
	return strings.Contains(u, "google.com/maps") ||
		strings.Contains(u, "google.com.tr/maps") ||
		strings.Contains(u, "maps.google.com")
}

func isShortMapsLink(u string) bool {
	return strings.Contains(u, "goo.gl/maps") ||
		strings.Contains(u, "maps.app.goo.gl") ||
		strings.Contains(u, "g.co/maps")
}

// extractCoordinates — URL'den koordinat çıkarır. Öncelik sırası önemli:
// !3d/!4d pin koordinatını verir, /@ ise kamera merkezini.
func extractCoordinates(u string) (lat, lng float64, ok bool) {
	for _, re := range []*regexp.Regexp{reData, reEmbed, reAt, reQuery, rePlaceCoord} {
		if m := re.FindStringSubmatch(u); m != nil {
			if lat, lng, ok = tryParseCoords(m[1], m[2]); ok {
				return lat, lng, true
			}
		}
	}
	return 0, 0, false
}

func extractPlaceID(u string) string {
	if m := rePlaceID.FindStringSubmatch(u); m != nil {
		if decoded, err := url.QueryUnescape(m[1]); err == nil {
			return decoded
		}
		return m[1]
	}
	return ""
}

func tryParseCoords(latStr, lngStr string) (lat, lng float64, ok bool) {
	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		return 0, 0, false
	}
	lng, err = strconv.ParseFloat(lngStr, 64)
	if err != nil {
		return 0, 0, false
	}
	if lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return 0, 0, false
	}
	return lat, lng, true
}
