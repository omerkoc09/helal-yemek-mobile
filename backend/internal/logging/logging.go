// Package logging — uygulama genelinde yapılandırılmış (structured) loglama kurar.
package logging

import (
	"log/slog"
	"os"
	"strings"
)

// Setup — varsayılan slog logger'ını yapılandırır.
//
// Önemli yan etki: slog.SetDefault, standart kütüphanedeki `log` paketinin
// çıktısını da bu handler'a yönlendirir. Bu sayede koddaki mevcut
// log.Printf/log.Println çağrıları tek satır bile değiştirilmeden
// yapılandırılmış çıktıya dönüşür; kademeli geçişe imkân verir.
//
// format: "json" (prod — log toplama araçları için) veya "text" (geliştirme).
// level:  debug | info | warn | error
func Setup(format, level string) *slog.Logger {
	opts := &slog.HandlerOptions{Level: parseLevel(level)}

	var handler slog.Handler
	if strings.EqualFold(format, "text") {
		handler = slog.NewTextHandler(os.Stdout, opts)
	} else {
		handler = slog.NewJSONHandler(os.Stdout, opts)
	}

	logger := slog.New(handler)
	slog.SetDefault(logger)
	return logger
}

// parseLevel — tanınmayan değerlerde info'ya düşer; yanlış yazılmış bir env
// değişkeni yüzünden loglar tamamen susmasın.
func parseLevel(level string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
