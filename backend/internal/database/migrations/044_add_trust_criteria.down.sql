-- Önce bu kriterlere yapılmış mekan işaretlemelerini temizle (FK ihlalini önle),
-- sonra kriterleri sil.
DELETE FROM venue_criteria WHERE criteria_id IN (4, 5, 6, 7);
DELETE FROM trust_criteria  WHERE id IN (4, 5, 6, 7);
