package main

import (
	"bytes"
	"testing"
)

func emptyEnv(string) string { return "" }

func TestDefaultConnectionMatchesMake(t *testing.T) {
	opt, err := optionsFrom([]string{"-content", "10"}, emptyEnv)
	if err != nil {
		t.Fatal(err)
	}
	if opt.host != "127.0.0.1" || opt.port != "5432" || opt.user != "test" ||
		opt.password != "dbfit" || opt.dbname != "MyCo" || opt.target != "html" {
		t.Fatalf("%+v", opt)
	}
}

func TestEnvAndFlagOverrideHost(t *testing.T) {
	env := func(key string) string {
		if key == "PGHOST" {
			return "db.example"
		}
		return ""
	}
	opt, err := optionsFrom([]string{"-content", "Notice"}, env)
	if err != nil {
		t.Fatal(err)
	}
	if opt.host != "db.example" {
		t.Fatalf("env host %s", opt.host)
	}
	opt, err = optionsFrom([]string{"-content", "Notice", "-host", "10.1.1.1", "-target", "txt", "-culture", "fr-FR"}, env)
	if err != nil {
		t.Fatal(err)
	}
	if opt.host != "10.1.1.1" || opt.target != "txt" || opt.culture != "fr-FR" || opt.content != "Notice" {
		t.Fatalf("%+v", opt)
	}
}

func TestEmptyRenderWritesNothing(t *testing.T) {
	var buf bytes.Buffer
	writeRender(&buf, "")
	writeRender(&buf, " \n\t")
	if buf.Len() != 0 {
		t.Fatalf("wrote %q", buf.String())
	}
	writeRender(&buf, "<p>Hello</p>")
	if buf.String() != "<p>Hello</p>\n" {
		t.Fatalf("wrote %q", buf.String())
	}
}

func TestRequiresOneSource(t *testing.T) {
	if _, err := optionsFrom(nil, emptyEnv); err == nil {
		t.Fatal("missing source")
	}
	if _, err := optionsFrom([]string{"-content", "10", "-list", "Example"}, emptyEnv); err == nil {
		t.Fatal("two sources")
	}
	if _, err := optionsFrom([]string{"-site", "next"}, emptyEnv); err == nil {
		t.Fatal("bad site id")
	}
}
