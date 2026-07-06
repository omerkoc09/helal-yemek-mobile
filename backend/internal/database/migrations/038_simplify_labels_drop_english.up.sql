-- İngilizce etiketler hiçbir yerde tüketilmiyor (backend her zaman gönderiyordu,
-- mobile hiç okumuyordu); tek dilli (TR) içerik olarak sadeleştiriliyor.
-- İleride çok dillilik gerekirse ayrı bir i18n şeması ile yeniden ele alınacak.

ALTER TABLE food_categories RENAME COLUMN label_tr TO name;
ALTER TABLE food_categories DROP COLUMN label_en;

ALTER TABLE food_items RENAME COLUMN label_tr TO name;
ALTER TABLE food_items DROP COLUMN label_en;

ALTER TABLE halal_criteria RENAME COLUMN label_tr TO name;
ALTER TABLE halal_criteria DROP COLUMN label_en;
ALTER TABLE halal_criteria RENAME COLUMN description_tr TO description;
ALTER TABLE halal_criteria DROP COLUMN description_en;
