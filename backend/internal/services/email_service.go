package services

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/smtp"
	"strings"
)

type EmailService interface {
	Send(to, subject, htmlBody string) error
}

type SMTPEmailService struct {
	host     string
	port     string
	user     string
	password string
	from     string
}

func NewSMTPEmailService(host, port, user, password, from string) *SMTPEmailService {
	return &SMTPEmailService{host: host, port: port, user: user, password: password, from: from}
}

func (s *SMTPEmailService) Send(to, subject, htmlBody string) error {
	auth := smtp.PlainAuth("", s.user, s.password, s.host)

	headers := strings.Join([]string{
		"From: " + s.from,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/html; charset=UTF-8",
	}, "\r\n")
	msg := headers + "\r\n\r\n" + htmlBody

	addr := net.JoinHostPort(s.host, s.port)

	tlsConfig := &tls.Config{ServerName: s.host}
	conn, err := tls.Dial("tcp", addr, tlsConfig)
	if err != nil {
		// TLS başarısız olursa STARTTLS dene
		return smtp.SendMail(addr, auth, s.user, []string{to}, []byte(msg))
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, s.host)
	if err != nil {
		return fmt.Errorf("smtp client oluşturulamadı: %w", err)
	}
	defer client.Close()

	if err = client.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth başarısız: %w", err)
	}
	if err = client.Mail(s.user); err != nil {
		return err
	}
	if err = client.Rcpt(to); err != nil {
		return err
	}
	w, err := client.Data()
	if err != nil {
		return err
	}
	_, err = fmt.Fprint(w, msg)
	if err != nil {
		return err
	}
	return w.Close()
}

// NoopEmailService — test ve geliştirme ortamı için email göndermeden loglar.
type NoopEmailService struct{}

func NewNoopEmailService() *NoopEmailService { return &NoopEmailService{} }

func (s *NoopEmailService) Send(to, subject, htmlBody string) error {
	// Gövdedeki 6 haneli kod da loglanır: SMTP tanımlı değilken şifre sıfırlama
	// akışının uygulamadan uçtan uca denenebilmesi için tek yol bu (kod DB'de
	// bcrypt hash'li saklandığı için oradan okunamaz).
	if code, ok := extractSixDigitCode(htmlBody); ok {
		fmt.Printf("[EMAIL NOOP] To: %s | Subject: %s | Kod: %s\n", to, subject, code)
		return nil
	}
	fmt.Printf("[EMAIL NOOP] To: %s | Subject: %s\n", to, subject)
	return nil
}

// extractSixDigitCode — gövdedeki ilk 6 haneli rakam dizisini döner.
// Şifre sıfırlama şablonunda başka 6 haneli sayı yok; başka mail türlerinde
// (ör. doğrulama uyarıları) bulunmazsa sessizce false döner ve log eski
// biçimine düşer. Yalnızca Noop (geliştirme) yolunda kullanılır.
func extractSixDigitCode(body string) (string, bool) {
	run := 0
	for i := 0; i < len(body); i++ {
		if body[i] >= '0' && body[i] <= '9' {
			run++
			if run == 6 {
				// Devamında da rakam varsa bu 6 haneli bir kod değildir.
				if i+1 < len(body) && body[i+1] >= '0' && body[i+1] <= '9' {
					run = 0
					continue
				}
				return body[i-5 : i+1], true
			}
			continue
		}
		run = 0
	}
	return "", false
}
