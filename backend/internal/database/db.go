package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Havuz varsayılanları. pgxpool.New tamamen ayarsız kullanıldığında MaxConns
// makinenin CPU sayısına göre belirleniyor ve bağlantı ömrü/timeout tanımsız
// kalıyor; yük altında bağlantı tükenmesi ve zincirleme timeout riski doğuyor.
const (
	defaultMaxConns          = 25
	defaultMinConns          = 2
	defaultMaxConnLifetime   = time.Hour
	defaultMaxConnIdleTime   = 30 * time.Minute
	defaultHealthCheckPeriod = time.Minute
	defaultConnectTimeout    = 5 * time.Second
)

func NewPool(databaseURL string) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("DATABASE_URL çözümlenemedi: %w", err)
	}

	// ParseConfig, DATABASE_URL'de pool_max_conns gibi parametreler varsa onları
	// zaten doldurur; yalnızca boş kalanlara varsayılan atanır ki URL'deki
	// açık ayar ezilmesin.
	if poolCfg.MaxConns == 0 {
		poolCfg.MaxConns = defaultMaxConns
	}
	if poolCfg.MinConns == 0 {
		poolCfg.MinConns = defaultMinConns
	}
	if poolCfg.MaxConnLifetime == 0 {
		poolCfg.MaxConnLifetime = defaultMaxConnLifetime
	}
	if poolCfg.MaxConnIdleTime == 0 {
		poolCfg.MaxConnIdleTime = defaultMaxConnIdleTime
	}
	if poolCfg.HealthCheckPeriod == 0 {
		poolCfg.HealthCheckPeriod = defaultHealthCheckPeriod
	}
	if poolCfg.ConnConfig.ConnectTimeout == 0 {
		poolCfg.ConnConfig.ConnectTimeout = defaultConnectTimeout
	}

	pool, err := pgxpool.NewWithConfig(context.Background(), poolCfg)
	if err != nil {
		return nil, err
	}

	// İlk bağlantı da süresiz beklememeli.
	ctx, cancel := context.WithTimeout(context.Background(), defaultConnectTimeout)
	defer cancel()
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}
