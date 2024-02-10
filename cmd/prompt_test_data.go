package cmd

type PromptTestDatum struct {
	UserInput    string
	WantedFunctionName string
	ShouldBeMessage bool
}

var PromptTestData = []PromptTestDatum{
	// printz
	{UserInput: "list all open udp ports", WantedFunctionName: "printz"},
	{UserInput: "list all open ports", WantedFunctionName: "printz"},
	{UserInput: "rename all files in the current directory to contain the word awesome", WantedFunctionName: "printz"},
	{UserInput: "list my subnet mask", WantedFunctionName: "printz"},
	{UserInput: "curl command to show me the weather in my local region", WantedFunctionName: "printz"},
	{UserInput: "watch star wars in the terminal", WantedFunctionName: "printz"},
	{UserInput: "monitor CPU and memory usage and alert if too high", WantedFunctionName: "printz"}, // this one is 50/50 printz echo w/ 3.5 TODO
	{UserInput: "convert all jpg images in a folder to png", WantedFunctionName: "printz"},
	{UserInput: "create a new user with sudo privileges", WantedFunctionName: "printz"},
	{UserInput: "set up a cron job to run a script every day at midnight" , WantedFunctionName: "printz"},
	{UserInput: "cut a new git release called 1.0" , WantedFunctionName: "printz"},

	// echo
	{UserInput: "What color is an elephant?", WantedFunctionName: "echo"},
	{UserInput: "how many quarts are in a gallon", WantedFunctionName: "echo"},
	{UserInput: "how many US presidents have there been", WantedFunctionName: "echo"},
	{UserInput: "What color is a penguin?", WantedFunctionName: "echo"},
	{UserInput: "What color is a lion?", WantedFunctionName: "echo"},

	// gen_image
	{UserInput: "generate an image of a cup of coffee", WantedFunctionName: "gen_image"},

	// crawl_web
	{UserInput: "summarize reddit.com", WantedFunctionName: "crawl_web"},
	{UserInput: "what is the first headline from bbc.com?", WantedFunctionName: "crawl_web"},

	// message (this isn't technically a function name, but it fits into the mold and is explicitly checked for at test time)
	{ UserInput: "please respond in a regular message, not using any of the supplied tools", WantedFunctionName: "message" },
}
