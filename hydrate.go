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

	var responsesJson map[string]any
	responsesJson = make(map[string]interface{})

	model := os.Getenv("OPENAI_API_MODEL")
	systemContent := "Linux art76 6.5.0-15-generic #15~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Fri Jan 12 18:54:30 UTC 2 x86_64 x86_64 x86_64 GNU/Linux"

	// Iterate through each prompt, populating the json file for each response
	var wg sync.WaitGroup
	fmt.Println("hydrating...")
	for _, promptTestDatum := range cmd.PromptTestData {
		wg.Add(1)
		go func(promptTestDatum cmd.PromptTestDatum) {
			defer wg.Done()
			userInput := promptTestDatum.UserInput
			obj, err := cmd.PerformPrimaryRequest(model, userInput, systemContent, "")
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
