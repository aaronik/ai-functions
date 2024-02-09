package cmd

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

/*************
This tests:
* Handling of responses in openai_responses.json
	* running assertions on output of above handling
* Prompt tests, assuring the prompt returned the expected function name
**************/

// TODO Test message responses
// TODO Test error responses
func TestPrimary(t *testing.T) {
	file, err := os.ReadFile("../openai_responses.json")
	if err != nil {
		log.Fatalf("unable to read file: %v", err)
	}

	var responses map[string]interface{}
	err = json.Unmarshal(file, &responses)
	if err != nil {
		log.Fatalf("unable to unmarshal json: %v", err)
	}

	// Json is shaped { userInput: response }
	for _, promptTestDatum := range PromptTestData {
		userInput := promptTestDatum.UserInput
		wantedFunctionName := promptTestDatum.WantedFunctionName
		shouldBeMessage := promptTestDatum.WantedFunctionName == "message"

		response, ok := responses[userInput]
		if !ok {
			t.Fatalf("response for saved user input in prompts.go file \"%s\" not found. Do you need to run `make hydrate?`", userInput)
		}

		jsonResponse, err := json.Marshal(response)
		if err != nil {
			panic(err)
		}

		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			w.Write(jsonResponse)
		}))

		defer server.Close()

		model := "gpt-3.5"
		systemContent := "definitely linux"

		// Fetch, type, marshal response
		resp, err := PerformPrimaryRequest(model, userInput, systemContent, server.URL)

		// Prompt test. Ensures all examples are giving the function names
		// we expect.
		// Messages are treated differently since they're not a function name.
		// The function names are gotten from actual openai responses hydrated via
		// `make hydrate`.
		if gotFunctionName := getToolcallFunctionName(*resp); gotFunctionName != "" {
			if gotFunctionName != wantedFunctionName {
				t.Errorf("Failed Prompt Test: \n"+
					"userInput: %v\n"+
					"want: %v\n"+
					"got: %v",
					userInput,
					gotFunctionName,
					wantedFunctionName,
				)
			}
		} else if shouldBeMessage {
			content := getMessageContent(*resp)
			if content == "" {
				t.Errorf("Failed Prompt Test: \n"+
					"userInput: %v\n"+
					"want: message\n"+
					"got: %v",
					userInput,
					getToolcallFunctionName(*resp),
				)
			}
		}

		var outputCatch bytes.Buffer

		// Put response through output system, sensitive to error codes
		HandlePrimaryResponse(*resp, &outputCatch)

		// Accumulate the terminal output
		output := outputCatch.String()

		// Ensure output starts with function name and one space, as sh script expects
		if !strings.HasPrefix(output, wantedFunctionName+" ") ||
			strings.HasPrefix(output, wantedFunctionName+"  ") {
			t.Error(
				"primary handler did not begin response with",
				wantedFunctionName,
				"followed by a single space:",
				output,
			)
		}
	}
}

func TestPrimary_Error(t *testing.T) {
	body, err := os.ReadFile("../json/error_response.json")
	if err != nil {
		t.Error("Test suite failed to import error_response.json")
	}

	var obj OpenAICompletionResponse
	if err := json.Unmarshal(body, &obj); err != nil {
		t.Error("Error json could not be unmarshalled into response type")
	}

	var outputCatch bytes.Buffer

	HandlePrimaryResponse(obj, &outputCatch)

	output := outputCatch.String()

	// Ensure output starts with error and one space, as sh script expects
	if !strings.HasPrefix(output, "error ") ||
		strings.HasPrefix(output, "error  ") {
		t.Error(
			"primary handler did not begin response with `error` followed by a single space:",
			output,
		)
	}
}
