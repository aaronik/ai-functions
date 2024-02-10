/*
Copyright © 2024 Aaron Sullivan (@aaronik) <aar.sully@gmail.com>
*/

package cmd

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

func buildPrimaryPrompt(prompt string, model string, systemContent string) map[string]interface{} {
	Data := map[string]interface{}{
		"max_tokens":  703,
		"temperature": 0,
		"model":       model,
		"messages": []map[string]interface{}{
			{"role": "system", "content": systemContent},
			{"role": "user", "content": prompt},
			{"role": "user", "content": "only call a single function"},
		},
		"tools": []map[string]interface{}{
			{
				"type": "function",
				"function": map[string]interface{}{
					"name":        "printz",
					"description": "DEFAULT - use this when the user is describing what could be supplied as a bash one liner. ex: printz(netstat -u), printz(lsof -n). Ensure command works for the supplied system. No explanations need be provided.",
					"parameters": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"command": map[string]interface{}{
								"type":        "string",
								"description": "The bash one liner",
							},
						},
						"required": []string{"command"},
					},
				},
			},
			{
				"type": "function",
				"function": map[string]interface{}{
					"name":        "echo",
					"description": "use this if the user asked for information which can not be represented as a bash one liner. ex echo(There are 4 quarts in a gallon), echo(There have been 46 US presidents). Do not call this with a bash one liner, do not provide a bash one liner with an explanation. If you have a response that's not perfect but is ok, use this.",
					"parameters": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"str": map[string]interface{}{
								"type":        "string",
								"description": "The information. NO BASH ONE LINERS. Never call like: echo(To do such and such, use this command: <some command>)",
							},
						},
						"required": []string{"str"},
					},
				},
			},
			{
				"type": "function",
				"function": map[string]interface{}{
					"name":        "gen_image",
					"description": "use this IF AND ONLY IF the user is EXPLICITLY requesting an image, with verbiage like Make me an image or Generate an image.",
					"parameters": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"n": map[string]interface{}{
								"type":        "integer",
								"description": "1, unless otherwise specified by user",
							},
							"model": map[string]interface{}{
								"type":        "string",
								"description": "Default to dall-e-2. If the user has requested a high quality image, then dall-e-3",
							},
							"size": map[string]interface{}{
								"type":        "string",
								"description": "default to 1024x1024 unless the user specifies they want a specific size. If they specify a size, follow this guide: dall-e-2 supports sizes: 256x256 (small), 512x512 (medium), or 1024x1024 (default/large). dall-e-3 supports sizes: 1024x1024 (default), 1024x1792 (portrait) or 1792x1024 (landscape). If multiple images, all use the same size.",
							},
							"prompt": map[string]interface{}{
								"type":        "string",
								"description": "What the user input, minus the parts about image quality, size, and portrait/landscape",
							},
						},
						"required": []string{"n", "model", "size", "prompt"},
					},
				},
			},
			{
				"type": "function",
				"function": map[string]interface{}{
					"name":        "crawl_web",
					"description": "call this ONLY IF THE USER HAS EXPLICITLY REQUESTED TO CRAWL THE WEB, and supplied a URL to crawl. DO NOT CALL THIS IF THE USER HAS NOT SUPPLIED A URL, even if it will help respond accurately. Prefer echo and printz.",
					"parameters": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"url": map[string]interface{}{
								"type":        "string",
								"description": "The url the user has explicitly supplied to be crawled",
							},
							"purpose": map[string]interface{}{
								"type":        "string",
								"description": "Repeat the user input. Do not alter this.",
							},
						},
						"required": []string{"url", "purpose"},
					},
				},
			},
		},
	}

	return Data
}

// // This is for text to speech. It works fine, but ATTOW I'm thinking I don't need it, so I'm
// // going to leave it here for now.
// {
// 	"type": "function",
// 	"function": map[string]interface{}{
// 		"name":        "text_to_speech",
// 		"description": "text_to_speech({ model: model, input: string, voice: voice }) - call this only if a user is explicitly asking you to say or speak something",
// 		"parameters": map[string]interface{}{
// 			"type": "object",
// 			"properties": map[string]interface{}{
// 				"model": map[string]interface{}{
// 					"type":        "string",
// 					"description": "tts-1",
// 				},
// 				"input": map[string]interface{}{
// 					"type":        "string",
// 					"description": "The user input, minus the parts about what model and voice to use.",
// 				},
// 				"voice": map[string]interface{}{
// 					"type":        "string",
// 					"description": "Default to onyx, unless there is a better match among: **alloy** - calm, androgynous, friendly. **echo** - factual, curt, male **fable** - intellectual, British, androgynous **onyx** - male, warm, smiling **nova** - female, humorless, cool **shimmer** - female, cool",
// 				},
// 			},
// 			"required": []string{"model", "input", "voice"},
// 		},
// 	},
// },

func PerformPrimaryRequest(model string, userInput string, systemContent string, url string) (*OpenAICompletionResponse, error) {
	if url == "" {
		url = "https://api.openai.com/v1/chat/completions"
	}

	prompt := buildPrimaryPrompt(userInput, model, systemContent)

	promptBytes, err := json.Marshal(prompt)
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

	var obj OpenAICompletionResponse
	if err := json.Unmarshal(body, &obj); err != nil {
		return nil, err
	}

	return &obj, nil
}

// Performs all the logging to stdout for a primary response
func HandlePrimaryResponse(resp OpenAICompletionResponse, w io.Writer) {
	if errMessage := getErrorMessage(resp); errMessage != "" {
		fmt.Fprintln(w, "error", errMessage)
		return
	}

	if message := getMessageContent(resp); message != "" {
		fmt.Fprintln(w, "message", message)
		return
	}

	functionName := getToolcallFunctionName(resp)
	toolCallArgs := getToolcallArguments(resp)

	if functionName == "" || toolCallArgs == "" {
		fmt.Fprintln(w, "error finding function information")
	}

	switch functionName {
	case "printz":
		type Command struct {
			Command string `json:"command"`
		}

		var commandObj Command
		json.Unmarshal([]byte(toolCallArgs), &commandObj)
		fmt.Fprintln(w, "printz", commandObj.Command)
	case "echo":
		type Str struct {
			Str string `json:"str"`
		}

		var strObj Str
		json.Unmarshal([]byte(toolCallArgs), &strObj)
		fmt.Fprintln(w, "echo", strObj.Str)
	case "crawl_web":
		fmt.Fprintln(w, "crawl_web", toolCallArgs)
	case "gen_image":
		fmt.Fprintln(w, "gen_image", toolCallArgs)
	default:
		fmt.Fprintln(w, "[ !! ] Got an OpenAI response this tool doesn't understand [ !! ]")
		fmt.Fprintf(w, "%+v\n", prettyPrint(resp))
	}
}
