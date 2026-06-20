package models

import "strings"

// TurkishCities — 81 ilin kanonik adları (alfabetik, doğru imla).
var TurkishCities = []string{
	"Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Aksaray", "Amasya",
	"Ankara", "Antalya", "Ardahan", "Artvin", "Aydın", "Balıkesir", "Bartın",
	"Batman", "Bayburt", "Bilecik", "Bingöl", "Bitlis", "Bolu", "Burdur",
	"Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli", "Diyarbakır", "Düzce",
	"Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir", "Gaziantep",
	"Giresun", "Gümüşhane", "Hakkâri", "Hatay", "Iğdır", "Isparta", "İstanbul",
	"İzmir", "Kahramanmaraş", "Karabük", "Karaman", "Kars", "Kastamonu",
	"Kayseri", "Kırıkkale", "Kırklareli", "Kırşehir", "Kilis", "Kocaeli",
	"Konya", "Kütahya", "Malatya", "Manisa", "Mardin", "Mersin", "Muğla",
	"Muş", "Nevşehir", "Niğde", "Ordu", "Osmaniye", "Rize", "Sakarya",
	"Samsun", "Siirt", "Sinop", "Sivas", "Şanlıurfa", "Şırnak", "Tekirdağ",
	"Tokat", "Trabzon", "Tunceli", "Uşak", "Van", "Yalova", "Yozgat",
	"Zonguldak",
}

// citySet — kanonik ad → struct{}; IsValidCity için hızlı arama.
var citySet = func() map[string]struct{} {
	m := make(map[string]struct{}, len(TurkishCities))
	for _, c := range TurkishCities {
		m[c] = struct{}{}
	}
	return m
}()

// normalizedIndex — normalize edilmiş ad → kanonik ad.
var normalizedIndex = func() map[string]string {
	m := make(map[string]string, len(TurkishCities))
	for _, c := range TurkishCities {
		m[normalizeForMatch(c)] = c
	}
	return m
}()

// normalizeForMatch — Türkçe karakterleri sadeleştirip küçük harfe çevirir, trim eder.
func normalizeForMatch(s string) string {
	s = strings.TrimSpace(s)
	var b strings.Builder
	for _, r := range s {
		switch r {
		case 'İ', 'I', 'ı', 'i':
			b.WriteRune('i')
		case 'Ş', 'ş':
			b.WriteRune('s')
		case 'Ğ', 'ğ':
			b.WriteRune('g')
		case 'Ü', 'ü':
			b.WriteRune('u')
		case 'Ö', 'ö':
			b.WriteRune('o')
		case 'Ç', 'ç':
			b.WriteRune('c')
		case 'Â', 'â':
			b.WriteRune('a')
		default:
			b.WriteString(strings.ToLower(string(r)))
		}
	}
	return b.String()
}

// IsValidCity — ad tam (kanonik) eşleşiyor mu.
func IsValidCity(name string) bool {
	_, ok := citySet[name]
	return ok
}

// NormalizeCity — case/boşluk/Türkçe-karakter duyarsız eşleştirir; kanonik adı döner.
func NormalizeCity(name string) (string, bool) {
	canonical, ok := normalizedIndex[normalizeForMatch(name)]
	return canonical, ok
}
