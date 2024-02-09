package cmd

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCrawlWeb(t *testing.T) {
	// This needs to be a crawl web response, which is just a completions response
	responseJson := `{
		"choices": [{
			"message": {
				"tool_calls": [{
					"function": {
						"name": "report_information",
						"arguments": "{\"str\": \"info\"}"
					}
				}]
			}
		}]
	}`

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(responseJson))
	}))

	defer server.Close()

	carryoverJson := `{"purpose": "do something", "url": "` + server.URL + `"}`

	resp, _ := CrawlWeb("gpt-3.5", carryoverJson, server.URL)
	HandleCrawlWebResponse(*resp)
}

// func TestGenImage_Sad(t *testing.T) {
// 	badJson := `{"n": 1, "model": "dall-e-2", "prompt": "bad banana"}`
// 	responseJson := `{"error": {"message": "bad json!"}}`

// 	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
// 		w.Header().Set("Content-Type", "application/json")
// 		w.WriteHeader(http.StatusOK)
// 		w.Write([]byte(responseJson))
// 	}))

// 	defer server.Close()

// 	resp := GenImage("model-doesnt-matter", badJson, server.URL)
// 	HandleGenImageResponse(resp)
// }
