package business

import (
	"context"
	"database/sql"
	"time"
)

// EntitlementPeriod is one row of EntitlementCurrent or EntitlementHistory.
type EntitlementPeriod struct {
	ID         int
	Individual int64
	ListName   string
	ListSet    string
	Source     string
	Status     string
	StopReason string
	Starts     time.Time
	Ends       *time.Time
	Batch      string
	Stopped    *time.Time
}

// EntitlementGrant returns the current period id for this individual, list, set, and source.
// An empty list set or batch is NULL.
func (d *DB) EntitlementGrant(ctx context.Context, individual int64, list, set, source, status string, starts time.Time, ends *time.Time, batch string) (int, error) {
	return d.queryInt(ctx, `SELECT EntitlementGrant($1, $2, $3, $4, $5, $6, $7, $8)`,
		individual, list, nullStr(set), source, status, starts, nullTime(ends), nullStr(batch))
}

// EntitlementSet stops the current period with reason replaced and inserts the next version.
func (d *DB) EntitlementSet(ctx context.Context, individual int64, list, set, source, status string, starts time.Time, ends *time.Time, batch string) (int, error) {
	return d.queryInt(ctx, `SELECT EntitlementSet($1, $2, $3, $4, $5, $6, $7, $8)`,
		individual, list, nullStr(set), source, status, starts, nullTime(ends), nullStr(batch))
}

// EntitlementStop sets stopped and stopReason on the current period.
func (d *DB) EntitlementStop(ctx context.Context, individual int64, list, set, source, reason string) (int, error) {
	return d.queryInt(ctx, `SELECT EntitlementStop($1, $2, $3, $4, $5)`,
		individual, list, nullStr(set), source, nullStr(reason))
}

// EntitlementReference stores one outside id on a version.
// The same name on that version returns the existing row.
func (d *DB) EntitlementReference(ctx context.Context, entitlement int, name, value string) (int, error) {
	return d.queryInt(ctx, `SELECT EntitlementReference($1, $2, $3)`, entitlement, name, value)
}

// EntitlementCurrent reads EntitlementCurrent for one individual.
func (d *DB) EntitlementCurrent(ctx context.Context, individual int64) ([]EntitlementPeriod, error) {
	return d.entitlementRows(ctx, `
		SELECT id, individual, listNameValue, listSetValue, sourceValue, statusValue,
		       stopReasonValue, starts, ends, batchValue, stopped
		FROM EntitlementCurrent
		WHERE individual = $1
		ORDER BY id`, individual)
}

// EntitlementHistory reads EntitlementHistory for one individual.
func (d *DB) EntitlementHistory(ctx context.Context, individual int64) ([]EntitlementPeriod, error) {
	return d.entitlementRows(ctx, `
		SELECT id, individual, listNameValue, listSetValue, sourceValue, statusValue,
		       stopReasonValue, starts, ends, batchValue, stopped
		FROM EntitlementHistory
		WHERE individual = $1
		ORDER BY id`, individual)
}

func nullTime(t *time.Time) any {
	if t == nil {
		return nil
	}
	return *t
}

func (d *DB) entitlementRows(ctx context.Context, q string, individual int64) ([]EntitlementPeriod, error) {
	rows, err := d.SQL.QueryContext(ctx, q, individual)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []EntitlementPeriod
	for rows.Next() {
		var row EntitlementPeriod
		var listName, listSet, source, status, stopReason, batch sql.NullString
		var ends, stopped sql.NullTime
		err := rows.Scan(
			&row.ID, &row.Individual, &listName, &listSet, &source, &status,
			&stopReason, &row.Starts, &ends, &batch, &stopped,
		)
		if err != nil {
			return nil, err
		}
		row.ListName = listName.String
		row.ListSet = listSet.String
		row.Source = source.String
		row.Status = status.String
		row.StopReason = stopReason.String
		row.Batch = batch.String
		if ends.Valid {
			t := ends.Time
			row.Ends = &t
		}
		if stopped.Valid {
			t := stopped.Time
			row.Stopped = &t
		}
		out = append(out, row)
	}
	return out, rows.Err()
}
