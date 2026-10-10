package business

import "context"

// SetSessionPath binds a Path to an anonymous session.
func (d *DB) SetSessionPath(ctx context.Context, session int64, typ string, path int64) (int64, error) {
	return d.queryInt64(ctx, `SELECT SetSessionPath($1, $2, $3)`, session, nullStr(typ), path)
}

// StopSessionPath ends the current SessionPath fact.
func (d *DB) StopSessionPath(ctx context.Context, session int64, typ string, path int64) (int64, error) {
	return d.queryInt64(ctx, `SELECT StopSessionPath($1, $2, $3)`, session, nullStr(typ), path)
}

// SetIndividualPath binds a Path to a person after claim.
func (d *DB) SetIndividualPath(ctx context.Context, individual int64, typ string, path int64) (int64, error) {
	return d.queryInt64(ctx, `SELECT SetIndividualPath($1, $2, $3)`, individual, nullStr(typ), path)
}

// StopIndividualPath ends the current IndividualPath fact.
func (d *DB) StopIndividualPath(ctx context.Context, individual int64, typ string, path int64) (int64, error) {
	return d.queryInt64(ctx, `SELECT StopIndividualPath($1, $2, $3)`, individual, nullStr(typ), path)
}

// PutPassword inserts a Password.value row and returns its id.
func (d *DB) PutPassword(ctx context.Context, value string) (int, error) {
	return d.queryInt(ctx, `SELECT PutPassword($1)`, value)
}

// SetPathPassword associates an unrevoked Password with a Path.
func (d *DB) SetPathPassword(ctx context.Context, path int64, password int) (int64, error) {
	return d.queryInt64(ctx, `SELECT SetPathPassword($1, $2)`, path, password)
}

// RevokePathPassword ends the current PathPassword fact.
func (d *DB) RevokePathPassword(ctx context.Context, path int64, password int) (int64, error) {
	return d.queryInt64(ctx, `SELECT RevokePathPassword($1, $2)`, path, password)
}
