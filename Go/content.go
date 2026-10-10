package business

import (
	"context"
	"database/sql"
)

// ContentElement is one current-edition element and its winning attribute.
// Name and Attribute are empty when the element has no winning attribute.
type ContentElement struct {
	Sequence  int
	Kind      string
	Element   int
	Value     string
	Format    *int
	Argument  string
	Name      string
	Attribute string
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
func (d *DB) SetContentElement(ctx context.Context, content, sequence int, format, word, sentence, paragraph *int, argument string) (int, error) {
	return d.queryInt(ctx, `SELECT SetContentElement($1, $2, $3, $4, $5, $6, $7)`,
		content, sequence, nullInt(format), nullInt(word), nullInt(sentence), nullInt(paragraph), nullStr(argument))
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

// ContentBody returns the current edition of one content id for a target.
func (d *DB) ContentBody(ctx context.Context, content int, target string) ([]ContentElement, error) {
	rows, err := d.SQL.QueryContext(ctx, `
		SELECT sequence, kind, element, value, format, argument, name, attribute
		FROM ContentBody($1, $2::varchar)`, content, nullStr(target))
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
func (d *DB) SiteContent(ctx context.Context, site int, target string) ([]PlacedContent, error) {
	rows, err := d.SQL.QueryContext(ctx, `
		SELECT place, content, sequence, kind, element, value, format, argument, name, attribute
		FROM SiteContent($1, $2::varchar)`, site, nullStr(target))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanPlaced(rows)
}

// ListContent returns unstopped list placements and their elements for a target.
func (d *DB) ListContent(ctx context.Context, list, target string) ([]PlacedContent, error) {
	rows, err := d.SQL.QueryContext(ctx, `
		SELECT place, content, sequence, kind, element, value, format, argument, name, attribute
		FROM ListContent($1, $2::varchar)`, list, nullStr(target))
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
	var value, argument, name, attribute sql.NullString
	var format sql.NullInt64
	err := rows.Scan(&el.Sequence, &el.Kind, &el.Element, &value, &format, &argument, &name, &attribute)
	if err != nil {
		return ContentElement{}, err
	}
	el.Value = value.String
	el.Argument = argument.String
	el.Name = name.String
	el.Attribute = attribute.String
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
		var value, argument, name, attribute sql.NullString
		var format sql.NullInt64
		err := rows.Scan(
			&row.Place, &row.Content,
			&row.Sequence, &row.Kind, &row.Element, &value, &format, &argument, &name, &attribute,
		)
		if err != nil {
			return nil, err
		}
		row.Value = value.String
		row.Argument = argument.String
		row.Name = name.String
		row.Attribute = attribute.String
		if format.Valid {
			v := int(format.Int64)
			row.Format = &v
		}
		out = append(out, row)
	}
	return out, rows.Err()
}
