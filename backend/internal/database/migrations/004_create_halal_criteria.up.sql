CREATE TABLE halal_criteria (
    id       SMALLINT PRIMARY KEY,
    key      VARCHAR(50) UNIQUE NOT NULL,
    label_tr VARCHAR(100) NOT NULL,
    label_en VARCHAR(100) NOT NULL
);

INSERT INTO halal_criteria VALUES
(1, 'personal_experience', 'Kişisel Tecrübe',  'Personal Experience'),
(2, 'halal_certified',     'Helal Sertifikası', 'Halal Certified');

CREATE TABLE venue_criteria (
    venue_id    UUID REFERENCES venues(id) ON DELETE CASCADE,
    criteria_id SMALLINT REFERENCES halal_criteria(id),
    PRIMARY KEY (venue_id, criteria_id)
);
