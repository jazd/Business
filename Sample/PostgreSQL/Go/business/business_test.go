package business

import (
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"net/url"
	"testing"

	_ "github.com/lib/pq"
	"gopkg.in/DATA-DOG/go-sqlmock.v1"
)

var mockDatabase bool
var db *sql.DB
var err error
var mock sqlmock.Sqlmock

var logged bool // one-time benchmark logging

func init() {
	mockDatabase = true

	if !mockDatabase {
		// Must have a jazd/Business test schema on a PostgreSQL database server
		db, err = sql.Open("postgres", "sslmode=disable host=localhost user=test dbname=MyCo")
		if err != nil {
			log.Fatal(err)
		}

		if err := db.Ping(); err != nil {
			panic(err)
		}
		//defer db.Close() // For initial test of closed messages.  TODO: remove or test specifically
		//db = nil // For initial test of invalid database messages.  TODO: remove or test specifically
	} else {
		// Test with a Mock Database
		db, mock, err = sqlmock.New()
	}

	logged = false
}

func TestCleanNumber(t *testing.T) {
	if _, ok := CleanNumber("11", 3); ok {
		t.Errorf("Should check length")
	}
	if result, ok := CleanNumber("11", 2); !ok || result != "11" {
		t.Errorf("Unable to clean number %s", result)
	}
	if result, ok := CleanNumber("12-3", 3); !ok || result != "123" {
		t.Errorf("Unable to clean number %s", result)
	}
	if result, ok := CleanNumber("12.3", 3); !ok || result != "123" {
		t.Errorf("Unable to clean number %s", result)
	}
	if result, ok := CleanNumber("12,3", 3); !ok || result != "123" {
		t.Errorf("Unable to clean number %s", result)
	}
	if result, ok := CleanNumber("12 3", 3); !ok || result != "123" {
		t.Errorf("Unable to clean number %s", result)
	}
}

// Phone
//
func TestPhoneEmptyObjectName(t *testing.T) {
	phone := new(Phone)
	name := phone.String()

	if name != "Phone" {
		t.Errorf("Name of Phone object was %s", name)
	}
	if phone.Id() != 0 || phone.ok {
		t.Errorf("phone.Id is corrupt")
	}
}
func TestPhoneShortNumber(t *testing.T) {
	phone := NewPhone()
	phone.countryCode = "USA"
	phone.areaCode = "503"

	if _, ok := phone.GetNumber("123456"); ok {
		t.Errorf("%s should reject short numbers. %s", phone, phone.message)
	}

	if _, ok := phone.GetNumber("123-456"); ok {
		t.Errorf("%s should reject short numbers. %s", phone, phone.message)
	}

	if _, ok := phone.GetNumber("1234567"); !ok {
		t.Errorf("%s rejected valid number. %s", phone, phone.message)
	}

	if _, ok := phone.GetNumber("123-4567"); !ok {
		t.Errorf("%s rejected valid number with separater. %s", phone, phone.message)
	}
}

func TestPhoneGetNumberSignatures(t *testing.T) {
	phone := NewPhone()
	if _, ok := phone.GetNumberAreaCountry("1233567", "123", "USA"); !ok {
		t.Errorf("%s rejected valid number. %s", phone, phone.message)
	}

	phone = NewPhone()
	phone.countryCode = "USA"
	if _, ok := phone.GetNumberArea("1234567", "123"); !ok {
		t.Errorf("%s rejected valid number. %s", phone, phone.message)
	}
}

