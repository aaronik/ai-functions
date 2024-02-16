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

func TestPrimary(t *testing.T) {
	// read saved responses
	file, err := os.ReadFile("../openai_responses.json")
	if err != nil {
		log.Fatalf("unable to read file: %v", err)
	}

	var responses map[string]interface{}
	err = json.Unmarshal(file, &responses)
	if err != nil {
		log.Fatalf("unable to unmarshal json: %v", err)
	}

	// for each test case
	for _, promptTestDatum := range PromptTestData {
		// Json is shaped { userInput: response }
		userInput := promptTestDatum.UserInput
		wantedFunctionName := promptTestDatum.WantedFunctionName

		response, ok := responses[userInput]
		if !ok {
			t.Fatalf("response for saved user input in prompts.go file \"%s\" not found. Do you need to run `make hydrate?`", userInput)
		}

		jsonResponse, err := json.Marshal(response)
		if err != nil {
			panic(err)
		}

		// mock server
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			w.Write(jsonResponse)
		}))

		defer server.Close()

		model := "fake-model"
		systemContent := "Linux art76 6.5.0-15-generic #15~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Fri Jan 12 18:54:30 UTC 2 x86_64 x86_64 x86_64 GNU/Linux"

		resp, err := PerformPrimaryRequest(model, userInput, systemContent, server.URL)

		gotFunctionName := getToolcallFunctionName(*resp)

		var outputBuffer bytes.Buffer

		// Put response through output system, sensitive to error codes
		HandlePrimaryResponse(*resp, &outputBuffer)

		output := outputBuffer.String()

		// Prompt test. Ensures all examples are giving the function names
		// we expect.
		// The function names are gotten from actual openai responses hydrated via
		// `make hydrate`.
		if gotFunctionName != wantedFunctionName {
			t.Errorf("Failed Prompt Test:"+
				"\nwant: %v"+
				"\ngot: %v"+
				"\nuserInput: %v"+
				"\nresponse: %v",
				wantedFunctionName,
				gotFunctionName,
				userInput,
				output,
			)

			// If function name is wrong, single space check below won't work, so avoid it
			continue
		}

		// Ensure output starts with function name and one space, as sh script expects
		if !strings.HasPrefix(output, wantedFunctionName+" ") ||
			strings.HasPrefix(output, wantedFunctionName+"  ") {
			t.Errorf(
				"Output did not start with function name followed by a single space:"+
					"\noutput: %v",
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

	var outputBuffer bytes.Buffer

	HandlePrimaryResponse(obj, &outputBuffer)

	output := outputBuffer.String()

	// Ensure output starts with error and one space, as sh script expects
	if !strings.HasPrefix(output, "error ") ||
		strings.HasPrefix(output, "error  ") {
		t.Error(
			"primary handler did not begin response with `error` followed by a single space:",
			output,
		)
	}
}
