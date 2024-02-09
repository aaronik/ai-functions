/*
Copyright © 2024 Aaron Sullivan (@aaronik) <aar.sully@gmail.com>

*/
package cmd

import (
	"fmt"
	"log"
	"os"

	"github.com/spf13/cobra"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "ai",
	Short: "A general purpose AI CLI app",
	Long:  `Not meant to be called directly`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Error: requires a subcommand")
		os.Exit(1)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

var primaryCmd = &cobra.Command{
	Use:   "primary",
	Short: "Executes the primary AI function",
	Long:  `Not meant to be called directly`,
	Run: func(cmd *cobra.Command, args []string) {
		prompt, _ := cmd.Flags().GetString("prompt")
		model, _ := cmd.Flags().GetString("model")
		systemContent, _ := cmd.Flags().GetString("system_content")
		resp, primaryErr := PerformPrimaryRequest(model, prompt, systemContent, "")
		if primaryErr != nil {
			log.Fatalln("Received error performing primary request:", primaryErr)
		}
		HandlePrimaryResponse(*resp, os.Stdout)
	},
}

// TODO To test these in a basic way, let's just feed some jsonParams as I expect them
// into these commands
var crawlWebCmd = &cobra.Command{
	Use:   "crawl_web",
	Short: "Executes the web crawling AI function",
	Long:  `Not meant to be called directly`,
	Run: func(cmd *cobra.Command, args []string) {
		jsonParams, _ := cmd.Flags().GetString("jsonParams")
		model, _ := cmd.Flags().GetString("model")

		resp, err := CrawlWeb(model, jsonParams, "")
		if err != nil {
			log.Fatalln("Received error performing crawl web:", err)
		}

		handleErr := HandleCrawlWebResponse(*resp)
		if handleErr != nil {
			log.Fatalln("Received error during web crawl result handling:", handleErr)
		}
	},
}

var genImageCmd = &cobra.Command{
	Use:   "gen_image",
	Short: "Executes the image generation AI function",
	Long:  `Not meant to be called directly`,
	Run: func(cmd *cobra.Command, args []string) {
		jsonParams, _ := cmd.Flags().GetString("jsonParams")
		model, _ := cmd.Flags().GetString("model")

		resp, genErr := GenImage(model, jsonParams, "")
		if genErr != nil {
			log.Fatalln("Received error during image generation:", genErr)
		}

		handleErr := HandleGenImageResponse(*resp)
		if handleErr != nil {
			log.Fatalln("Received error during image handling:", handleErr)
		}
	},
}

func init() {
	rootCmd.AddCommand(primaryCmd)
	rootCmd.AddCommand(crawlWebCmd)
	rootCmd.AddCommand(genImageCmd)

	primaryCmd.Flags().String("prompt", "", "What the user enters, to be sent to openai in addition to hard coded tools")
	primaryCmd.Flags().String("model", "gpt-3.5-turbo-0125", "What model to use")
	primaryCmd.Flags().String("system_content", "", "Information about the system, used for printz")
	primaryCmd.MarkFlagRequired("prompt")
	primaryCmd.MarkFlagRequired("model")
	primaryCmd.MarkFlagRequired("system_content")

	crawlWebCmd.Flags().String("jsonParams", "", "What the user enters, to be sent to openai in addition to hard coded tools")
	crawlWebCmd.Flags().String("model", "gpt-3.5-turbo-0125", "What model to use")
	crawlWebCmd.MarkFlagRequired("jsonParams")
	crawlWebCmd.MarkFlagRequired("model")

	genImageCmd.Flags().String("jsonParams", "", "The model's image generation json")
	genImageCmd.MarkFlagRequired("jsonParams")
}
