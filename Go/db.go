// Package business calls jazd/Business PostgreSQL procedures.
//
// A method is SELECT of a procedure with the same name. The package does not
// insert, update, or delete.
package business

import (
	"context"
	"database/sql"
	"errors"
	"os"

	_ "github.com/jackc/pgx/v5/stdlib"
)

// DB is a Business database. The caller owns the *sql.DB lifetime.
type DB struct {
	SQL *sql.DB
}

// ErrNotConfigured means PGHOST, PGUSER, or PGDATABASE is unset.
var ErrNotConfigured = errors.New("postgres is not configured")

// OpenFromEnv opens PostgreSQL with the PG* environment variables.
func OpenFromEnv() (*DB, error) {
	if os.Getenv("PGHOST") == "" || os.Getenv("PGUSER") == "" || os.Getenv("PGDATABASE") == "" {
		return nil, ErrNotConfigured
	}
	sqldb, err := sql.Open("pgx", "")
	if err != nil {
		return nil, err
	}
	return &DB{SQL: sqldb}, nil
}

func (d *DB) queryInt(ctx context.Context, q string, args ...any) (int, error) {
	var id sql.NullInt64
	if err := d.SQL.QueryRowContext(ctx, q, args...).Scan(&id); err != nil {
		return 0, err
	}
	if !id.Valid {
		return 0, sql.ErrNoRows
	}
	return int(id.Int64), nil
}

func (d *DB) queryInt64(ctx context.Context, q string, args ...any) (int64, error) {
	var id sql.NullInt64
	if err := d.SQL.QueryRowContext(ctx, q, args...).Scan(&id); err != nil {
		return 0, err
	}
	if !id.Valid {
		return 0, sql.ErrNoRows
	}
	return id.Int64, nil
}

func (d *DB) queryString(ctx context.Context, q string, args ...any) (string, error) {
	var s sql.NullString
	if err := d.SQL.QueryRowContext(ctx, q, args...).Scan(&s); err != nil {
		return "", err
	}
	if !s.Valid {
		return "", sql.ErrNoRows
	}
	return s.String, nil
}

func nullInt(p *int) any {
	if p == nil {
		return nil
	}
	return *p
}

func nullInt64(p *int64) any {
	if p == nil {
		return nil
	}
	return *p
}

func nullStr(s string) any {
	if s == "" {
		return nil
	}
	return s
}
