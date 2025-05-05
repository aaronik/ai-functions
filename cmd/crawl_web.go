/*
Copyright © 2024 Aaron Sullivan (@aaronik) <aar.sully@gmail.com>
*/

package cmd

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
)

func buildCrawlWebRequest(carryoverJson string, model string) map[string]any {
	type Json struct {
		Url     string `json:"url"`
		Purpose string `json:"purpose"`
	}
	var carryover Json
	if err := json.Unmarshal([]byte(carryoverJson), &carryover); err != nil {
		log.Fatalf("Error parsing JSON: %s", err)
	}
	url := carryover.Url
	purpose := carryover.Purpose

	fmt.Println("crawling:", url)
	fmt.Println("purpose:", purpose)

	// Get the page content using lynx
	// TODO This is hitting the web during unit tests
	cmd := exec.Command("lynx", "-dump", url)
	output, err := cmd.Output()
	if err != nil {
		fmt.Println("Error fetching page:", err)
		os.Exit(1)
	}
	page := string(output)

	Data := map[string]any{
		"max_tokens":  703,
		"temperature": 0,
		"model":       model,
		"messages": []map[string]any{
			{"role": "system", "content": "You are an information extraction system. You'll be given a parsed web page and a goal, usually to extract information from the parsed page. You should call report_information with the extracted information."},
			{"role": "user", "content": page},
			{"role": "system", "content": purpose},
			{"role": "user", "content": "only call a single tool/function once"},
		},
		"tools": []map[string]any{
			{
				"type": "function",
				"function": map[string]any{
					"name":        "report_information",
					"description": "DEFAULT - Report with the requested information.",
					"parameters": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"str": map[string]any{
								"type":        "string",
								"description": "The information the user is looking for from the supplied web page.",
							},
						},
						"required": []string{"str"},
					},
				},
			},
		},
	}

	return Data
}

func CrawlWeb(model string, carryoverJson string, openaiUrl string) (*OpenAICompletionResponse, error) {
	if openaiUrl == "" {
		openaiUrl = "https://api.openai.com/v1/chat/completions"
	}

	prompt := buildCrawlWebRequest(carryoverJson, model)

	promptBytes, err := json.Marshal(prompt)
	if err != nil {
		return nil, err
	}

	// Create an HTTP request
	req, err := http.NewRequest("POST", openaiUrl, bytes.NewBuffer(promptBytes))
	if err != nil {
		return nil, err
	}

	openaiApiKey := os.Getenv("OPENAI_API_KEY")
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", openaiApiKey))
	req.Header.Add("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var obj OpenAICompletionResponse
	if err := json.Unmarshal(body, &obj); err != nil {
		return nil, err
	}

	return &obj, nil
}

func HandleCrawlWebResponse(resp OpenAICompletionResponse) error {
	if err := getError(resp); err != nil {
		return err
	}

	if message := getMessageContent(resp); message != "" {
		fmt.Println(message)
		return nil
	}

	args := getToolcallArguments(resp)

	// If we've made it this far, there should be function arguments
	if args == "" {
		log.Fatalln("No function arguments found")

	}

	var argsStruct struct {
		Str string `json:"str"`
	}

	if err := json.Unmarshal([]byte(args), &argsStruct); err != nil {
		return err
	}

	// Tell the user of what the AI found
	fmt.Println(argsStruct.Str)

	return nil
}