func TestPhoneNumberDb(t *testing.T) {
	phone := NewPhoneDb(db)
	phone.countryCode = "USA"
	phone.areaCode = "503"

	if mock != nil {
		mock.ExpectQuery("SELECT GetPhone").WillReturnRows(sqlmock.
			NewRows([]string{"getphone"}).AddRow(1001))
	}
	// Primary result is a unique database Id for the phone number
	if _, ok := phone.GetNumber("1234567"); ok && phone.id == nil {
		t.Errorf("%s was not inserted. %s", phone, phone.message)
	}

	if _, ok := phone.GetNumber("123-4567"); ok && phone.id == nil {
		t.Errorf("%s was not found. %s", phone, phone.message)
	}
	if phone.id != nil {
		//t.Logf("Got phone id %d for %s", *phone.id, *phone.numberRaw)
	} else {
		t.Error("Nil phone.id")
	}
	// Things that are abailable without going to the database again
	// phone.Id
	// phone.areaCode
	// phone.countryCode
	// phone.numberRaw
	// phone.language
	if phone.Id() == 0 {
		t.Errorf("id was nil")
	}
	if phone.Id() != *phone.id {
		t.Errorf("Id is returning pointer to id %d, not Id %d", phone.Id(), *phone.id)
	}

	// Things that will require another database access, now that we have a unique Id
	// phone.Number
	// phone.NumberInternational
	// Primary result is the latest/current representation of the phone number with the unique phone.Id
	if mock != nil {
		mock.ExpectQuery("SELECT local, international FROM").WillReturnRows(sqlmock.
			NewRows([]string{"local", "international"}).AddRow("503-123-4567", "011-1-503-123-4567"))
	}
	if phone.Number() == "" {
		t.Error("Phone number not retrieved from view")
	}
	if phone.NumberI() == "" {
		t.Errorf("International number not retrieved from view. %s", phone.message)
	}
	if phone.Number() != "" {
		//t.Logf("Local %s, Internatinal %s", phone.Number(), phone.NumberI())
	} else {
		t.Error("Empty response for phone.Number()")
	}

	name := phone.String()
	if name == "Phone" {
		t.Errorf("Stringer output was %s", name)
	}
}

// go test -v -bench=. -benchtime 1s
// ./business.test -test.v -test.bench=. -test.benchtime 1s
func BenchmarkPhoneDbSameNumber(b *testing.B) {
	phone := NewPhoneDb(db)
	phone.countryCode = "USA"
	phone.areaCode = "503"

	if mock != nil {
		mock.ExpectQuery("SELECT GetPhone").WillReturnRows(sqlmock.
			NewRows([]string{"getphone"}).AddRow(1001))
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		phone.GetNumber("1234567")
	}
}

func BenchmarkPhoneDbUniqueNumber(b *testing.B) {
	phone := NewPhoneDb(db)
	phone.countryCode = "USA"
	phone.areaCode = "503"

	if mock != nil {
		mock.ExpectQuery("SELECT GetPhone").WillReturnRows(sqlmock.
			NewRows([]string{"getphone"}).AddRow(1001))
		mock.ExpectQuery("SELECT local, international FROM").WillReturnRows(sqlmock.
			NewRows([]string{"local", "international"}).AddRow("503-123-4567", "011-1-503-123-4567"))
	}

	// fail outside of loop
	number := fmt.Sprintf("%07d", rand.Intn(10000000))
	var ok bool
	if _, ok = phone.GetNumber(number); ok && phone.id == nil {
		b.Errorf("%s was not found. %s", phone, phone.message)
	}
	if !ok {
		b.Fatalf("%s Got %s %s", number, phone.Number(), phone.message)
	}
	firstId := phone.Id()

	var result string
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		var r string
		for pb.Next() {
			number = fmt.Sprintf("%07d", rand.Intn(10000000))
			phone.GetNumber(number) // first db access
			r = phone.Number()      // second db access. Store so compiler will not eliminate this line
		}
		result = r // Be sure compiler will not to eliminate the benchmark itself
	})

	if !logged && !mockDatabase { // only log this once
		b.Logf("May need to execute\nDELETE FROM phone WHERE area = '%s' AND id >= %d;\nTo remove generated records.", phone.areaCode, firstId)
		logged = true
	}
}

// URL
// A simplification of Path
func TestURLEmpty(t *testing.T) {
	url := NewURL()
	if url.ok {
		t.Error("New object should not be okay")
	}

	name := url.String()
	if name != "URL" {
		t.Errorf("Name of URL object was %s", name)
	}

	if url.Id() != 0 {
		t.Error("Id is corrupt")
	}

	secure := false
	host := ""
	path := ""
	get := ""
	if _, ok := url.GetPathURL(secure, host, path, get); ok {
		t.Error("Did not rejected invalid URL")
	}
}

