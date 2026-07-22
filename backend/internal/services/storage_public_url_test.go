package services

import "testing"

func TestPublicURL(t *testing.T) {
	svc := &StorageService{baseURL: "http://localhost:8080/static"}

	tests := []struct {
		name string
		key  string
		want string
	}{
		{
			name: "anahtar tam URL'e çevrilir",
			key:  "abc123_1783.jpg",
			want: "http://localhost:8080/static/abc123_1783.jpg",
		},
		{
			name: "baştaki eğik çizgi çiftlenmez",
			key:  "/abc123.jpg",
			want: "http://localhost:8080/static/abc123.jpg",
		},
		// Migration öncesinden kalan kayıtlar tam URL içeriyor; bunlar
		// olduğu gibi dönmeli ki migration uygulanmamış bir ortamda
		// fotoğraflar kırılmasın.
		{
			name: "eski http URL olduğu gibi döner",
			key:  "http://192.168.1.5:3000/static/eski.jpg",
			want: "http://192.168.1.5:3000/static/eski.jpg",
		},
		{
			name: "eski https URL olduğu gibi döner",
			key:  "https://cdn.example.com/eski.jpg",
			want: "https://cdn.example.com/eski.jpg",
		},
		// Boş anahtar boş dönmeli — "görsel yok" durumu ayırt edilebilsin;
		// aksi halde istemci "http://localhost:8080/static/" gibi kırık bir
		// adrese istek atardı.
		{
			name: "boş anahtar boş döner",
			key:  "",
			want: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := svc.PublicURL(tt.key); got != tt.want {
				t.Fatalf("PublicURL(%q) = %q, beklenen %q", tt.key, got, tt.want)
			}
		})
	}
}

func TestPublicURLTrailingSlashInBase(t *testing.T) {
	// baseURL sonunda eğik çizgi olsa da çift eğik çizgi üretilmemeli.
	svc := &StorageService{baseURL: "http://localhost:8080/static/"}
	if got := svc.PublicURL("a.jpg"); got != "http://localhost:8080/static/a.jpg" {
		t.Fatalf("alınan %q", got)
	}
}
