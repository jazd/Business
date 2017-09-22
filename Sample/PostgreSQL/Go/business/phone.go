package business

import (
	"database/sql"
)

var PhoneErrors map[int][]string

func init() {
	// Just make PhoneErrors here until language to error mapping is official
	PhoneErrors = make(map[int][]string)
	PhoneErrors[1033] = append(PhoneErrors[1033], "Must set default country and area codes.")
	PhoneErrors[1033] = append(PhoneErrors[1033], "Invalid phone number or database.")
	PhoneErrors[1033] = append(PhoneErrors[1033], "No id returned from database.")
	PhoneErrors[1033] = append(PhoneErrors[1033], "Phones view error.")
}

type Phone struct {
	ok          bool
	language    int
	countryCode string
	areaCode    string
	message     string
	db          *sql.DB
	id          *uint64
	numberRaw   *string // Stripped number argument
	number      *string // not database Phone.number but the result of a composite field
	numberI     *string // composite number including international codes
}

func NewPhone() *Phone {
	phone := new(Phone)
	phone.language = 1033 // default english
	return phone
}

func NewPhoneDb(db *sql.DB) *Phone {
	phone := NewPhone()
	phone.db = db
	return phone
}

// Stringer
func (phone *Phone) String() string {
	if phone.numberI == nil {
		return "Phone"
	} else {
		return phone.NumberI()
	}
}

// Properties
func (phone *Phone) Id() uint64 {
	if phone.id == nil || !phone.ok {
		return 0
	} else {
		return *phone.id
	}
}
func (phone *Phone) Number() string {
	empty := ""
	if phone.number == nil {
		// retrieve from view
		phone.refresh()
	}

	if phone.number != nil {
		return *phone.number
	} else {
		return empty
	}
}
func (phone *Phone) NumberI() string {
	empty := ""
	if phone.numberI == nil {
		// retrieve from view
		phone.refresh()
	}

	if phone.numberI != nil {
		return *phone.numberI
	} else {
		return empty
	}
}

func (phone *Phone) GetNumberArea(number string, areaCode string) (*Phone, bool) {
	phone.areaCode = areaCode
	return phone.GetNumber(number)
}

func (phone *Phone) GetNumberAreaCountry(number string, areaCode string, countryCode string) (*Phone, bool) {
	phone.areaCode = areaCode
	phone.countryCode = countryCode
	return phone.GetNumber(number)
}

func (phone *Phone) GetNumber(number string) (*Phone, bool) {
	phone.ok = false
	phone.message = ""

	// Invalidate last refresh
	phone.number = nil
	phone.numberI = nil

	// must have default country and area code if number is 7 numbers long
	if phone.countryCode != "" && phone.areaCode != "" {
		if number, phone.ok = CleanNumber(number, 7); phone.ok && phone.db != nil {
			// be sure we can get the unique id for this number
			row := phone.db.QueryRow("SELECT GetPhone($1, $2, $3)", phone.countryCode, phone.areaCode, number)
			var id uint64
			if err := row.Scan(&id); err != nil {
				phone.message = PhoneErrors[phone.language][2] + " " + err.Error()
			} else {
				phone.id = &id
				phone.numberRaw = &number
				phone.ok = true
			}
		} else {
			phone.message = PhoneErrors[phone.language][1]
		}
	} else {
		phone.message = PhoneErrors[phone.language][0]
	}

	return phone, phone.ok
}

// Pickup current view of Phone.Id
func (phone *Phone) refresh() (ok bool) {
	ok = false
	if phone.id != nil && phone.db != nil {
		row := phone.db.QueryRow("SELECT local, international FROM phones WHERE phones.phone = $1", *phone.id)
		var local string
		var internatinal string
		if err := row.Scan(&local, &internatinal); err != nil {
			phone.message = PhoneErrors[phone.language][3] + " " + err.Error()
		} else {
			phone.number = &local
			phone.numberI = &internatinal
			ok = true
		}
	}
	return ok
}
