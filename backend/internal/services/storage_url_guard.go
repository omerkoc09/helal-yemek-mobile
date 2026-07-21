package services

import (
	"errors"
	"fmt"
	"net/url"
	"strings"
)

var (
	ErrPhotoURLScheme = errors.New("fotoğraf URL'si https olmalı")
	ErrPhotoURLHost   = errors.New("fotoğraf URL'si izin verilmeyen bir adrese işaret ediyor")
)

// allowedPhotoHosts — tam eşleşme gereken host'lar.
// maps.googleapis.com, places_service.BuildPhotoURL'ün ürettiği adrestir.
var allowedPhotoHosts = map[string]struct{}{
	"maps.googleapis.com": {},
}

// allowedPhotoHostSuffixes — bu alan adının kendisi veya alt alanları kabul edilir.
// Places Photo API isteği lh3/lh4/lh5... googleusercontent.com'a yönlendirir,
// bu yüzden sabit bir host listesi yetmez.
var allowedPhotoHostSuffixes = []string{
	"googleusercontent.com",
}

// validateRemotePhotoURL — DownloadAndStore'un ulaşmasına izin verilen adresleri sınırlar.
//
// Bu fonksiyon olmadan kullanıcıdan gelen google_photo_url doğrudan fetch edilir;
// saldırgan http://169.254.169.254/... (cloud metadata) veya iç ağ adresi vererek
// sunucuyu kendi adına istek yaptırabilir (SSRF) ve credential sızdırabilir.
func validateRemotePhotoURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("%w: çözümlenemedi", ErrPhotoURLScheme)
	}
	if u.Scheme != "https" {
		return fmt.Errorf("%w: %q", ErrPhotoURLScheme, u.Scheme)
	}
	// Userinfo ("https://maps.googleapis.com@evil.com") gerçek host'u gizleyebilir;
	// meşru bir fotoğraf adresinde hiç bulunmaz, doğrudan reddediyoruz.
	if u.User != nil {
		return fmt.Errorf("%w: userinfo içeriyor", ErrPhotoURLHost)
	}

	host := strings.ToLower(u.Hostname())
	if _, ok := allowedPhotoHosts[host]; ok {
		return nil
	}
	for _, suffix := range allowedPhotoHostSuffixes {
		// Nokta ile karşılaştırma şart: "notgoogleusercontent.com" ve
		// "googleusercontent.com.evil.com" bu kontrolden geçmemeli.
		if host == suffix || strings.HasSuffix(host, "."+suffix) {
			return nil
		}
	}
	return fmt.Errorf("%w: %q", ErrPhotoURLHost, host)
}
