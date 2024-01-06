#!/usr/bin/env zsh

# Command to generate a bash command to do whatever you ask it.
# Usage: ai fetch ip address
# Requires OPENAI_API_KEY to be set
# Doc'd at https://gist.github.com/Aaronik/7d5a212f33a2815408a0c9a82470c7dd
# TODO `ai a bash function that has a nonzero exit code` consistently returns backticks
function ai() {
  local system_content="uname -0: $(uname -o), uname -r: $(uname -r)."
  local text="Write a bash command to $@. Return only the command, no other text. Do not describe what it is. Do not include quotes or back ticks in the answer. I want to copy/paste exactly what you return and run it directly in a terminal."

  # Append piped in content
  if ! [ -t 0 ]; then
    # If data is being piped in, read it
    piped=$(cat -)
  fi

  if [ -n "$piped" ] && [ "$piped" != '""' ]; then
    text="$text Here is further context for this request: $piped"
  fi

  # Construct the JSON payload
  local json_payload=$(jq -n --arg system_content "$system_content" --arg text "$text" '{
    "messages": [
      {"role": "system", "content": $system_content},
      {"role": "user", "content": $text}
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

  local completion=$(echo "$response" | jq -r '.choices[0].message.content')

  # Guard for openai error response. Inform and return execution.
  if [[ $completion == "null" || $completion == "" ]]; then
    echo "$response"
    false
    return
  fi

  print -z "$completion"
}
