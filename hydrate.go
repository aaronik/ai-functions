//go:build ignore
// +build ignore

package main

import (
	"aaronik/ai/cmd"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
)

func main() {
	responseFileName := "openai_responses.json"

	var responsesJson map[string]interface{}
	responsesJson = make(map[string]interface{})

	model := os.Getenv("OPENAI_API_MODEL")

	// Iterate through each prompt, populating the json file for each response
	var wg sync.WaitGroup
	fmt.Println("hydrating...")
	for _, promptTestDatum := range cmd.PromptTestData {
		wg.Add(1)
		go func(promptTestDatum cmd.PromptTestDatum) {
			defer wg.Done()
			userInput := promptTestDatum.UserInput
			obj, err := cmd.PerformPrimaryRequest(model, userInput, "", "")
			fmt.Println("hydration complete for:", userInput)
			if err != nil {
				log.Fatal("Primary Request failed:", err)
			}
			responsesJson[userInput] = obj
		}(promptTestDatum)
	}
	wg.Wait()

	jsonData, err := json.MarshalIndent(responsesJson, "", "  ")
	if err != nil {
		panic(err)
	}

	writeFile, err := os.OpenFile(responseFileName, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0666)
	if err != nil {
		fmt.Println("Error opening file:", err)
		return
	}

	if _, err := writeFile.Write(jsonData); err != nil {
		panic(err)
	}
}
