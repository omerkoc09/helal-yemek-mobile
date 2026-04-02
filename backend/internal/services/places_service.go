package services

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"time"
)

type PlacesService struct {
	apiKey string
	client *http.Client
}

func NewPlacesService(apiKey string) *PlacesService {
	return &PlacesService{
		apiKey: apiKey,
		client: &http.Client{Timeout: 5 * time.Second},
	}
}

// findPlaceResponse — Google Find Place API yanıtı.
type findPlaceResponse struct {
	Candidates []struct {
		PlaceID  string `json:"place_id"`
		Name     string `json:"name"`
		Geometry struct {
			Location struct {
				Lat float64 `json:"lat"`
				Lng float64 `json:"lng"`
			} `json:"location"`
		} `json:"geometry"`
	} `json:"candidates"`
	Status string `json:"status"`
}

// ResolvePlaceID — mekan adı ve koordinat kullanarak Google Place ID bulur.
// API anahtarı yoksa veya bulunamazsa boş string döner (hata değil).
func (s *PlacesService) ResolvePlaceID(name string, lat, lng float64) string {
	if s.apiKey == "" {
		return ""
	}

	endpoint := "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
	params := url.Values{
		"input":     {name},
		"inputtype": {"textquery"},
		"locationbias": {
			fmt.Sprintf("circle:500@%f,%f", lat, lng),
		},
		"fields": {"place_id,name,geometry"},
		"key":    {s.apiKey},
	}

	resp, err := s.client.Get(endpoint + "?" + params.Encode())
	if err != nil {
		fmt.Printf("[PlacesService] HTTP hatası: %v\n", err)
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("[PlacesService] Beklenmeyen HTTP status: %d\n", resp.StatusCode)
		return ""
	}

	var result findPlaceResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		fmt.Printf("[PlacesService] JSON decode hatası: %v\n", err)
		return ""
	}

	fmt.Printf("[PlacesService] status=%s, candidates=%d\n", result.Status, len(result.Candidates))

	if result.Status == "OK" && len(result.Candidates) > 0 {
		// En yakın adayı bul (koordinat mesafesi kontrolü)
		bestCandidate := result.Candidates[0]
		bestDistance := s.calculateDistance(lat, lng, bestCandidate.Geometry.Location.Lat, bestCandidate.Geometry.Location.Lng)

		for _, candidate := range result.Candidates {
			distance := s.calculateDistance(lat, lng, candidate.Geometry.Location.Lat, candidate.Geometry.Location.Lng)
			if distance < bestDistance {
				bestCandidate = candidate
				bestDistance = distance
			}
		}

		// 500 metre içindeyse kabul et, değilse güvenlik için reddet
		if bestDistance <= 500 {
			fmt.Printf("[PlacesService] Seçilen: %s (mesafe: %.0fm)\n", bestCandidate.Name, bestDistance)
			return bestCandidate.PlaceID
		} else {
			fmt.Printf("[PlacesService] En yakın aday çok uzak: %s (mesafe: %.0fm)\n", bestCandidate.Name, bestDistance)
		}
	}

	return ""
}

// AddressComponents — Place Details API'den dönen adres ve isim bilgileri.
type AddressComponents struct {
	Name     string // mekan adı (display_name)
	City     string // locality
	District string // sublocality_level_1
}

// placeDetailsResponse — Google Place Details API yanıtı.
type placeDetailsResponse struct {
	Result struct {
		Name              string `json:"name"`
		AddressComponents []struct {
			LongName string   `json:"long_name"`
			Types    []string `json:"types"`
		} `json:"address_components"`
	} `json:"result"`
	Status string `json:"status"`
}

// GetAddressComponents — place_id üzerinden mekan adı, şehir ve semt bilgilerini çeker.
// Yalnızca "ChIJ" prefix'li geçerli place_id'lerle çalışır.
// Hata durumunda nil döner (sessiz fail).
func (s *PlacesService) GetAddressComponents(placeID string) (*AddressComponents, error) {
	if s.apiKey == "" || placeID == "" {
		return nil, nil
	}

	endpoint := "https://maps.googleapis.com/maps/api/place/details/json"
	params := url.Values{
		"place_id": {placeID},
		"fields":   {"name,address_components"},
		"key":      {s.apiKey},
	}

	resp, err := s.client.Get(endpoint + "?" + params.Encode())
	if err != nil {
		return nil, fmt.Errorf("place details HTTP hatası: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("place details beklenmeyen status: %d", resp.StatusCode)
	}

	var result placeDetailsResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("place details JSON decode hatası: %w", err)
	}

	if result.Status != "OK" {
		return nil, fmt.Errorf("place details status: %s", result.Status)
	}

	components := &AddressComponents{
		Name: result.Result.Name,
	}
	for _, c := range result.Result.AddressComponents {
		for _, t := range c.Types {
			switch t {
			case "administrative_area_level_1":
				// Türkiye: İl (İstanbul, Ankara, ...)
				components.City = c.LongName
			case "locality":
				// Bazı ülkelerde şehir locality olarak gelir; yalnızca henüz boşsa yaz
				if components.City == "" {
					components.City = c.LongName
				}
			case "administrative_area_level_2":
				// Türkiye: İlçe (Beyoğlu, Kadıköy, ...)
				components.District = c.LongName
			case "sublocality_level_1":
				// Bazı ülkelerde district sublocality olarak gelir
				if components.District == "" {
					components.District = c.LongName
				}
			}
		}
	}

	return components, nil
}

// geocodeResponse — Google Geocoding API yanıtı.
type geocodeResponse struct {
	Results []struct {
		Name              string `json:"formatted_address"`
		AddressComponents []struct {
			LongName string   `json:"long_name"`
			Types    []string `json:"types"`
		} `json:"address_components"`
	} `json:"results"`
	Status string `json:"status"`
}

// calculateDistance — iki koordinat arasındaki mesafeyi metre cinsinden hesaplar (Haversine formula)
func (s *PlacesService) calculateDistance(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371000 // Dünya yarıçapı (metre)

	lat1Rad := lat1 * math.Pi / 180
	lat2Rad := lat2 * math.Pi / 180
	deltaLatRad := (lat2 - lat1) * math.Pi / 180
	deltaLngRad := (lng2 - lng1) * math.Pi / 180

	a := math.Sin(deltaLatRad/2)*math.Sin(deltaLatRad/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*
			math.Sin(deltaLngRad/2)*math.Sin(deltaLngRad/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return R * c
}
