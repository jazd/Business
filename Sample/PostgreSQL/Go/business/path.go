package business

import (
	"database/sql"
	"net/url"
	"strings"
)

var PathErrors map[int][]string

func init() {
	// Just make PathErrors here until language to error mapping is official
	PathErrors = make(map[int][]string)
	PathErrors[1033] = append(PathErrors[1033], "Host can not be empty.")
	PathErrors[1033] = append(PathErrors[1033], "Invalid URL or database.")
	PathErrors[1033] = append(PathErrors[1033], "URL view error.")
}

type Path struct {
	ok        bool
	language  int
	message   string
	db        *sql.DB
	id        *uint32
	protocol  string
	secure    bool
	host      string
	value     *string
	get       *string
	fullValue *string
}

func NewURL() *Path {
	url := new(Path)
	url.language = 1033 // default english
	url.protocol = "http"
	return url
}

func NewURLDb(db *sql.DB) *Path {
	url := NewURL()
	url.db = db
	return url
}

func (url *Path) String() string {
	return "URL"
}

func (url *Path) Id() uint32 {
	if url.id == nil || !url.ok {
		return 0
	} else {
		return *url.id
	}
}
func (url *Path) Value() string {
	empty := ""
	if url.fullValue == nil {
		// retrieve from view
		url.refreshURL()
	}

	if url.fullValue != nil {
		return *url.fullValue
	} else {
		return empty
	}
}

func (path *Path) GetPathParsedURL(parsed *url.URL) (*Path, bool) {
	secure := false
	if parsed.Scheme == "https" {
		secure = true
	}
	return path.GetPathURL(secure, parsed.Host, strings.Trim(parsed.Path, "/"), parsed.RawQuery)
}

func (url *Path) GetPathURL(secure bool, host string, path string, get string) (*Path, bool) {
	url.ok = false
	url.message = ""

	url.secure = secure
	url.host = host
	// Invalidate view
	url.fullValue = nil

	// Do not insert empty strings into the database
	url.value = nil
	if path != "" {
		url.value = &path
	}
	url.get = nil
	if get != "" {
		url.get = &get
	}

	// Must have at least host defined
	if host != "" && url.db != nil {
		secureInt := 0
		if url.secure {
			secureInt = 1
		}
		// Be sure we can get an unique id for this URL
		row := url.db.QueryRow("SELECT GetURL($1, $2, $3, $4)", secureInt, url.host, NullableStringPointer(url.value), NullableStringPointer(url.get))
		var id uint32
		if err := row.Scan(&id); err != nil {
			url.message = PathErrors[url.language][1] + " " + err.Error()
		} else {
			url.id = &id
			url.ok = true
		}
	} else {
		url.message = PathErrors[url.language][0]
	}

	return url, url.ok
}

// Pickup current view of URL.path
func (url *Path) refreshURL() (ok bool) {
	ok = false
	if url.id != nil && url.db != nil {
		row := url.db.QueryRow("SELECT value FROM URL WHERE path = $1", *url.id)
		var fullValue string
		if err := row.Scan(&fullValue); err != nil {
			url.message = PathErrors[url.language][2] + " " + err.Error()
		} else {
			url.fullValue = &fullValue
			ok = true
		}
	}
	return ok
}
