package business

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"
)

// SetSessionInput is the cookie-token form of SetSession.
type SetSessionInput struct {
	Token                  string
	SiteApplicationRelease int
	AgentString            *int
	Credential             *int
	Referring              *int64
	IP                     string
	Location               *int
	// Type is the SessionToken type name: session, mail, or trial.
	// Empty is NULL. SetSession stores it with GetIdentifier.
	Type string
}

// SetSession creates or touches a Session for token and site application release.
func (d *DB) SetSession(ctx context.Context, in SetSessionInput) (int64, error) {
	var ip any
	if in.IP != "" {
		ip = in.IP
	}
	return d.queryInt64(ctx, `
		SELECT SetSession($1::varchar, $2::integer, $3::integer, $4::integer, $5::integer, $6::inet, $7::integer, $8::timestamp, $9::varchar)`,
		in.Token,
		in.SiteApplicationRelease,
		nullInt(in.AgentString),
		nullInt(in.Credential),
		nullInt64(in.Referring),
		ip,
		nullInt(in.Location),
		nil,
		nullStr(in.Type),
	)
}

// ClaimSession attaches email to a session.
func (d *DB) ClaimSession(ctx context.Context, session int64, email string) (int64, error) {
	return d.queryInt64(ctx, `SELECT ClaimSession($1::bigint, $2::varchar)`, session, email)
}

// ClaimSessionToken claims the token on one site application release.
func (d *DB) ClaimSessionToken(ctx context.Context, token, email string, sar int) (int64, error) {
	info, err := d.SessionByToken(ctx, token, sar)
	if err != nil {
		return 0, err
	}
	if info.Session == 0 {
		return 0, sql.ErrNoRows
	}
	return d.ClaimSession(ctx, info.Session, email)
}

// SessionInfo is one Sessions row for a token.
type SessionInfo struct {
	Session    int64
	Token      string
	SAR        int
	Timeout    *int
	Created    time.Time
	Credential *int
	Individual *int64
	Email      string
}

// SessionByToken reads Sessions for a cookie or mailed token on one SAR.
func (d *DB) SessionByToken(ctx context.Context, token string, sar int) (SessionInfo, error) {
	var info SessionInfo
	var sarOut sql.NullInt64
	var timeout sql.NullInt64
	var cred sql.NullInt64
	var individual sql.NullInt64
	var email sql.NullString
	err := d.SQL.QueryRowContext(ctx, `
		SELECT session, token, siteapplicationrelease, timeout, created,
		       credential, individual, email
		FROM Sessions
		WHERE token = $1
		  AND (siteapplicationrelease = $2
		       OR (siteapplicationrelease IS NULL AND $2 IS NULL))
		LIMIT 1`, token, sar).Scan(
		&info.Session, &info.Token, &sarOut, &timeout, &info.Created,
		&cred, &individual, &email,
	)
	if err != nil {
		return SessionInfo{}, err
	}
	if sarOut.Valid {
		info.SAR = int(sarOut.Int64)
	}
	if timeout.Valid {
		v := int(timeout.Int64)
		info.Timeout = &v
	}
	if cred.Valid {
		v := int(cred.Int64)
		info.Credential = &v
	}
	if individual.Valid {
		v := individual.Int64
		info.Individual = &v
	}
	if email.Valid {
		info.Email = email.String
	}
	return info, nil
}

// BoostExpired reports whether timeout seconds from Created have elapsed.
func (info SessionInfo) BoostExpired(now time.Time) bool {
	if info.Timeout == nil || *info.Timeout <= 0 {
		return true
	}
	return !info.Created.Add(time.Duration(*info.Timeout) * time.Second).After(now)
}

// SetSessionTimeout fills SessionToken.timeout when it is still NULL.
func (d *DB) SetSessionTimeout(ctx context.Context, token string, sar, seconds int) error {
	n, err := d.queryInt(ctx, `SELECT SetSessionTimeout($1, $2, $3)`, token, sar, seconds)
	if err != nil {
		return err
	}
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// UnexpiredBoostCount counts IndividualSessions rows for this email and SAR
// that are still inside timeout.
func (d *DB) UnexpiredBoostCount(ctx context.Context, sar int, email string, now time.Time) (int, error) {
	var n int
	err := d.SQL.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM IndividualSessions
		WHERE siteApplicationRelease = $1
		  AND lower(email) = lower($2)
		  AND timeout IS NOT NULL AND timeout > 0
		  AND created + (timeout * interval '1 second') > $3`,
		sar, email, now).Scan(&n)
	return n, err
}

// GetCredential returns the unrevoked Credential id for individual and email.
func (d *DB) GetCredential(ctx context.Context, individual int64, emailID int) (int, error) {
	return d.queryInt(ctx, `SELECT GetCredential($1, $2)`, individual, emailID)
}

// ListSubscribeEmail appends the address onto a named list set.
func (d *DB) ListSubscribeEmail(ctx context.Context, list, set, email string) error {
	_, err := d.SQL.ExecContext(ctx, `SELECT ListSubscribeEmail($1, $2, $3)`, list, set, email)
	return err
}

// ListHasEmail reports whether the address is currently on the list set.
func (d *DB) ListHasEmail(ctx context.Context, list, set, email string) (bool, error) {
	var n int
	err := d.SQL.QueryRowContext(ctx, `
		SELECT 1
		FROM SiteMembership
		WHERE listNameValue = $1
		  AND COALESCE(listSetValue, '') = $2
		  AND lower(email) = $3
		  AND unlist IS NULL
		LIMIT 1`, list, set, strings.ToLower(strings.TrimSpace(email))).Scan(&n)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// ListHasIndividual reports whether the person is currently on the list set.
func (d *DB) ListHasIndividual(ctx context.Context, list, set string, individual int64) (bool, error) {
	var n int
	err := d.SQL.QueryRowContext(ctx, `
		SELECT 1
		FROM List
		WHERE listNameValue = $1
		  AND COALESCE(listSetValue, '') = $2
		  AND individual = $3
		LIMIT 1`, list, set, individual).Scan(&n)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// ListUnsubscribe ends list membership for the individual.
// The procedure name is ListUnSubscribe.
func (d *DB) ListUnsubscribe(ctx context.Context, list, set string, individual int64) error {
	_, err := d.SQL.ExecContext(ctx, `SELECT ListUnSubscribe($1, $2, $3)`, list, set, individual)
	return err
}
