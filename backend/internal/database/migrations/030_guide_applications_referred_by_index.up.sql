-- Admin kullanıcı listesi sorgusu guide_applications.referred_by üzerinden
-- JOIN + GROUP BY yapıyor; kullanıcı tablosu büyüdükçe index gerekli.
CREATE INDEX idx_guide_applications_referred_by ON guide_applications(referred_by);
