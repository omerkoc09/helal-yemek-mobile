ALTER TABLE guide_applications ADD COLUMN referred_by UUID REFERENCES users(id);
