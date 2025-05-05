package cmd

import (
	"encoding/json"
	"errors"
)

type OpenAICompletionResponse struct {
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
		Param   string `json:"param"`
		Code    string `json:"code"`
	} `json:"error"`
	ID      string `json:"id"`
	Object  string `json:"object"`
	Created int    `json:"created"`
	Model   string `json:"model"`
	Choices []struct {
		Index        int         `json:"index"`
		Logprobs     any `json:"logprobs,omitempty"`
		FinishReason string      `json:"finish_reason"`
		Message      struct {
			Content   *string `json:"content"`
			Role      string `json:"role"`
			ToolCalls *[]struct {
				Id       string `json:"id"`
				Type     string `json:"type"`
				Function struct {
					Name      string `json:"name"`      // TODO lock this down
					Arguments string `json:"arguments"` // TODO lock this down
				} `json:"function"`
			} `json:"tool_calls"`
		} `json:"message"`
	} `json:"choices"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage"`
}

type OpenAIImageGenerationResponse struct {
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
		Param   string `json:"param"`
		Code    string `json:"code"`
	} `json:"error"`
	ID      string `json:"id"`
	Object  string `json:"object"`
	Created int    `json:"created"`
	Model   string `json:"model"`
	Data    *[]struct {
		Url string `json:"url"`
	} `json:"data"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage"`
}

// Add this function to pretty print the response
func prettyPrint(i any) string {
	s, _ := json.MarshalIndent(i, "", "  ")
	return string(s)
}

// Pull the error message off a resp if there is any
func getError(resp OpenAICompletionResponse) error {
	if resp.Error != nil && resp.Error.Message != "" {
		return errors.New(resp.Error.Message)
	}

	return nil
}

// Pull the error message off a resp if there is any
func getErrorMessage(resp OpenAICompletionResponse) string {
	if resp.Error != nil && resp.Error.Message != "" {
		return resp.Error.Message
	}

	return ""
}

// Pull the error message off a resp if there is any
func getErrorMessageFromImgGenResp(resp OpenAIImageGenerationResponse) error {
	if resp.Error != nil && resp.Error.Message != "" {
		return errors.New(resp.Error.Message)
	}

	return nil
}

// Pull the Message content off a resp if there is any
func getMessageContent(resp OpenAICompletionResponse) string {
	if resp.Choices != nil && len(resp.Choices) > 0 && resp.Choices[0].Message.Content != nil && *resp.Choices[0].Message.Content != "" {
		return *resp.Choices[0].Message.Content
	}

	return ""
}

// Return the function arguments off a resp if there is any
func getToolcallArguments(resp OpenAICompletionResponse) string {
	if resp.Choices != nil && len(resp.Choices) > 0 && resp.Choices[0].Message.ToolCalls != nil && len(*resp.Choices[0].Message.ToolCalls) > 0 {
		return (*resp.Choices[0].Message.ToolCalls)[0].Function.Arguments
	} else {
		return ""
	}
}

// Return the function name off a resp if there is any
func getToolcallFunctionName(resp OpenAICompletionResponse) string {
	if resp.Choices != nil && len(resp.Choices) > 0 && resp.Choices[0].Message.ToolCalls != nil && len(*resp.Choices[0].Message.ToolCalls) > 0 {
		return (*resp.Choices[0].Message.ToolCalls)[0].Function.Name
	} else if content := getMessageContent(resp); content != "" {
		return "message"
	} else {
		return ""
	}
}
