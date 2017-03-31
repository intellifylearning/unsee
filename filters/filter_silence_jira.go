package filters

import (
	"fmt"
	"strings"

	"github.com/cloudflare/unsee/models"
	"github.com/cloudflare/unsee/store"
)

type silenceJiraFilter struct {
	alertFilter
}

func (filter *silenceJiraFilter) Match(alert *models.UnseeAlert, matches int) bool {
	if filter.IsValid {
		var isMatch bool
		if alert.Silenced > 0 {
			silence := store.Store.GetSilence(alert.Silenced)
			if silence != nil {
				isMatch = filter.Matcher.Compare(silence.JiraID, filter.Value)
			}
		} else {
			isMatch = filter.Matcher.Compare("", filter.Value)
		}
		if isMatch {
			filter.Hits++
		}
		return isMatch
	}
	e := fmt.Sprintf("Match() called on invalid filter %#v", filter)
	panic(e)
}

func newSilenceJiraFilter() FilterT {
	f := silenceJiraFilter{}
	return &f
}

func sinceJiraIDAutocomplete(name string, operators []string, alerts []models.UnseeAlert) []models.UnseeAutocomplete {
	tokens := map[string]models.UnseeAutocomplete{}
	for _, alert := range alerts {
		if alert.Silenced > 0 {
			silence := store.Store.GetSilence(alert.Silenced)
			if silence != nil && silence.JiraID != "" {
				for _, operator := range operators {
					token := fmt.Sprintf("%s%s%s", name, operator, silence.JiraID)
					tokens[token] = makeAC(token, []string{
						name,
						strings.TrimPrefix(name, "@"),
						fmt.Sprintf("%s%s", name, operator),
						silence.JiraID,
					})
				}
			}
		}
	}
	acData := []models.UnseeAutocomplete{}
	for _, token := range tokens {
		acData = append(acData, token)
	}
	return acData
}
