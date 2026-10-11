// Command render prints one content id, site, or list.
//
// The default database is 127.0.0.1 port 5432, user test, database MyCo,
// the same server make pgsqldb and DbFit use. PGHOST, PGPORT, PGUSER,
// PGPASSWORD, and PGDATABASE replace those defaults when set.
package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/jazd/Business/Go"
)

func main() {
	if err := run(os.Args[1:], os.Getenv, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type options struct {
	content  string
	site     string
	list     string
	target   string
	culture  string
	host     string
	port     string
	user     string
	password string
	dbname   string
}

func run(args []string, getenv func(string) string, stdout io.Writer) error {
	opt, err := optionsFrom(args, getenv)
	if err != nil {
		return err
	}
	db, err := openDB(opt)
	if err != nil {
		return err
	}
	defer db.SQL.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	text, err := render(ctx, db, opt)
	if err != nil {
		return err
	}
	writeRender(stdout, text)
	return nil
}

// writeRender prints a rendered page. An empty result, including spaces
// and newlines, writes nothing.
func writeRender(stdout io.Writer, text string) {
	if strings.TrimSpace(text) == "" {
		return
	}
	fmt.Fprintln(stdout, text)
}

func optionsFrom(args []string, getenv func(string) string) (options, error) {
	opt := options{
		target:   "html",
		host:     firstSet(getenv("PGHOST"), "127.0.0.1"),
		port:     firstSet(getenv("PGPORT"), "5432"),
		user:     firstSet(getenv("PGUSER"), "test"),
		password: firstSet(getenv("PGPASSWORD"), "dbfit"),
		dbname:   firstSet(getenv("PGDATABASE"), "MyCo"),
	}
	fs := flag.NewFlagSet("render", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.StringVar(&opt.content, "content", "", "content id, or the sentence name of the content")
	fs.StringVar(&opt.site, "site", "", "site id")
	fs.StringVar(&opt.list, "list", "", "list name")
	fs.StringVar(&opt.target, "target", opt.target, "html, mime, or txt")
	fs.StringVar(&opt.culture, "culture", "", "Culture.name; empty uses ClientCulture")
	fs.StringVar(&opt.host, "host", opt.host, "database host")
	fs.StringVar(&opt.port, "port", opt.port, "database port")
	fs.StringVar(&opt.user, "user", opt.user, "database user")
	fs.StringVar(&opt.password, "password", opt.password, "database password")
	fs.StringVar(&opt.dbname, "db", opt.dbname, "database name")
	if err := fs.Parse(args); err != nil {
		return options{}, err
	}
	n := 0
	if opt.content != "" {
		n++
	}
	if opt.site != "" {
		n++
	}
	if opt.list != "" {
		n++
	}
	if n != 1 {
		return options{}, fmt.Errorf("pass one of -content, -site, or -list")
	}
	if opt.site != "" {
		if _, err := strconv.Atoi(opt.site); err != nil {
			return options{}, fmt.Errorf("site id: %s", opt.site)
		}
	}
	return opt, nil
}

func firstSet(value, fallback string) string {
	if value != "" {
		return value
	}
	return fallback
}

func openDB(opt options) (*business.DB, error) {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s",
		opt.host, opt.port, opt.user, opt.password, opt.dbname)
	sqldb, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := sqldb.PingContext(ctx); err != nil {
		sqldb.Close()
		return nil, err
	}
	return &business.DB{SQL: sqldb}, nil
}

func render(ctx context.Context, db *business.DB, opt options) (string, error) {
	page := business.Render{
		Target:  opt.target,
		Culture: opt.culture,
		Dynamic: business.ExampleFill,
	}
	switch {
	case opt.content != "":
		id, err := contentID(ctx, db, opt.content)
		if err != nil {
			return "", err
		}
		return db.ComposeContent(ctx, id, page)
	case opt.site != "":
		id, _ := strconv.Atoi(opt.site)
		return db.ComposeSite(ctx, id, page)
	default:
		return db.ComposeList(ctx, opt.list, page)
	}
}

func contentID(ctx context.Context, db *business.DB, name string) (int, error) {
	if id, err := strconv.Atoi(name); err == nil {
		return id, nil
	}
	var id int
	err := db.SQL.QueryRowContext(ctx, `
		SELECT Content.id
		FROM Content
		JOIN Sentence ON Sentence.id = Content.name
		 AND Sentence.culture = 1033
		 AND UPPER(Sentence.value) = UPPER($1)
		LIMIT 1`, name).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}
