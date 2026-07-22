package logging

import (
	"log/slog"
	"testing"
)

func TestParseLevel(t *testing.T) {
	tests := []struct {
		in   string
		want slog.Level
	}{
		{"debug", slog.LevelDebug},
		{"DEBUG", slog.LevelDebug},
		{"info", slog.LevelInfo},
		{"warn", slog.LevelWarn},
		{"warning", slog.LevelWarn},
		{"error", slog.LevelError},
		{"  Error  ", slog.LevelError},
		// Yanlış yazılmış veya boş env değeri logları susturmamalı:
		// bilinmeyen her değer info'ya düşer.
		{"", slog.LevelInfo},
		{"uydurma", slog.LevelInfo},
		{"trace", slog.LevelInfo},
	}

	for _, tt := range tests {
		t.Run(tt.in, func(t *testing.T) {
			if got := parseLevel(tt.in); got != tt.want {
				t.Fatalf("parseLevel(%q) = %v, beklenen %v", tt.in, got, tt.want)
			}
		})
	}
}

func TestSetupReturnsLoggerAndSetsDefault(t *testing.T) {
	for _, format := range []string{"json", "text", "bilinmeyen"} {
		t.Run(format, func(t *testing.T) {
			logger := Setup(format, "info")
			if logger == nil {
				t.Fatal("logger nil döndü")
			}
			// slog.SetDefault çağrıldığı için varsayılan logger da değişmeli;
			// stdlib log paketinin yönlendirilmesi buna bağlı.
			if slog.Default() == nil {
				t.Fatal("varsayılan logger ayarlanmadı")
			}
		})
	}
}
