package business

import (
	"context"
	"strings"
)

// GetWord returns the Word id for value. The procedure default culture is en-US.
func (d *DB) GetWord(ctx context.Context, value string) (int, error) {
	return d.queryInt(ctx, `SELECT GetWord($1)`, value)
}

// GetIdentifier returns the Word id whose culture is null.
// Session token types and campaign channels use this, not GetWord.
func (d *DB) GetIdentifier(ctx context.Context, value string) (int, error) {
	return d.queryInt(ctx, `SELECT GetIdentifier($1)`, value)
}

// GetSentence returns the Sentence id for value.
func (d *DB) GetSentence(ctx context.Context, value string) (int, error) {
	return d.queryInt(ctx, `SELECT GetSentence($1)`, value)
}

// GetParagraph returns the Paragraph id for value.
func (d *DB) GetParagraph(ctx context.Context, value string) (int, error) {
	return d.queryInt(ctx, `SELECT GetParagraph($1)`, value)
}

// GetEmail returns the Email id for addr (user[+plus]@host).
func (d *DB) GetEmail(ctx context.Context, addr string) (int, error) {
	return d.queryInt(ctx, `SELECT GetEmail($1)`, addr)
}

// GetIndividualEmail returns the Individual id for addr, creating the person
// when the mailbox is not already on IndividualEmail.
func (d *DB) GetIndividualEmail(ctx context.Context, addr string) (int64, error) {
	return d.queryInt64(ctx, `SELECT GetIndividualEmail($1)`, addr)
}

// GetApplication returns the Application id for name.
func (d *DB) GetApplication(ctx context.Context, name string) (int, error) {
	return d.queryInt(ctx, `SELECT GetApplication($1)`, name)
}

// GetApplicationRelease returns the ApplicationRelease id.
// A nil release attaches the application with a null Release.
func (d *DB) GetApplicationRelease(ctx context.Context, app int, release *int) (int, error) {
	return d.queryInt(ctx, `SELECT GetApplicationRelease($1, $2)`, app, nullInt(release))
}

// GetRelease returns the Release id for version.
func (d *DB) GetRelease(ctx context.Context, version int) (int, error) {
	return d.queryInt(ctx, `SELECT GetRelease($1)`, version)
}

// GetSite returns the Site id for name. Site.name is a Sentence id.
func (d *DB) GetSite(ctx context.Context, name string) (int, error) {
	return d.queryInt(ctx, `SELECT GetSite($1)`, name)
}

// GetSiteApplicationRelease returns the SiteApplicationRelease id.
func (d *DB) GetSiteApplicationRelease(ctx context.Context, site, applicationRelease int) (int, error) {
	return d.queryInt(ctx, `SELECT GetSiteApplicationRelease($1, $2)`, site, applicationRelease)
}

// EnsureSiteApplication returns Site and SiteApplicationRelease ids.
// rel is unused: Release.version has to be a Version id, so the release is null.
func (d *DB) EnsureSiteApplication(ctx context.Context, host, appName string, rel int) (siteID, sarID int, err error) {
	_ = rel
	app, err := d.GetApplication(ctx, appName)
	if err != nil {
		return 0, 0, err
	}
	ar, err := d.GetApplicationRelease(ctx, app, nil)
	if err != nil {
		return 0, 0, err
	}
	siteID, err = d.GetSite(ctx, host)
	if err != nil {
		return 0, 0, err
	}
	sarID, err = d.GetSiteApplicationRelease(ctx, siteID, ar)
	return siteID, sarID, err
}

func pathValue(p string) any {
	return nullStr(strings.TrimLeft(p, "/"))
}

// GetURL returns a Path id. secure is 1 for https and 0 for http.
func (d *DB) GetURL(ctx context.Context, secure int, host, path, getq string) (int64, error) {
	return d.GetURLPort(ctx, secure, host, path, getq, nil)
}

// GetURLPort is GetURL with an explicit TCP port. Nil port is the protocol default.
func (d *DB) GetURLPort(ctx context.Context, secure int, host, path, getq string, port *int) (int64, error) {
	hostArg, pathArg, getArg := nullStr(host), pathValue(path), nullStr(getq)
	if port == nil {
		return d.queryInt64(ctx, `SELECT GetUrl($1, $2, $3, $4)`, secure, hostArg, pathArg, getArg)
	}
	return d.queryInt64(ctx, `SELECT GetUrl($1, $2, $3, $4, $5)`, secure, hostArg, pathArg, getArg, *port)
}

// GetPath is the protocol form. host does not contain :port.
func (d *DB) GetPath(ctx context.Context, protocol string, secure int, host, value, getq string, port *int) (int64, error) {
	hostArg, valueArg, getArg := nullStr(host), pathValue(value), nullStr(getq)
	if port == nil {
		return d.queryInt64(ctx, `SELECT GetPath($1, $2, $3, $4, $5)`, protocol, secure, hostArg, valueArg, getArg)
	}
	return d.queryInt64(ctx, `SELECT GetPath($1, $2, $3, $4, $5, $6)`, protocol, secure, hostArg, valueArg, getArg, *port)
}
