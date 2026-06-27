package models

import "testing"

func TestBadgeFromCount(t *testing.T) {
	cases := []struct {
		count int
		level string
	}{
		{0, "base"},
		{1, "bronze"},
		{2, "silver"},
		{5, "silver"},
		{6, "gold"},
		{10, "gold"},
		{11, "platinum"},
		{50, "platinum"},
	}
	for _, c := range cases {
		got := BadgeFromCount(c.count)
		if got.Level != c.level {
			t.Errorf("BadgeFromCount(%d).Level = %q, want %q", c.count, got.Level, c.level)
		}
		if got.Count != c.count {
			t.Errorf("BadgeFromCount(%d).Count = %d, want %d", c.count, got.Count, c.count)
		}
	}
}
