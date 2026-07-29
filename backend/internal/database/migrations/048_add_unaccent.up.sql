-- Arama sorgularında Türkçe karakter duyarsız eşleşme için (ör. "kofte" → "Köfte").
-- venue_search_repo.SearchByText tarafından kullanılır.
CREATE EXTENSION IF NOT EXISTS unaccent;
