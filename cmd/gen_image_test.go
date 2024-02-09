package cmd

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGenImage_Happy(t *testing.T) {
	carryoverJson := `{"n": 1, "size": "1024x1024", "model": "dall-e-2", "prompt": "good banana"}`
	responseJson := `{"data": [{"url": "url.biz"}]}`

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(responseJson))
	}))

	defer server.Close()

	resp, _ := GenImage("gpt-3.5", carryoverJson, server.URL)
	HandleGenImageResponse(*resp)
}

func TestGenImage_Sad(t *testing.T) {
	badJson := `{"n": 1, "model": "dall-e-2", "prompt": "bad banana"}`
	responseJson := `{"error": {"message": "bad json!"}}`

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(responseJson))
	}))

	defer server.Close()

	resp, _ := GenImage("gpt-3.5", badJson, server.URL)
	var _ = HandleGenImageResponse(*resp)
}
