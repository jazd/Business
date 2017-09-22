package business

import (
	"database/sql"
	"strings"
)

// Remove any formatting characters from a phone number string
// Like - , .
var numberCleaner = strings.NewReplacer(
	" ", "",
	"-", "",
	".", "",
	",", "")

func CleanNumber(number string, length int) (string, bool) {
	ok := false
	number = numberCleaner.Replace(number)
	ok = len(number) == length

	return number, ok
}

// Convert nil string pointers to NULL for database inserts
func NullableStringPointer(s *string) sql.NullString {
	if s == nil {
		return sql.NullString{}
	}
	return sql.NullString{
		String: *s,
		Valid:  true}
}

// Convert empty string to NULL for database inserts
func NullableString(s string) sql.NullString {
	if s == "" {
		return sql.NullString{}
	}
	return sql.NullString{
		String: s,
		Valid:  true}
}
