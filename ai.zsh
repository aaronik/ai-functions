#!/usr/bin/env zsh

# Requires OPENAI_API_KEY to be set
function ai() {
  # Ensure deps are installed
  if ! $(which curl 1>/dev/null) || ! $(which jq 1>/dev/null) ; then
    echo 'requires `curl` and `jq`'
    false
    return
  fi

  local system_content="The system - uname -0: $(uname -o), uname -r: $(uname -r)."
  local text="The user has input: '$@'. If they are describing a shell command, call the supplied printz function, NOT including newlines or escape characters, and NOT including any explanation of the command. If the user asked for text, then call the echo command with your response. Only respond in valid json."

  # Append piped in content
  if ! [ -t 0 ]; then
    piped=$(cat -)
    text="$text Here is further context for this request: $piped"
  fi

  # Construct the JSON payload
  local json_payload=$(jq -n --arg system_content "$system_content" --arg text "$text" '{
    "messages": [
      {"role": "system", "content": $system_content},
      {"role": "user", "content": $text}
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
      }
    ],
    "max_tokens": 303,
    "temperature": 0,
    "model": "gpt-4-1106-preview"
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

  # What will be fed to the fn
  local arg=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.arguments' | jq -r '.str // .command')


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

  if [ "$function_name" == "printz" ]; then
    print -z "$arg"
  elif [ "$function_name" == "echo" ]; then
    echo "$arg"
  fi
}
