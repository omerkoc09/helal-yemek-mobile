package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

// generateResetCode — 6 haneli sıfırlama kodu üretir.
//
// crypto/rand kullanılır: math/rand tahmin edilebilir olduğu için tüm akışı
// çürütürdü. Baştaki sıfırlar korunsun diye %06d ile biçimlendirilir.
func generateResetCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func passwordResetEmailHTML(name, code string) string {
	return fmt.Sprintf(`<!DOCTYPE html><html><body>
<p>Merhaba %s,</p>
<p>Şifre sıfırlama kodunuz:</p>
<p style="font-size:28px;font-weight:bold;letter-spacing:4px;">%s</p>
<p>Bu kod <strong>15 dakika</strong> boyunca geçerlidir.</p>
<p>Bu isteği siz yapmadıysanız bu e-postayı yok sayabilirsiniz; şifreniz değişmez.</p>
<p>İtimat</p>
</body></html>`, name, code)
}
