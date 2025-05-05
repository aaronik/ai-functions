/*
TODO Rename primary to "coordinator"
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

func buildPrimaryPrompt(prompt string, model string, systemContent string) map[string]any {
	Data := map[string]any{
		"max_tokens":  703,
		"temperature": 0,
		"model":       model,

		"messages": []map[string]any{
			{"role": "user", "content": "User's system: " + systemContent},
			{"role": "user", "content": prompt},
			{"role": "system", "content": "You are a helpful command line based ai assistant program. Your job is to utilize the supplied tools to best respond to the user's requests."},
			{"role": "system", "content": "use printz to supply a bash or zsh command, if the user has asked for a command."},
			{"role": "system", "content": "use crawl_web for information you're otherwise unable to provide. Avoid crawl_web when possible."},
			{"role": "system", "content": "use gen_image only when explicitly asked for an image, like 'generate an image of ..', or 'make a high quality image of ..'."},
			// {"role": "user", "content": "only call a single function"},
		},

		"tools": []map[string]any{

			{
				"type": "function",
				"function": map[string]any{
					"name":        "printz",
					"description": "Use zsh's print -z to place the command on the command buffer. ex: printz(netstat -u), printz(lsof -n).",
					"parameters": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"command": map[string]any{
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
				"function": map[string]any{
					"name":        "gen_image",
					"description": "use this IF AND ONLY IF the user is EXPLICITLY requesting an image, with verbiage like Make me an image or Generate an image.",
					"parameters": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"n": map[string]any{
								"type":        "integer",
								"description": "1, unless otherwise specified by user",
							},
							"model": map[string]any{
								"type":        "string",
								"description": "Default to dall-e-2. If the user has requested a high quality image, then dall-e-3",
							},
							"size": map[string]any{
								"type":        "string",
								"description": "default to 1024x1024 unless the user specifies they want a specific size. If they specify a size, follow this guide: dall-e-2 supports sizes: 256x256 (small), 512x512 (medium), or 1024x1024 (default/large). dall-e-3 supports sizes: 1024x1024 (default), 1024x1792 (portrait) or 1792x1024 (landscape). If multiple images, all use the same size.",
							},
							"prompt": map[string]any{
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
				"function": map[string]any{
					"name":        "crawl_web",
					"description": "Crawl the web for more information.",
					"parameters": map[string]any{
						"type": "object",
						"properties": map[string]any{
							"url": map[string]any{
								"type":        "string",
								"description": "Fully qualified URL",
							},
							"purpose": map[string]any{
								"type":        "string",
								"description": "A detailed description of the user's needs.",
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

// // Commented to test using message instead of this
// {
// 	"type": "function",
// 	"function": map[string]any{
// 		"name":        "info",
// 		"description": "use this if the user asked for information which can not be represented as a bash one liner. ex info(There are 4 quarts in a gallon), info(There have been 46 US presidents). Do not call this with a bash one liner, do not provide a bash one liner with an explanation. If you have a response that's not perfect but is ok, use this.",
// 		"parameters": map[string]any{
// 			"type": "object",
// 			"properties": map[string]any{
// 				"str": map[string]any{
// 					"type":        "string",
// 					"description": "The information. NO BASH ONE LINERS. Never call like: info(To do such and such, use this command: <some command>)",
// 				},
// 			},
// 			"required": []string{"str"},
// 		},
// 	},
// },

// // This is for text to speech. It works fine, but ATTOW I'm thinking I don't need it, so I'm
// // going to leave it here for now.
// {
// 	"type": "function",
// 	"function": map[string]any{
// 		"name":        "text_to_speech",
// 		"description": "text_to_speech({ model: model, input: string, voice: voice }) - call this only if a user is explicitly asking you to say or speak something",
// 		"parameters": map[string]any{
// 			"type": "object",
// 			"properties": map[string]any{
// 				"model": map[string]any{
// 					"type":        "string",
// 					"description": "tts-1",
// 				},
// 				"input": map[string]any{
// 					"type":        "string",
// 					"description": "The user input, minus the parts about what model and voice to use.",
// 				},
// 				"voice": map[string]any{
// 					"type":        "string",
// 					"description": "Default to onyx, unless there is a better match among: **alloy** - calm, androgynous, friendly. **echo** - factual, curt, male **fable** - intellectual, British, androgynous **onyx** - male, warm, smiling **nova** - female, humorless, cool **shimmer** - female, cool",
// 				},
// 			},
// 			"required": []string{"model", "input", "voice"},
// 		},
// 	},
// },

// Fetch, type, marshal
func PerformPrimaryRequest(model string, userInput string, systemContent string, url string) (*OpenAICompletionResponse, error) {
	if url == "" {
		url = "https://api.openai.com/v1/chat/completions"
	}

	// payload
	prompt := buildPrimaryPrompt(userInput, model, systemContent)

	promptBytes, err := json.Marshal(prompt)
	if err != nil {
		return nil, err
	}

	// req
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(promptBytes))
	if err != nil {
		return nil, err
	}

	openaiApiKey := os.Getenv("OPENAI_API_KEY")
	req.Header.Add("Authorization", fmt.Sprintf("Bearer %s", openaiApiKey))
	req.Header.Add("Content-Type", "application/json")

	// send
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// receive
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	// resp
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

	functionName := getToolcallFunctionName(resp)
	toolCallArgs := getToolcallArguments(resp)

	if functionName == "" {
		fmt.Fprintln(w, "error finding function name")
		return
	}

	if toolCallArgs == "" && functionName != "message" {
		fmt.Fprintln(w, "error finding function arguments")
	}

	switch functionName {
	case "printz":
		type Command struct {
			Command string `json:"command"`
		}

		var commandObj Command
		json.Unmarshal([]byte(toolCallArgs), &commandObj)
		fmt.Fprintln(w, "printz", commandObj.Command)
	case "message":
		fmt.Fprintln(w, "message", getMessageContent(resp))
	case "info":
		type Str struct {
			Str string `json:"str"`
		}

		var strObj Str
		json.Unmarshal([]byte(toolCallArgs), &strObj)
		fmt.Fprintln(w, "info", strObj.Str)
	case "crawl_web":
		fmt.Fprintln(w, "crawl_web", toolCallArgs)
	case "gen_image":
		fmt.Fprintln(w, "gen_image", toolCallArgs)
	default:
		fmt.Fprintln(w, "[ !! ] Got an OpenAI response this tool doesn't understand [ !! ]")
		fmt.Fprintf(w, "%+v\n", prettyPrint(resp))
	}
}
