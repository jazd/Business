package business

import (
	"context"
	"database/sql"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
)

func TestGetSiteCallsProcedure(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`SELECT GetSite\(\$1\)`).
		WithArgs("Example").
		WillReturnRows(sqlmock.NewRows([]string{"getsite"}).AddRow(4))
	d := &DB{SQL: sqldb}
	id, err := d.GetSite(context.Background(), "Example")
	if err != nil {
		t.Fatal(err)
	}
	if id != 4 {
		t.Fatalf("id=%d", id)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestPutPasswordCallsProcedure(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`SELECT PutPassword\(\$1\)`).
		WithArgs("secret").
		WillReturnRows(sqlmock.NewRows([]string{"putpassword"}).AddRow(9))
	d := &DB{SQL: sqldb}
	id, err := d.PutPassword(context.Background(), "secret")
	if err != nil {
		t.Fatal(err)
	}
	if id != 9 {
		t.Fatalf("id=%d", id)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestSetSessionTimeoutZeroIsNoRows(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`SELECT SetSessionTimeout`).
		WithArgs("tok", 3, 3600).
		WillReturnRows(sqlmock.NewRows([]string{"setsessiontimeout"}).AddRow(0))
	d := &DB{SQL: sqldb}
	err = d.SetSessionTimeout(context.Background(), "tok", 3, 3600)
	if err != sql.ErrNoRows {
		t.Fatalf("err=%v", err)
	}
}

func TestClientCultureCallsProcedure(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`SELECT ClientCulture\(\$1::varchar\)`).
		WithArgs("fr-FR").
		WillReturnRows(sqlmock.NewRows([]string{"clientculture"}).AddRow(1036))
	d := &DB{SQL: sqldb}
	code, err := d.ClientCulture(context.Background(), "fr-FR")
	if err != nil {
		t.Fatal(err)
	}
	if code != 1036 {
		t.Fatalf("code=%d", code)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestContentBodyCallsProcedure(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	mock.ExpectQuery(`FROM ContentBody`).
		WithArgs(7, "html").
		WillReturnRows(sqlmock.NewRows([]string{
			"sequence", "kind", "element", "value", "format", "argument", "name", "attribute",
			"identifier", "identifierType",
		}).AddRow(1, "sentence", 4, "DbFit line", 2, nil, "class", "htmltok", nil, nil))
	d := &DB{SQL: sqldb}
	rows, err := d.ContentBody(context.Background(), 7, "html")
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 || rows[0].Attribute != "htmltok" || rows[0].Value != "DbFit line" {
		t.Fatalf("rows=%+v", rows)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestEntitlementGrantCallsProcedure(t *testing.T) {
	sqldb, mock, err := sqlmock.New()
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	starts := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	mock.ExpectQuery(`SELECT EntitlementGrant`).
		WithArgs(int64(8), "Example", "Pro", "comp", "active", starts, nil, nil).
		WillReturnRows(sqlmock.NewRows([]string{"entitlementgrant"}).AddRow(15))
	d := &DB{SQL: sqldb}
	id, err := d.EntitlementGrant(context.Background(), 8, "Example", "Pro", "comp", "active", starts, nil, "")
	if err != nil {
		t.Fatal(err)
	}
	if id != 15 {
		t.Fatalf("id=%d", id)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestNoTableWrites(t *testing.T) {
	files := []string{"db.go", "get.go", "session.go", "path.go", "content.go", "compose.go", "entitlement.go"}
	for _, name := range files {
		b, err := os.ReadFile(name)
		if err != nil {
			t.Fatal(err)
		}
		s := strings.ToUpper(string(b))
		for _, bad := range []string{"INSERT ", "UPDATE ", "DELETE "} {
			if strings.Contains(s, bad) {
				t.Fatalf("%s contains %s", name, bad)
			}
		}
	}
}

func TestBoostExpired(t *testing.T) {
	created := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	sec := 3600
	info := SessionInfo{Created: created, Timeout: &sec}
	if info.BoostExpired(created.Add(30 * time.Minute)) {
		t.Fatal("inside the timeout")
	}
	if !info.BoostExpired(created.Add(2 * time.Hour)) {
		t.Fatal("past the timeout")
	}
}
