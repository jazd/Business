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

func TestNoTableWrites(t *testing.T) {
	files := []string{"db.go", "get.go", "session.go", "path.go"}
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


