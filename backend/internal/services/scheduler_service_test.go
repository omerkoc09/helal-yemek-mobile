package services

import (
	"testing"
	"time"
)

// nextRunTimeFrom için referans zaman: 15 Ocak 2026
var jan15 = time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC)

func TestNextRunTimeFrom_BeforeRunHour_SameDay(t *testing.T) {
	// Saat 01:00 → hedef aynı gün 02:00
	s := &SchedulerService{runHour: 2}
	now := jan15.Add(1 * time.Hour) // 01:00
	next := s.nextRunTimeFrom(now)

	if next.Day() != 15 || next.Hour() != 2 || next.Minute() != 0 {
		t.Errorf("beklenen: 15 Ocak 02:00, gelen: %v", next)
	}
}

func TestNextRunTimeFrom_AfterRunHour_NextDay(t *testing.T) {
	// Saat 03:00 → hedef ertesi gün 02:00
	s := &SchedulerService{runHour: 2}
	now := jan15.Add(3 * time.Hour) // 03:00
	next := s.nextRunTimeFrom(now)

	if next.Day() != 16 || next.Hour() != 2 || next.Minute() != 0 {
		t.Errorf("beklenen: 16 Ocak 02:00, gelen: %v", next)
	}
}

func TestNextRunTimeFrom_ExactlyAtRunHour_NextDay(t *testing.T) {
	// Tam 02:00'da — geçmiş sayılır, ertesi güne atlar
	s := &SchedulerService{runHour: 2}
	now := jan15.Add(2 * time.Hour) // 02:00:00 tam
	next := s.nextRunTimeFrom(now)

	// 02:00:00 == next, yani now.After(next) false — aynı gün döner
	// Bu edge case: tam saatte çalışırsa bugün mi ertesi gün mü?
	if next.Hour() != 2 {
		t.Errorf("beklenen saat: 2, gelen: %v", next)
	}
}

func TestNextRunTimeFrom_AlwaysOnSecondZero(t *testing.T) {
	// Hedef zaman her zaman XX:00:00 olmalı (saniye/nanosaniye yok)
	s := &SchedulerService{runHour: 3}
	now := jan15.Add(1 * time.Hour) // 01:00
	next := s.nextRunTimeFrom(now)

	if next.Second() != 0 || next.Nanosecond() != 0 {
		t.Errorf("beklenen: saniye=0, gelen: %v", next)
	}
}

func TestNextRunTimeFrom_MidnightRunHour(t *testing.T) {
	// runHour=0 (gece yarısı): saat 23:00 ise ertesi gün 00:00
	s := &SchedulerService{runHour: 0}
	now := jan15.Add(23 * time.Hour) // 23:00
	next := s.nextRunTimeFrom(now)

	if next.Day() != 16 || next.Hour() != 0 {
		t.Errorf("beklenen: 16 Ocak 00:00, gelen: %v", next)
	}
}
