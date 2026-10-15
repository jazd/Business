package business

import (
	"context"
	"database/sql"
)

// ContentElement is one current-edition element and its winning attribute.
// Name and Attribute are empty when the element has no winning attribute.
// Identifier and IdentifierType are the culture-null words on a dynamic element.
// Element is 0 when the row has no word, sentence, or paragraph.
type ContentElement struct {
	Sequence       int
	Kind           string
	Element        int
	Value          string
	Format         *int
	Argument       string
	Name           string
	Attribute      string
	Identifier     string
	IdentifierType string
	Squash         string
}

// PlacedContent is a ContentElement on a site or a list, in placement order.
type PlacedContent struct {
	Place   int
	Content int
	ContentElement
}

// FormatToken is one winning attribute name and value.
type FormatToken struct {
	Name  string
	Value string
}

// ClientCulture sets the connection culture by Culture.name.
// An empty name clears it, so reads fall back to 1033.
func (d *DB) ClientCulture(ctx context.Context, name string) (int, error) {
	return d.queryInt(ctx, `SELECT ClientCulture($1::varchar)`, nullStr(name))
}

// PluralWord returns the plural form of word for count. The form follows ClientCulture().
func (d *DB) PluralWord(ctx context.Context, word, count int) (string, error) {
	return d.queryString(ctx, `SELECT PluralWord($1, $2)`, word, count)
}

// SetSessionCulture stores the visitor culture on the session. An empty name clears it.
func (d *DB) SetSessionCulture(ctx context.Context, session int64, culture string) (int64, error) {
	return d.queryInt64(ctx, `SELECT SetSessionCulture($1, $2)`, session, nullStr(culture))
}

// SetFormat returns the format id for a sentence name.
func (d *DB) SetFormat(ctx context.Context, name string) (int, error) {
	return d.queryInt(ctx, `SELECT SetFormat($1)`, name)
}

// SetFormatAttribute adds an unstopped attribute. An empty target applies to every output.
func (d *DB) SetFormatAttribute(ctx context.Context, format int, name, value, target string) (int, error) {
	return d.queryInt(ctx, `SELECT SetFormatAttribute($1, $2, $3, $4)`, format, name, nullStr(value), nullStr(target))
}

// StopFormatAttribute ends the unstopped attribute with this name, value, and target.
func (d *DB) StopFormatAttribute(ctx context.Context, format int, name, value, target string) (int, error) {
	return d.queryInt(ctx, `SELECT StopFormatAttribute($1, $2, $3, $4)`, format, name, nullStr(value), nullStr(target))
}

// SetCampaign finds or inserts a campaign by name.
// channel is a culture-null word (email, mail). List name and list set stay GetWord.
// An empty set or channel stores null. A nil period stores null.
func (d *DB) SetCampaign(ctx context.Context, name, list, set, channel string, period *int) (int, error) {
	return d.queryInt(ctx, `SELECT SetCampaign($1, $2, $3, $4, $5)`,
		name, list, nullStr(set), nullStr(channel), nullInt(period))
}

// SetContent returns the stable content id for a sentence name.
func (d *DB) SetContent(ctx context.Context, name string) (int, error) {
	return d.queryInt(ctx, `SELECT SetContent($1)`, name)
}

// StopContent closes the open edition.
func (d *DB) StopContent(ctx context.Context, content int) (int, error) {
	return d.queryInt(ctx, `SELECT StopContent($1)`, content)
}

// SetContentElement writes one element on the open edition.
// Exactly one of word, sentence, or paragraph is set. argument is the count name for a word.
// squash empty stores null. Any other string is a GetIdentifier name.
func (d *DB) SetContentElement(ctx context.Context, content, sequence int, format, word, sentence, paragraph *int, argument, squash string) (int, error) {
	return d.queryInt(ctx, `SELECT SetContentElement($1, $2, $3, $4, $5, $6, $7, NULL, NULL, $8)`,
		content, sequence, nullInt(format), nullInt(word), nullInt(sentence), nullInt(paragraph), nullStr(argument), nullStr(squash))
}

// SetContentSite places content on a site. A nil sequence uses the next place.
func (d *DB) SetContentSite(ctx context.Context, site, content int, sequence *int) (int, error) {
	if sequence == nil {
		return d.queryInt(ctx, `SELECT SetContentSite($1, $2)`, site, content)
	}
	return d.queryInt(ctx, `SELECT SetContentSite($1, $2, $3)`, site, content, *sequence)
}

// StopContentSite ends that placement.
func (d *DB) StopContentSite(ctx context.Context, site, content int) (int, error) {
	return d.queryInt(ctx, `SELECT StopContentSite($1, $2)`, site, content)
}

// SetContentList places content on a list name. A nil sequence uses the next place.
func (d *DB) SetContentList(ctx context.Context, list string, content int, sequence *int) (int, error) {
	if sequence == nil {
		return d.queryInt(ctx, `SELECT SetContentList($1, $2)`, list, content)
	}
	return d.queryInt(ctx, `SELECT SetContentList($1, $2, $3)`, list, content, *sequence)
}

