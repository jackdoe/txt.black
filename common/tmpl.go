package common

import (
	"fmt"
	"time"
)

func FormatAsDate(t time.Time) string {
	year, month, day := t.Date()
	return fmt.Sprintf("%04d/%02d/%02d", year, month, day)
}

func InjectFuncMap(fm map[string]interface{}) {
	fm["formatAsDate"] = FormatAsDate
}
