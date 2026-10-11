package business

import (
	"context"
	"fmt"
	"html"
	"strings"
)

// Dynamic supplies the text for one dynamic element.
// name and kind are the culture-null identifier and identifier type.
// ok false skips that element.
type Dynamic func(name, kind string) (text string, ok bool)

// Renderer builds one document from pieces in read order.
type Renderer func(pieces []Piece) (string, error)

// Piece is one element in read order.
// Text is the culture's atom text, or the text Dynamic returned.
// Attr and Token are the winning format attribute.
// The identifier strings are not stored on a piece.
type Piece struct {
	Text  string
	Attr  string
	Token string
}

// Render chooses the target, culture, dynamic fill-in, and renderer.
// An empty Culture uses ClientCulture. A nil Dynamic skips dynamic elements.
// A nil Renderer uses HTML for html, MIME for mime, and newline-joined text for txt.
type Render struct {
	Target   string
	Culture  string
	Dynamic  Dynamic
	Renderer Renderer
}

// ComposeContent reads one content id and renders it.
func (d *DB) ComposeContent(ctx context.Context, content int, r Render) (string, error) {
	rows, err := d.contentElements(ctx, content, r.Target, r.Culture)
	if err != nil {
		return "", err
	}
	return renderPieces(piecesFromElements(rows, r.Dynamic), r)
}

// ComposeSite reads unstopped placements on a site and renders them.
// Order is placement sequence, then element sequence.
func (d *DB) ComposeSite(ctx context.Context, site int, r Render) (string, error) {
	rows, err := d.siteElements(ctx, site, r.Target, r.Culture)
	if err != nil {
		return "", err
	}
	return renderPieces(piecesFromPlaced(rows, r.Dynamic), r)
}

// ComposeList reads unstopped placements for a list name and renders them.
// Order is placement sequence, then element sequence.
func (d *DB) ComposeList(ctx context.Context, list string, r Render) (string, error) {
	rows, err := d.listElements(ctx, list, r.Target, r.Culture)
	if err != nil {
		return "", err
	}
	return renderPieces(piecesFromPlaced(rows, r.Dynamic), r)
}

// HTML renders pieces. A class token of heading is an h2.
// lede and note are paragraphs with that class. Any other class token is a
// paragraph with that class. No class is a paragraph. Text is escaped.
// The result has no style element. Each piece is one line.
func HTML(pieces []Piece) (string, error) {
	lines := make([]string, len(pieces))
	for i, p := range pieces {
		lines[i] = htmlPiece(p)
	}
	return strings.Join(lines, "\n"), nil
}

// MIME renders multipart/alternative. The first part is the piece texts.
// The second part is HTML. The result sets no subject and no address.
func MIME(pieces []Piece) (string, error) {
	plain := joinText(pieces)
	page, err := HTML(pieces)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	b.WriteString("Content-Type: multipart/alternative; boundary=")
	b.WriteString(mimeBoundary)
	b.WriteString("\r\n\r\n")
	writeMIMEPart(&b, "text/plain; charset=UTF-8", plain)
	writeMIMEPart(&b, "text/html; charset=UTF-8", page)
	b.WriteString("--")
	b.WriteString(mimeBoundary)
	b.WriteString("--\r\n")
	return b.String(), nil
}

const mimeBoundary = "business-content"

func writeMIMEPart(b *strings.Builder, contentType, body string) {
	b.WriteString("--")
	b.WriteString(mimeBoundary)
	b.WriteString("\r\nContent-Type: ")
	b.WriteString(contentType)
	b.WriteString("\r\n\r\n")
	b.WriteString(body)
	if body != "" && !strings.HasSuffix(body, "\n") && !strings.HasSuffix(body, "\r\n") {
		b.WriteString("\r\n")
	}
}

func renderPieces(pieces []Piece, r Render) (string, error) {
	render := r.Renderer
	if render == nil {
		var err error
		render, err = rendererFor(r.Target)
		if err != nil {
			return "", err
		}
	}
	return render(pieces)
}

func rendererFor(target string) (Renderer, error) {
	switch strings.ToLower(target) {
	case "html":
		return HTML, nil
	case "mime":
		return MIME, nil
	case "txt":
		return func(pieces []Piece) (string, error) {
			return joinText(pieces), nil
		}, nil
	default:
		return nil, fmt.Errorf("content target %q has no renderer", target)
	}
}

func joinText(pieces []Piece) string {
	parts := make([]string, len(pieces))
	for i, p := range pieces {
		parts[i] = p.Text
	}
	return strings.Join(parts, "\n")
}

func htmlPiece(p Piece) string {
	text := html.EscapeString(p.Text)
	token := ""
	if strings.EqualFold(p.Attr, "class") {
		token = p.Token
	}
	switch strings.ToLower(token) {
	case "heading":
		return "<h2 class=\"heading\">" + text + "</h2>"
	case "lede":
		return "<p class=\"lede\">" + text + "</p>"
	case "note":
		return "<p class=\"note\">" + text + "</p>"
	case "":
		return "<p>" + text + "</p>"
	default:
		return "<p class=\"" + html.EscapeString(token) + "\">" + text + "</p>"
	}
}

type elementRow struct {
	place   int
	content int
	el      ContentElement
	placed  bool
}

func piecesFromElements(rows []ContentElement, dynamic Dynamic) []Piece {
	wrapped := make([]elementRow, len(rows))
	for i, el := range rows {
		wrapped[i] = elementRow{el: el}
	}
	return piecesFrom(wrapped, dynamic)
}

func piecesFromPlaced(rows []PlacedContent, dynamic Dynamic) []Piece {
	wrapped := make([]elementRow, len(rows))
	for i, row := range rows {
		wrapped[i] = elementRow{place: row.Place, content: row.Content, el: row.ContentElement, placed: true}
	}
	return piecesFrom(wrapped, dynamic)
}

func piecesFrom(rows []elementRow, dynamic Dynamic) []Piece {
	var out []Piece
	for i := 0; i < len(rows); {
		j := i + 1
		for j < len(rows) && sameElement(rows[i], rows[j]) {
			j++
		}
		if piece, ok := pieceFrom(rows[i:j], dynamic); ok {
			out = append(out, piece)
		}
		i = j
	}
	return out
}

func sameElement(a, b elementRow) bool {
	if a.el.Sequence != b.el.Sequence || a.placed != b.placed {
		return false
	}
	if a.placed {
		return a.place == b.place && a.content == b.content
	}
	return true
}

func pieceFrom(group []elementRow, dynamic Dynamic) (Piece, bool) {
	first := group[0].el
	var piece Piece
	for _, row := range group {
		if strings.EqualFold(row.el.Name, "class") && row.el.Attribute != "" {
			piece.Attr = row.el.Name
			piece.Token = row.el.Attribute
		}
	}
	if piece.Attr == "" {
		for _, row := range group {
			if row.el.Name != "" {
				piece.Attr = row.el.Name
				piece.Token = row.el.Attribute
				break
			}
		}
	}
	if strings.EqualFold(first.Kind, "dynamic") {
		if dynamic == nil {
			return Piece{}, false
		}
		text, ok := dynamic(first.Identifier, first.IdentifierType)
		if !ok {
			return Piece{}, false
		}
		piece.Text = text
		return piece, true
	}
	piece.Text = first.Value
	return piece, true
}