func TestURLDb(t *testing.T) {
	url := NewURLDb(db)

	// Existing record
	secure := false
	host := "www.IBM.com"
	path := ""
	get := ""

	if mock != nil {
		mock.ExpectQuery("SELECT GetURL").WillReturnRows(sqlmock.
			NewRows([]string{"getphone"}).AddRow(10))
	}

	// Primary result is a unique database Id for the URL
	if _, ok := url.GetPathURL(secure, host, path, get); ok && url.id == nil {
		t.Errorf("%s was not inserted. %s", url, url.message)
	}
	if url.Id() != 10 {
		t.Errorf("Proper id was not returned. %s", url.message)
	}

	if mock != nil {
		mock.ExpectQuery("SELECT GetURL").WillReturnRows(sqlmock.
			NewRows([]string{"getphone"}).AddRow(11))
		mock.ExpectQuery("SELECT value FROM URL").WillReturnRows(sqlmock.NewRows([]string{"value"}).AddRow("https://maps.Google.com/maps"))
	}

	// Possibly new record
	secure = true
	host = "maps.Google.com"
	path = "maps"
	if _, ok := url.GetPathURL(secure, host, path, get); ok && url.id == nil {
		t.Errorf("%s was not inserted. %s", url, url.message)
	}
	if url.Id() == 10 {
		t.Errorf("Proper id was not returned %d, %d. %s", *url.id, url.Id(), url.message)
	}

	// Things that will require another database access, now that we have a unique Id
	if url.Value() != "https://maps.Google.com/maps" {
		t.Errorf("Invalid value of %s. %s", url.Value(), url.message)
	}
}

func TestURLParsedDb(t *testing.T) {
	path := "http://bing.com/search?q=dotnet"

	urlDb := NewURLDb(db)
	parsedURL, err := url.Parse(path)
	if err != nil {
		t.Fatal(err)
	}

	if mock != nil {
		mock.ExpectQuery("SELECT GetURL").WillReturnRows(sqlmock.
			NewRows([]string{"getphone"}).AddRow(11))
		mock.ExpectQuery("SELECT value FROM URL").WillReturnRows(sqlmock.NewRows([]string{"value"}).AddRow(path))
	}

	if _, ok := urlDb.GetPathParsedURL(parsedURL); ok && urlDb.id == nil {
		t.Errorf("%s was not inserted. %s", urlDb, urlDb.message)
	}
	if urlDb.Id() == 10 {
		t.Errorf("Proper id was not returned %d, %d. %s", *urlDb.id, urlDb.Id(), urlDb.message)
	}

	// Things that will require another database access, now that we have a unique Id
	if urlDb.Value() != path {
		t.Errorf("Invalid value of %s. %s", urlDb.Value(), urlDb.message)
	}
}

// Session
func TestSessionAnonymous(t *testing.T) {
	// simulate uap result
	parsedAgentString := new(ParsedAgentString)
	parsedAgentString.UserAgent = &UserAgent{}
	parsedAgentString.Os = &Os{}
	parsedAgentString.Device = &Device{}

	userAgent := "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.130 Safari/537.36"
	parsedAgentString.UserAgent.Family = "Chrome"
	parsedAgentString.UserAgent.Major = "43"
	parsedAgentString.UserAgent.Minor = "0"
	parsedAgentString.UserAgent.Patch = "2357"
	parsedAgentString.Os.Family = "Linux"
	parsedAgentString.Device.Family = "Samsung SM-G900V"
	referer := "https://google.com/?go.fetch"
	remoteAddr := "192.168.0.112"

	if mock != nil {
		mock.ExpectQuery("SELECT AnonymousSession").WillReturnRows(sqlmock.
			NewRows([]string{"anonymoussession"}).AddRow(1))
	}

	session := NewSession(db)
	sessionId, ok := session.Anonymous(userAgent, parsedAgentString, referer, remoteAddr)
	if !ok || sessionId == 0 {
		t.Errorf("Anonymous session failed. %s", session.message)
	} else {
		//t.Logf("Session %d", sessionId)
	}
}
