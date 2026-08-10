package services

import "testing"

// envelopeFrom, SMTP zarfındaki (MAIL FROM) adresi SMTP_FROM'dan türetir.
// Giriş kullanıcı adının zarf adresi olarak kullanılması Resend gibi
// sağlayıcılarda kırılıyordu: orada SMTP_USER sabit "resend" kelimesidir,
// geçerli bir e-posta adresi değildir ve sunucu zarfı reddeder.
func TestEnvelopeFrom(t *testing.T) {
	cases := []struct {
		name string
		from string
		want string
	}{
		{
			name: "görünen adlı biçim",
			from: "İtimat <noreply@itimat.app>",
			want: "noreply@itimat.app",
		},
		{
			name: "çıplak adres",
			from: "noreply@itimat.app",
			want: "noreply@itimat.app",
		},
		{
			name: "açılı parantez içinde boşluk",
			from: "İtimat < noreply@itimat.app >",
			want: "noreply@itimat.app",
		},
		{
			name: "görünen adda soru işareti ve boşluk",
			from: "İtimat <noreply@itimat.app>",
			want: "noreply@itimat.app",
		},
		{
			name: "baştaki ve sondaki boşluklar kırpılır",
			from: "  noreply@itimat.app  ",
			want: "noreply@itimat.app",
		},
		{
			name: "kapanış parantezi yoksa olduğu gibi döner",
			from: "bozuk <noreply@itimat.app",
			want: "bozuk <noreply@itimat.app",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := envelopeFrom(tc.from); got != tc.want {
				t.Fatalf("envelopeFrom(%q) = %q, beklenen %q", tc.from, got, tc.want)
			}
		})
	}
}
