#!/usr/bin/env zsh

# TODO
# * Test
#   * ai list my subnet mask on 3.5 consistently borks
#   * Set up prompt testing (good if there's no error?)
#   * ai rename all files to include the word awesome consistently borks b/c soft quotes are included

function ai() {
  # Ensure deps are installed
  if ! $(which curl jq mpg123 1>/dev/null) || [ -z "${OPENAI_API_KEY}" ] ; then
    echo "$0 requires \`curl\`, \`jq\`, and \`mpg123\` for audio output, and the OPENAI_API_KEY env var to be set"
    false
    return
  fi

  # Bash commands need to be valid for the system they're run on
  local system_content="This system - uname -s: $(uname -s), uname -r: $(uname -r)."

  # Prompt
  local prompt="""
    USER INPUT: '$@'

    COMMANDS:

    * printz(command: string) - DEFAULT - use this when the user is describing a shell command.
    However, NEVER call printz with an echo command.
    ex: printz(ifconfig | grep -oP \'inet addr:\K\d+.\d+.\d+.\d+\')

    * echo(str: string) - use this if the user asked for something that can be best answered with text.
    Use this if you're supplying information to the user, and it doesn't need to be run as a command.
    ex: echo('There are 4 quarts in a gallon')

    * gen_image({ json: { model: String, prompt: String, n: 1, size: SizeString }}) - use this only if the user
    is explicitly requesting an image, like 'make an image of something or other'. Do not use this
    just because the user mentioned something that could be in an image.
      - model: If the user requests the image to be high quality, use dall-e-3, otherwise dall-e-2.
      - size: default to 1024x1024, unless the user specifies they want a specific size. If they do,
        follow this guide:
          dall-e-2 supports sizes: 256x256 (small), 512x512 (medium), or 1024x1024 (default/large).
          dall-e-3 supports sizes: 1024x1024 (default), 1024x1792 (portrait) or 1792x1024 (landscape).
      - prompt: What the user input, minus the parts about image quality, size, and portrait/landscape.
      - n: 1

    * text_to_speech({ json: { model: Model, input: String, voice: Voice }}) - if a user is asking you to
      say or speak something, call this, with:
      - model: tts-1
      - input: The user input, minus the parts about what model and voice to use.
      - voice: Defaulting to onyx, but using, if requested:
        - alloy - calm, androgynous, friendly
        - echo - factual, curt, male
        - fable - intellectual, British, androgynous
        - onyx - male, warm, smiling - DEFAULT
        - nova - female, humorless, cool
        - shimmer - female, cool
  """

  # Append piped in content
  if ! [ -t 0 ]; then
    piped=$(cat -)
    prompt="$prompt\n\nADDITIONAL CONTEXT: $piped"
  fi

  # Construct the JSON payload
  local json_payload=$(jq -n --arg system_content "$system_content" --arg prompt "$prompt" '{
    "max_tokens": 503,
    "temperature": 0,
    "response_format": { "type": "json_object" },
    "model": "gpt-4-1106-preview",
    # "model": "gpt-3.5-turbo-1106",
    "messages": [
      {"role": "system", "content": $system_content},
      {"role": "user", "content": $prompt}
    ],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "printz",
          "description": "Write a bash one liner to the command buffer",
          "parameters": {
            "type": "object",
            "properties": {
              "command": {
                "type": "string",
                "description": "The bash one liner that will be sent to the command buffer."
              }
            },
            "required": ["command"]
          }
        }
      },
      {
        "type": "function",
        "function": {
          "name": "echo",
          "description": "echo the response to the terminal",
          "parameters": {
            "type": "object",
            "properties": {
              "str": {
                "type": "string",
                "description": "The string that will be echoed to the terminal"
              }
            },
            "required": ["str"]
          }
        }
      },
      {
        "type": "function",
        "function": {
          "name": "gen_image",
          "description": "Send JSON to OpenAI image generation endpoint",
          "parameters": {
            "type": "object",
            "properties": {
              "json": {
                "type": "string",
                "description": "Valid JSON for the OpenAI image generation endpoint"
              }
            },
            "required": ["json"]
          }
        }
      },
      {
        "type": "function",
        "function": {
          "name": "text_to_speech",
          "description": "Send valid text to speech JSON to the OpenAI text to speech endpoint",
          "parameters": {
            "type": "object",
            "properties": {
              "json": {
                "type": "string",
                "description": "Valid JSON for the OpenaAI text to speech endpoint"
              }
            },
            "required": ["json"]
          }
        }
      }
    ]
  }')

  local response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --data "$json_payload" \
    https://api.openai.com/v1/chat/completions
  )

  # Filter out control characters (they trip up jq)
  # TODO I think this step is getting in the way of responses with quotes.
  response=$(echo "$response" | tr -d '\000-\037')

  # Which fn the model chose
  local function_name=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.name')

  # Perform the action
  if [ "$function_name" = "printz" ]; then
    local arg=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.arguments' | jq -r '.command')
    print -z "$arg"

  elif [ "$function_name" = "echo" ]; then
    local arg=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.arguments' | jq -r '.str')
    echo "$arg"

  elif [ "$function_name" = "gen_image" ]; then
    local json=$(echo $response | jq -r '.choices[0].message.tool_calls[0].function.arguments')
    # For some reason the model often includes invalid \" before and after { and }
    json=$(echo $json | sed 's/\"{/{/g' | sed 's/}\"/}/g' | jq -r '.json')

    echo "generating image with details: $json"

    # Ask before generating image
    printf "continue? Y/n "
    read choice
    if [ "$choice" != "Y" ] && [ "$choice" != "" ]; then
      echo "choice: $choice"
      return
    fi

    local url=$(curl -s https://api.openai.com/v1/images/generations \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      --data "$json" | jq -r '.data[0].url')
    print -z "open '$url'"

  elif [ "$function_name" = "text_to_speech" ]; then
    local json=$(echo $response | jq -r '.choices[0].message.tool_calls[0].function.arguments')
    # For some reason the model often includes invalid \" before and after { and }
    json=$(echo $json | sed 's/\"{/{/g' | sed 's/}\"/}/g' | jq -r '.json')

    voice=$(echo $json | jq -r .voice)
    input=$(echo $json | jq -r .input)

    if [ -z "$voice" ] || [ -z "$input" ]; then
        echo "Error: LLM returned invalid json: $json"
    else
        echo "Generating audio using voice: $voice and input: $input"
    fi

    curl -s https://api.openai.com/v1/audio/speech \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$json" \
      | mpg123 - 2>/dev/null

  else
    echo "ERROR - LLM returned error or invalid function call structure or json"
    echo "function_name: $function_name"
    echo "arg: $arg"
    echo
    echo "openai response:"
    echo "$response"
    false
  fi

}
