package business

import (
	"strings"
	"testing"
)

func TestExampleFill(t *testing.T) {
	link, ok := ExampleFill("link", "url")
	if !ok || link != "https://example.test/notice" {
		t.Fatalf("link %q %v", link, ok)
	}
	count, ok := ExampleFill("count", "number")
	if !ok || count != "2" {
		t.Fatalf("count %q %v", count, ok)
	}
	if _, ok := ExampleFill("link", "number"); ok {
		t.Fatal("link with the wrong type")
	}
	if _, ok := ExampleFill("other", "url"); ok {
		t.Fatal("unknown identifier")
	}
}

func TestExampleNoticeHTMLAndMIME(t *testing.T) {
	rows := []ContentElement{
		{Sequence: 1, Kind: "sentence", Value: "Here is the notice", Name: "class", Attribute: "heading"},
		{Sequence: 2, Kind: "dynamic", Name: "class", Attribute: "note", Identifier: "link", IdentifierType: "url"},
		{Sequence: 3, Kind: "sentence", Value: "Items ready", Name: "class", Attribute: "lede"},
		{Sequence: 4, Kind: "dynamic", Identifier: "count", IdentifierType: "number"},
	}
	pieces := piecesFromElements(rows, ExampleFill)
	page, err := HTML(pieces)
	if err != nil {
		t.Fatal(err)
	}
	want := strings.Join([]string{
		`<h2 class="heading">Here is the notice</h2>`,
		`<p class="note">https://example.test/notice</p>`,
		`<p class="lede">Items ready</p>`,
		`<p>2</p>`,
	}, "\n")
	if page != want {
		t.Fatalf("html\n%s", page)
	}
	body, err := MIME(pieces)
	if err != nil {
		t.Fatal(err)
	}
	plain := joinText(pieces)
	if plain != "Here is the notice\nhttps://example.test/notice\nItems ready\n2" {
		t.Fatalf("plain %q", plain)
	}
	if !strings.Contains(body, "multipart/alternative") ||
		!strings.Contains(body, "text/plain") ||
		!strings.Contains(body, "text/html") ||
		!strings.Contains(body, page) ||
		!strings.Contains(body, plain) {
		t.Fatalf("mime %s", body)
	}
}
