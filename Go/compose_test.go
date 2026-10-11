package business

import (
	"context"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

func editionRows() *sqlmock.Rows {
	return sqlmock.NewRows([]string{
		"sequence", "kind", "element", "value", "format", "argument", "name", "attribute",
		"identifier", "identifierType", "squash",
	})
}

func TestPiecesUseDynamicTextBetweenSentences(t *testing.T) {
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Element: 1, Value: "Hello", Name: "class", Attribute: "lede"},
		{Sequence: 2, Kind: "dynamic", Identifier: "link", IdentifierType: "url"},
		{Sequence: 3, Kind: "sentence", Element: 2, Value: "Thanks"},
	}
	pieces := piecesFromElements(rows, func(name, kind string) (string, bool) {
		if name == "link" && kind == "url" {
			return "https://example.test", true
		}
		return "", false
	})
	got := joinText(pieces)
	want := "Hello\nhttps://example.test\nThanks"
	if got != want {
		t.Fatalf("got %q", got)
	}
	if pieces[0].Attr != "class" || pieces[0].Token != "lede" {
		t.Fatalf("attribute %+v", pieces[0])
	}
	if pieces[1].Text != "https://example.test" {
		t.Fatalf("dynamic piece %+v", pieces[1])
	}
}

func TestNilDynamicOmitsDynamicRows(t *testing.T) {
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Value: "Hello"},
		{Sequence: 2, Kind: "dynamic", Identifier: "link", IdentifierType: "url"},
		{Sequence: 3, Kind: "sentence", Value: "Thanks"},
	}
	got := joinText(piecesFromElements(rows, nil))
	if got != "Hello\nThanks" {
		t.Fatalf("got %q", got)
	}
}

func TestDynamicFalseSkipsOneElement(t *testing.T) {
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Value: "Hello"},
		{Sequence: 2, Kind: "dynamic", Identifier: "price", IdentifierType: "money"},
		{Sequence: 3, Kind: "sentence", Value: "Thanks"},
	}
	got := joinText(piecesFromElements(rows, func(string, string) (string, bool) {
		return "", false
	}))
	if got != "Hello\nThanks" {
		t.Fatalf("got %q", got)
	}
}

func TestThankYouStaysSentenceAndWord(t *testing.T) {
	called := false
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Element: 80110, Value: "Thank you for your"},
		{Sequence: 2, Kind: "word", Element: 80110, Value: "subscription", Argument: "subscriptions"},
	}
	pieces := piecesFromElements(rows, func(string, string) (string, bool) {
		called = true
		return "nope", true
	})
	if called {
		t.Fatal("dynamic was called")
	}
	if len(pieces) != 2 || pieces[0].Text != "Thank you for your" || pieces[1].Text != "subscription" {
		t.Fatalf("pieces %+v", pieces)
	}
	if pieces[1].Text == "" {
		t.Fatal("word text missing")
	}
}

func TestHTMLClassTokens(t *testing.T) {
	page, err := HTML([]Piece{
		{Text: "Title", Attr: "class", Token: "heading"},
		{Text: "Lead", Attr: "class", Token: "lede"},
		{Text: "Aside", Attr: "class", Token: "note"},
		{Text: "Quote", Attr: "class", Token: "pullquote"},
		{Text: "Plain"},
		{Text: `a < b & "c"`, Attr: "class", Token: "lede"},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := strings.Join([]string{
		`<h2 class="heading">Title</h2>`,
		`<p class="lede">Lead</p>`,
		`<p class="note">Aside</p>`,
		`<p class="pullquote">Quote</p>`,
		`<p>Plain</p>`,
		`<p class="lede">a &lt; b &amp; &#34;c&#34;</p>`,
	}, "\n")
	if page != want {
		t.Fatalf("html\n%s", page)
	}
	if strings.Contains(page, "<style") {
		t.Fatal("style element")
	}
}

func TestHTMLUsesClassWhenAnotherAttributeIsPresent(t *testing.T) {
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Value: "Hello", Name: "lang", Attribute: "en"},
		{Sequence: 1, Kind: "sentence", Value: "Hello", Name: "class", Attribute: "lede"},
	}
	page, err := HTML(piecesFromElements(rows, nil))
	if err != nil {
		t.Fatal(err)
	}
	if page != `<p class="lede">Hello</p>` {
		t.Fatalf("html %s", page)
	}
}

