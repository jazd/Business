package business

import (
	"database/sql"
	"net/url"
	"strings"
)

var SessionErrors map[int][]string

func init() {
	// Just make SessionErrors here until language to error mapping is official
	SessionErrors = make(map[int][]string)
	SessionErrors[1033] = append(SessionErrors[1033], "Agent String and remoteAddr can not be empty.")
	SessionErrors[1033] = append(SessionErrors[1033], "Invalid Session or database.")
}

type Session struct {
	ok       bool
	language int
	db       *sql.DB
	message  string
	id       *uint64
}

// Make a structure like https://github.com/ua-parser/uap-go uses
type UserAgent struct {
	Family string
	Major  string
	Minor  string
	Patch  string
}
type Os struct {
	Family     string
	Major      string
	Minor      string
	Patch      string
	PatchMinor string
}
type Device struct {
	Family string
	Brand  string
	Model  string
}
type ParsedAgentString struct {
	UserAgent *UserAgent
	Os        *Os
	Device    *Device
}

func NewSession(db *sql.DB) *Session {
	session := new(Session)
	session.db = db
	session.language = 1033 // default english

	return session
}

func (session *Session) Anonymous(userAgent string, parsedAgentString *ParsedAgentString, referer string, remoteAddr string) (Id uint64, ok bool) {
	// Convert referrer to go parsed url
	secure := false
	host := ""
	path := ""
	query := ""
	parsedURL, err := url.Parse(referer)
	if err == nil {
		if parsedURL.Scheme == "https" {
			secure = true
		}
		host = parsedURL.Host
		path = strings.Trim(parsedURL.Path, "/")
		query = parsedURL.RawQuery
	}

	// Convert parsedAgentString.Device.Family to a family and version name
	deviceFamilyVersion := ""
	deviceFamily := parsedAgentString.Device.Family
	result := strings.SplitN(deviceFamily, " ", 2)
	if len(result) > 1 {
		deviceFamily = result[0]
		deviceFamilyVersion = result[1]
	}

	return session.AnonymousParsed(userAgent, parsedAgentString, deviceFamily, deviceFamilyVersion, secure, host, path, query, remoteAddr)
}

func (session *Session) AnonymousParsed(userAgent string, parsedAgentString *ParsedAgentString, deviceFamily string, deviceFamilyVersion string, secure bool, host string, path string, query string, remoteAddr string) (Id uint64, ok bool) {
	session.ok = false
	session.message = ""

	// At lease userAgent string and remoteAddr must be defined
	if userAgent != "" && remoteAddr != "" {
		secureInt := 0
		if secure {
			secureInt = 1
		}

		// Be sure we can get an unique id for session
		row := session.db.QueryRow("SELECT AnonymousSession($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)",
			userAgent, NullableString(parsedAgentString.UserAgent.Family), NullableString(parsedAgentString.UserAgent.Major), NullableString(parsedAgentString.UserAgent.Minor), NullableString(parsedAgentString.UserAgent.Patch), sql.NullString{},
			NullableString(parsedAgentString.Os.Family), NullableString(parsedAgentString.Os.Major), NullableString(parsedAgentString.Os.Minor), NullableString(parsedAgentString.Os.Patch),
			NullableString(parsedAgentString.Device.Brand), NullableString(parsedAgentString.Device.Model), NullableString(deviceFamily), NullableString(deviceFamilyVersion),
			secureInt, NullableString(host), NullableString(path), NullableString(query),
			remoteAddr)
		if err := row.Scan(&Id); err != nil {
			session.message = SessionErrors[session.language][1] + " " + err.Error()
		} else {
			session.id = &Id
			session.ok = true
		}
	} else {
		session.message = SessionErrors[session.language][0]
	}

	return Id, session.ok
}