// StopContentList ends that placement.
func (d *DB) StopContentList(ctx context.Context, list string, content int) (int, error) {
	return d.queryInt(ctx, `SELECT StopContentList($1, $2)`, list, content)
}

// FormatFor returns winning attributes for one format and target.
// A target row wins over the null-target row with the same name.
func (d *DB) FormatFor(ctx context.Context, format int, target string) ([]FormatToken, error) {
	rows, err := d.SQL.QueryContext(ctx, `
		SELECT name, value FROM FormatFor($1, $2::varchar)`, format, nullStr(target))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []FormatToken
	for rows.Next() {
		var name, value sql.NullString
		if err := rows.Scan(&name, &value); err != nil {
			return nil, err
		}
		out = append(out, FormatToken{Name: name.String, Value: value.String})
	}
	return out, rows.Err()
}

const elementCols = `sequence, kind, element, value, format, argument, name, attribute, identifier, identifierType, squash`

// ContentBody returns the current edition of one content id for a target.
// The read uses ClientCulture.
func (d *DB) ContentBody(ctx context.Context, content int, target string) ([]ContentElement, error) {
	return d.contentElements(ctx, content, target, "")
}

func (d *DB) contentElements(ctx context.Context, content int, target, culture string) ([]ContentElement, error) {
	q := `SELECT ` + elementCols + ` FROM ContentBody($1, $2::varchar)`
	args := []any{content, nullStr(target)}
	if culture != "" {
		q = `SELECT ` + elementCols + ` FROM ContentBody($1, $2::varchar, $3::varchar)`
		args = append(args, culture)
	}
	rows, err := d.SQL.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ContentElement
	for rows.Next() {
		el, err := scanContentElement(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, el)
	}
	return out, rows.Err()
}

// SiteContent returns unstopped site placements and their elements for a target.
// The read uses ClientCulture.
func (d *DB) SiteContent(ctx context.Context, site int, target string) ([]PlacedContent, error) {
	return d.siteElements(ctx, site, target, "")
}

func (d *DB) siteElements(ctx context.Context, site int, target, culture string) ([]PlacedContent, error) {
	q := `SELECT place, content, ` + elementCols + ` FROM SiteContent($1, $2::varchar)`
	args := []any{site, nullStr(target)}
	if culture != "" {
		q = `SELECT place, content, ` + elementCols + ` FROM SiteContent($1, $2::varchar, $3::varchar)`
		args = append(args, culture)
	}
	rows, err := d.SQL.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPlaced(rows)
}

// ListContent returns unstopped list placements and their elements for a target.
// The read uses ClientCulture.
func (d *DB) ListContent(ctx context.Context, list, target string) ([]PlacedContent, error) {
	return d.listElements(ctx, list, target, "")
}

func (d *DB) listElements(ctx context.Context, list, target, culture string) ([]PlacedContent, error) {
	q := `SELECT place, content, ` + elementCols + ` FROM ListContent($1, $2::varchar)`
	args := []any{list, nullStr(target)}
	if culture != "" {
		q = `SELECT place, content, ` + elementCols + ` FROM ListContent($1, $2::varchar, $3::varchar)`
		args = append(args, culture)
	}
	rows, err := d.SQL.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPlaced(rows)
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanContentElement(rows rowScanner) (ContentElement, error) {
	var el ContentElement
	var value, argument, name, attribute, identifier, identifierType, squash sql.NullString
	var element, format sql.NullInt64
	err := rows.Scan(
		&el.Sequence, &el.Kind, &element, &value, &format, &argument, &name, &attribute,
		&identifier, &identifierType, &squash,
	)
	if err != nil {
		return ContentElement{}, err
	}
	if element.Valid {
		el.Element = int(element.Int64)
	}
	el.Value = value.String
	el.Argument = argument.String
	el.Name = name.String
	el.Attribute = attribute.String
	el.Identifier = identifier.String
	el.IdentifierType = identifierType.String
	el.Squash = squash.String
	if format.Valid {
		v := int(format.Int64)
		el.Format = &v
	}
	return el, nil
}

func scanPlaced(rows *sql.Rows) ([]PlacedContent, error) {
	var out []PlacedContent
	for rows.Next() {
		var row PlacedContent
		var value, argument, name, attribute, identifier, identifierType, squash sql.NullString
		var element, format sql.NullInt64
		err := rows.Scan(
			&row.Place, &row.Content,
			&row.Sequence, &row.Kind, &element, &value, &format, &argument, &name, &attribute,
			&identifier, &identifierType, &squash,
		)
		if err != nil {
			return nil, err
		}
		if element.Valid {
			row.Element = int(element.Int64)
		}
		row.Value = value.String
		row.Argument = argument.String
		row.Name = name.String
		row.Attribute = attribute.String
		row.Identifier = identifier.String
		row.IdentifierType = identifierType.String
		row.Squash = squash.String
		if format.Valid {
			v := int(format.Int64)
			row.Format = &v
		}
		out = append(out, row)
	}
	return out, rows.Err()
}