func TestMIMEContainsPlainAndHTML(t *testing.T) {
	pieces := []Piece{{Text: "Hello", Attr: "class", Token: "lede"}}
	body, err := MIME(pieces)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(body, "Subject:") || strings.Contains(body, "From:") || strings.Contains(body, "To:") {
		t.Fatalf("address header in %s", body)
	}
	if !strings.Contains(body, "multipart/alternative") || !strings.Contains(body, "Hello") {
		t.Fatalf("mime %s", body)
	}
	if !strings.Contains(body, `<p class="lede">Hello</p>`) {
		t.Fatalf("html part %s", body)
	}
	plainAt := strings.Index(body, "text/plain")
	htmlAt := strings.Index(body, "text/html")
	if plainAt < 0 || htmlAt < 0 || plainAt > htmlAt {
		t.Fatalf("part order %s", body)
	}
}

func TestCallerRendererIsTheResult(t *testing.T) {
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Value: "Hello"},
		{Sequence: 2, Kind: "dynamic", Identifier: "link", IdentifierType: "url"},
	}
	var got []Piece
	out, err := renderPieces(piecesFromElements(rows, func(name, kind string) (string, bool) {
		return name + ":" + kind, true
	}), Render{
		Target: "html",
		Renderer: func(pieces []Piece) (string, error) {
			got = pieces
			return "CUSTOM", nil
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if out != "CUSTOM" {
		t.Fatalf("out %q", out)
	}
	if len(got) != 2 || got[0].Text != "Hello" || got[1].Text != "link:url" {
		t.Fatalf("pieces %+v", got)
	}
}

func TestComposeContentDefaults(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`FROM ContentBody\(\$1, \$2::varchar\)$`).
		WithArgs(10, "txt").
		WillReturnRows(editionRows().
			AddRow(1, "sentence", 80110, "Thank you for your", nil, nil, nil, nil, nil, nil, nil).
			AddRow(2, "word", 80110, "subscription", nil, "subscriptions", nil, nil, nil, nil, nil))
	d := &DB{SQL: sqldb}
	got, err := d.ComposeContent(context.Background(), 10, Render{Target: "txt"})
	if err != nil {
		t.Fatal(err)
	}
	if got != "Thank you for your\nsubscription" {
		t.Fatalf("got %q", got)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestComposeContentHTMLAndCulture(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`FROM ContentBody\(\$1, \$2::varchar, \$3::varchar\)`).
		WithArgs(7, "html", "fr-FR").
		WillReturnRows(editionRows().
			AddRow(1, "sentence", 1, "Bonjour", nil, nil, "class", "lede", nil, nil, nil).
			AddRow(2, "dynamic", nil, nil, nil, nil, "class", "note", "link", "url", nil).
			AddRow(3, "sentence", 2, "Merci", nil, nil, nil, nil, nil, nil, nil))
	d := &DB{SQL: sqldb}
	got, err := d.ComposeContent(context.Background(), 7, Render{
		Target:  "html",
		Culture: "fr-FR",
		Dynamic: func(name, kind string) (string, bool) {
			if name == "link" && kind == "url" {
				return "https://example.test", true
			}
			return "", false
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := "<p class=\"lede\">Bonjour</p>\n<p class=\"note\">https://example.test</p>\n<p>Merci</p>"
	if got != want {
		t.Fatalf("html %s", got)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestComposeSiteKeepsPlacementOrder(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`FROM SiteContent`).
		WithArgs(4, "txt").
		WillReturnRows(sqlmock.NewRows([]string{
			"place", "content", "sequence", "kind", "element", "value", "format", "argument",
			"name", "attribute", "identifier", "identifierType", "squash",
		}).
			AddRow(1, 8, 2, "sentence", 1, "Second", nil, nil, nil, nil, nil, nil, nil).
			AddRow(2, 9, 1, "sentence", 2, "First on the next page", nil, nil, nil, nil, nil, nil, nil))
	d := &DB{SQL: sqldb}
	got, err := d.ComposeSite(context.Background(), 4, Render{Target: "txt"})
	if err != nil {
		t.Fatal(err)
	}
	if got != "Second\nFirst on the next page" {
		t.Fatalf("got %q", got)
	}
}

func TestComposeMIMEDefault(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`FROM ListContent`).
		WithArgs("Example", "mime").
		WillReturnRows(sqlmock.NewRows([]string{
			"place", "content", "sequence", "kind", "element", "value", "format", "argument",
			"name", "attribute", "identifier", "identifierType", "squash",
		}).AddRow(1, 3, 1, "sentence", 1, "Hello", nil, nil, "class", "lede", nil, nil, nil))
	d := &DB{SQL: sqldb}
	got, err := d.ComposeList(context.Background(), "Example", Render{Target: "mime"})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "Hello") || !strings.Contains(got, `<p class="lede">Hello</p>`) {
		t.Fatalf("mime %s", got)
	}
}

func lede(seq int, text, squash string) Piece {
	return Piece{
		Text: text, Attr: "class", Token: "lede", Squash: squash, Sequence: seq,
	}
}

func TestSquashSpaceJoin(t *testing.T) {
	pieces := []Piece{
		lede(5, "2", "space"),
		lede(6, "Items ready", "space"),
	}
	page, err := HTML(pieces)
	if err != nil {
		t.Fatal(err)
	}
	if page != `<p class="lede">2 Items ready</p>` {
		t.Fatalf("html %s", page)
	}
	if joinText(pieces) != "2 Items ready" {
		t.Fatalf("txt %q", joinText(pieces))
	}
	body, err := MIME(pieces)
	if err != nil || !strings.Contains(body, "2 Items ready") || !strings.Contains(body, `<p class="lede">2 Items ready</p>`) {
		t.Fatalf("mime %s %v", body, err)
	}
	other := []Piece{lede(1, "2", "box"), lede(2, "Items ready", "box")}
	page, err = HTML(other)
	if err != nil || page != `<p class="lede">2 Items ready</p>` {
		t.Fatalf("other type %s %v", page, err)
	}
}

func TestSquashLeavesSeparatePieces(t *testing.T) {
	separate := [][]Piece{
		{lede(3, "Items ready", ""), lede(4, "2", "")},
		{lede(3, "Items ready", "space"), {Text: "2", Sequence: 4, Squash: "space"}},
		{lede(3, "Items ready", "space"), lede(5, "2", "space")},
		{
			{Text: "2", Attr: "class", Token: "lede", Squash: "space", Sequence: 1, Content: 1},
			{Text: "Items ready", Attr: "class", Token: "lede", Squash: "space", Sequence: 2, Content: 2},
		},
		{lede(4, "2", "space")},
	}
	want := []string{
		"<p class=\"lede\">Items ready</p>\n<p class=\"lede\">2</p>",
		"<p class=\"lede\">Items ready</p>\n<p>2</p>",
		"<p class=\"lede\">Items ready</p>\n<p class=\"lede\">2</p>",
		"<p class=\"lede\">2</p>\n<p class=\"lede\">Items ready</p>",
		"<p class=\"lede\">2</p>",
	}
	for i, pieces := range separate {
		page, err := HTML(pieces)
		if err != nil || page != want[i] {
			t.Fatalf("case %d\n%s\n%v", i, page, err)
		}
	}
}

func TestCustomRendererSeesSquashPieces(t *testing.T) {
	pieces := []Piece{lede(5, "2", "space"), lede(6, "Items ready", "space")}
	var got []Piece
	out, err := renderPieces(pieces, Render{
		Target: "html",
		Renderer: func(in []Piece) (string, error) {
			got = in
			return "CUSTOM", nil
		},
	})
	if err != nil || out != "CUSTOM" {
		t.Fatalf("%q %v", out, err)
	}
	if len(got) != 2 || got[0].Text != "2" || got[1].Text != "Items ready" || got[0].Squash != "space" || got[1].Squash != "space" {
		t.Fatalf("pieces %+v", got)
	}
}

func TestEmptyPiecesRenderNothing(t *testing.T) {
	page, err := HTML(nil)
	if err != nil || page != "" {
		t.Fatalf("html %q %v", page, err)
	}
	body, err := MIME(nil)
	if err != nil || body != "" {
		t.Fatalf("mime %q %v", body, err)
	}
	if joinText(nil) != "" {
		t.Fatal("txt")
	}
}

func TestUnknownTargetRequiresRenderer(t *testing.T) {
	_, err := renderPieces(nil, Render{Target: "document"})
	if err == nil {
		t.Fatal("expected error")
	}
}
