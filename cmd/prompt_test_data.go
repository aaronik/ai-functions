package cmd

type PromptTestDatum struct {
	UserInput          string
	WantedFunctionName string
}

var PromptTestData = []PromptTestDatum{
	// easy
	{WantedFunctionName: "printz", UserInput: "list all open udp ports"},
	{WantedFunctionName: "printz", UserInput: "command to show the weather"},
	{WantedFunctionName: "printz", UserInput: "rename all files in the current directory to contain the word awesome"},
	{WantedFunctionName: "printz", UserInput: "list my subnet mask"},
	{WantedFunctionName: "printz", UserInput: "watch star wars in my terminal"},
	{WantedFunctionName: "printz", UserInput: "convert all jpg images in folder to png"},
	{WantedFunctionName: "printz", UserInput: "create a new user with sudo privileges"},
	{WantedFunctionName: "printz", UserInput: "set up a cron job to run a script every day at midnight"},
	{WantedFunctionName: "printz", UserInput: "cut a new git release called 1.0"},
	{WantedFunctionName: "printz", UserInput: "monitor CPU and memory usage and alert if too high"},
	{WantedFunctionName: "gen_image", UserInput: "generate an image of a cup of coffee"},
	{WantedFunctionName: "crawl_web", UserInput: "summarize reddit.com"},
	{WantedFunctionName: "crawl_web", UserInput: "what color do elephants tend to be?"},
	{WantedFunctionName: "crawl_web", UserInput: "what is the first headline from bbc.com?"},
	{WantedFunctionName: "crawl_web", UserInput: "What color is a penguin?"},
	{WantedFunctionName: "crawl_web", UserInput: "What color is a lion?"},
	{WantedFunctionName: "crawl_web", UserInput: "summarize the latest headline"},

	// // hard / ambiguous
	// {WantedFunctionName: "crawl_web", UserInput: "how many US presidents have there been up to 2023?"},
	// {WantedFunctionName: "printz", UserInput: "show the weather"},
	// {WantedFunctionName: "message", UserInput: "how many quarts are in a gallon"},
	// {WantedFunctionName: "message", UserInput: "please say hello, as a regular message response, not using any of the supplied tools"},
}
