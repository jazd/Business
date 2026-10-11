package business

// ExampleFill fills the notice template in Sample/SQL/Content/notice.sql.
// link with type url returns https://example.test/notice.
// count with type number returns 2.
// Any other name or type is skipped.
func ExampleFill(name, kind string) (string, bool) {
	switch {
	case name == "link" && kind == "url":
		return "https://example.test/notice", true
	case name == "count" && kind == "number":
		return "2", true
	default:
		return "", false
	}
}
