function ai() {
  # Ensure deps are installed
  if ! $(which curl 1>/dev/null) || ! $(which jq 1>/dev/null) || [ -z "${OPENAI_API_KEY}" ] ; then
    echo 'requires `curl` and `jq`, and the OPENAI_API_KEY env var'
    false
    return
  fi

  # Bash commands need to be valid for the system they're run on
  local system_content="This system - uname -0: $(uname -o), uname -r: $(uname -r)."

  # Prompt
  local prompt="""
The user has input: '$@'.

If they are describing a shell command, call the supplied printz function,
NOT including newlines or escape characters, and NOT including any explanation of the command.

If the user asked for something that can be best answered with pure text, then call the echo function with your response.

If the user is requesting an image, call the gen_image function with JSON that best matches the request.
If the user requests the image is high quality, make the model dall-e-3, otherwise make it dall-e-2.
For the size parameter, default to 1024x1024, unless the user specifies they want a specific size. If they do,
  use the size that most accurately fits their request.
  dall-e-2 supports sizes: 256x256 (small), 512x512 (medium), or 1024x1024 (default/large).
  dall-e-3 supports sizes: 1024x1024 (default), 1024x1792 (portrait) or 1792x1024 (horizontal).
The JSON should adhere to the format: { json: {
  model: dall-e-2 or dall-e-3,
  prompt: the input supplied by the user,
  n: 1,
  size: 1024x1024
}}

For all requests, ONLY RESPOND IN VALID JSON.
"""

  # Append piped in content
  if ! [ -t 0 ]; then
    piped=$(cat -)
    prompt="$prompt Here is further context for this request: $piped"
  fi

  # Construct the JSON payload
  local json_payload=$(jq -n --arg system_content "$system_content" --arg prompt "$prompt" '{
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
            "required": ["command"]
          }
        }
      }
    ],
    "max_tokens": 503,
    "temperature": 0,
    "model": "gpt-4-1106-preview"
    # "model": "gpt-3.5-turbo"
  }')

  local response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --data "$json_payload" \
    https://api.openai.com/v1/chat/completions
  )

  # Filter out control characters
  response=$(echo "$response" | tr -d '\000-\037')

  # Which fn the model chose
  local function_name=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.name')

  # Guard for openai error response. Inform and return execution.
  if [ -z "$function_name" -o "$cmd" == "null" ] && [ -z "$arg" -o "$arg" == "null" ]; then
    echo
    echo "ERROR"
    echo "response:"
    echo "$response"
    echo "function_name: $function_name"
    echo "arg: $arg"
    false
    return
  fi

  # Perform the action
  if [ "$function_name" == "printz" ]; then
    local arg=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.arguments' | jq -r '.command')
    print -z "$arg"
  elif [ "$function_name" == "echo" ]; then
    local arg=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.arguments' | jq -r '.str')
    echo "$arg"
  elif [ "$function_name" == "gen_image" ]; then
    local json=$(echo $response | jq -r '.choices[0].message.tool_calls[0].function.arguments')
    # For some reason the model often includes invalid \" before and after { and }
    json=$(echo $json | sed 's/\"{/{/g' | sed 's/}\"/}/g' | jq -r '.json')
    echo "generating image with details: $json"
    local url=$(curl -s https://api.openai.com/v1/images/generations \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      --data "$json" | jq -r '.data[0].url')
    print -z "open '$url'"
  fi
}
