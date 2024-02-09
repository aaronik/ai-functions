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

type CarryoverJson struct {
	N      int `json:"n"`
	Model  string `json:"model"`
	Size   string `json:"size"`
	Prompt string `json:"prompt"`
}

func buildGenImageRequest(carryoverJson string, model string) CarryoverJson {
	var params CarryoverJson
	if err := json.Unmarshal([]byte(carryoverJson), &params); err != nil {
		log.Fatalf("Error parsing JSON: %s", err)
	}

	// currently dall-e-3 only will do one at a time
	if params.Model == "dall-e-3" && params.N == 1 {
		fmt.Println("Using dall-e-3, which limits parallel requests to 1")
		params.N = 1
	}

	fmt.Printf(
		"Generating %d image(s) using [%s], size: [%s] with prompt: %s\n",
		params.N, params.Model, params.Size, params.Prompt,
	)

	return params
}

func GenImage(model string, carryoverJson string, url string) (*OpenAIImageGenerationResponse, error) {
	if url == "" {
		url = "https://api.openai.com/v1/images/generations"
	}

	genImageReqJson := buildGenImageRequest(carryoverJson, model)

	promptBytes, err := json.Marshal(genImageReqJson)
	if err != nil {
		return nil, err
	}

	// Create an HTTP request
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(promptBytes))
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

	var obj OpenAIImageGenerationResponse
	if err := json.Unmarshal(body, &obj); err != nil {
		return nil, err
	}

	return &obj, nil
}

func HandleGenImageResponse(resp OpenAIImageGenerationResponse) error {
	if err := getErrorMessageFromImgGenResp(resp); err != nil {
		return err
	}

	for _, datum := range *resp.Data {
		exec.Command("open", datum.Url).Start()
	}

	return nil
}
