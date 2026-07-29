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
			from: "İtimat <noreply@caizmi.com>",
			want: "noreply@caizmi.com",
		},
		{
			name: "çıplak adres",
			from: "noreply@caizmi.com",
			want: "noreply@caizmi.com",
		},
		{
			name: "açılı parantez içinde boşluk",
			from: "İtimat < noreply@caizmi.com >",
			want: "noreply@caizmi.com",
		},
		{
			name: "görünen adda soru işareti ve boşluk",
			from: "Caiz mi? <noreply@caizmi.com>",
			want: "noreply@caizmi.com",
		},
		{
			name: "baştaki ve sondaki boşluklar kırpılır",
			from: "  noreply@caizmi.com  ",
			want: "noreply@caizmi.com",
		},
		{
			name: "kapanış parantezi yoksa olduğu gibi döner",
			from: "bozuk <noreply@caizmi.com",
			want: "bozuk <noreply@caizmi.com",
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
