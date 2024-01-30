#!/usr/bin/env zsh

function ai() {
  # Ensure deps are installed
  if ! $(which curl jq mpg123 lynx 1>/dev/null) || [ -z "${OPENAI_API_KEY}" ] ; then
    echo "$0 requires \`curl\`, \`jq\`, \`lynx\`, and \`mpg123\` for audio output, and the OPENAI_API_KEY env var to be set"
    false
    return
  fi

  function sanitize_json() {
    local json="$1"
    json=$(echo "$json" | tr -d '\000-\037' | tr -d '\177-\377' | tr -d '\n')
    json=$(echo "$json" | jq -c .)

    # Check if jq was successful
    if [ $? -ne 0 ]; then
      echo "ERROR - Unable to parse JSON"
      echo $json
      false
      return
    fi

    echo "$json"
  }

  # Bash commands need to be valid for the system they're run on
  local system_content="This system - uname -s: $(uname -s), uname -r: $(uname -r)."

  # Prompt
  local prompt="""
    USER INPUT: '$@'
  """

  # Append piped in content
  # if ! [ -t 0 ]; then # commented b/c of difficulty in using `read` with tests using this way
  if [ -p /dev/stdin ]; then
    piped=$(cat -)
    prompt="$prompt\n\nADDITIONAL CONTEXT: $piped"
  fi

  model="${OPENAI_API_MODEL:-gpt-3.5-turbo-1106}"
  # model="${OPENAI_API_MODEL:-gpt-4-1106-preview}"

  # Construct the JSON payload
  local json_payload=$(jq -n \
    --arg system_content "$system_content" \
    --arg prompt "$prompt" \
    --arg model "$model" \
      '{
      "max_tokens": 703,
      "temperature": 0,
      "model": $model,
      "messages": [
        {"role": "system", "content": $system_content},
        {"role": "user", "content": $prompt},
        {"role": "user", "content": "only call a single function"}
      ],
      "tools": [
        {
          "type": "function",
          "function": {
            "name": "printz",
            "description": "printz(command: string) - DEFAULT - use this when the user is describing a shell command that isnt just echoing information. ex: printz(netstat -u), printz(lsof -n). Use the system content to ensure the command works on the current system. instead of printz(echo information), use the supplied echo function",
            "parameters": {
              "type": "object",
              "properties": {
                "command": {
                  "type": "string",
                  "description": "The bash command"
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
            "description": "echo(str: string) - use this if the user asked for information other than a bash command, or anything conversational. ex echo(There are 4 quarts in a gallon), echo(There have been 46 US presidents)",
            "parameters": {
              "type": "object",
              "properties": {
                "str": {
                  "type": "string",
                  "description": "The information"
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
            "description": "use this IF AND ONLY IF the user is EXPLICITLY requesting an image, with verbiage like Make me an image or Generate an image.",
            "parameters": {
              "type": "object",
              "properties": {
                "n": {
                  "type": "integer",
                  "description": "1, unless otherwise specified by user"
                },
                "model": {
                  "type": "string",
                  "description": "Default to dall-e-2. If the user has requested a high quality image, then dall-e-3"
                },
                "size": {
                  "type": "string",
                  "description": "default to 1024x1024 unless the user specifies they want a specific size. If they do, follow this guide:
                    dall-e-2 supports sizes: 256x256 (small), 512x512 (medium), or 1024x1024 (default/large).
                    dall-e-3 supports sizes: 1024x1024 (default), 1024x1792 (portrait) or 1792x1024 (landscape)."
                },
                "prompt": {
                  "type": "string",
                  "description": "What the user input, minus the parts about image quality, size, and portrait/landscape"
                }
              },
              "required": ["model", "size", "n", "prompt"]
            }
          }
        },
        {
          "type": "function",
          "function": {
            "name": "crawl_web",
            "description": "call this ONLY IF THE USER HAS EXPLICITLY REQUESTED TO CRAWL THE WEB, and supplied a URL to crawl. DO NOT CALL THIS IF THE USER HAS NOT SUPPLIED A URL, even if it will help respond accurately. Prefer echo and printz.",
            "parameters": {
              "type": "object",
              "properties": {
                "url": {
                  "type": "string",
                  "description": "The url the user has explicitly supplied to be crawled"
                },
                "purpose": {
                  "type": "string",
                  "description": "Repeat the request. Do not alter this."
                }
              },
              "required": ["url", "purpose"]
            }
          }
        },
        {
          "type": "function",
          "function": {
            "name": "text_to_speech",
            "description": "text_to_speech({ model: model, input: string, voice: voice }) - call this only if a user is explicitly asking you to say or speak something",
            "parameters": {
              "type": "object",
              "properties": {
                "model": {
                  "type": "string",
                  "description": "tts-1"
                },
                "input": {
                  "type": "string",
                  "description": "The user input, minus the parts about what model and voice to use."
                },
                "voice": {
                  "type": "string",
                  "description": "Default to onyx, unless there is a better match among:
                    **alloy** - calm, androgynous, friendly.
                    **echo** - factual, curt, male
                    **fable** - intellectual, British, androgynous
                    **onyx** - male, warm, smiling
                    **nova** - female, humorless, cool
                    **shimmer** - female, cool"
                }
              },
              "required": ["model", "input", "voice"]
            }
          }
        }
      ]
    }'
  )

  local response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    --data "$json_payload" \
    https://api.openai.com/v1/chat/completions)

  sanitized_response=$(sanitize_json "$response")

  # Crawl the web
  # This function takes one argument: an openai json response object
  # TODO This works alright for a single piece of information.
  # But there's no current way to aggregate all the info.
  # TODO Never visit the same page twice
  function crawl_web() {
    # $1 is a tool_call
    local args=$(echo "$1" | jq -r '.function.arguments')

    local url=$(echo $args | jq -r '.url')

    local history=$2

    if [ -z "$history" ]; then
      history="$url"
    else
      history="$history,$url"
    fi

    local original_purpose=$(echo $args | jq -r '.purpose')
    local prompt="USER REQUEST: $original_purpose"

    # TODO Ask it to get the important info.
    # Remove ads, remove special characters,
    # Remove similar links,
    local page=$(lynx -dump "$url")
    page_prompt="""
    CURRENT URL: $url

    HISTORY OF VISITED URLS:

    $history

    PAGE:

    $page
    """

    echo
    echo """
    crawling: $url
    purpose: $original_purpose
    history: $history
    """

    local json_payload=$(jq -n \
      --arg model "$model" \
      --arg prompt "$prompt" \
      --arg page_prompt "$page_prompt" \
      '{
        "max_tokens": 703,
        "temperature": 0,
        "model": $model,
        "messages": [
          {"role": "user", "content": $page_prompt},
          {"role": "user", "content": $prompt},
          {"role": "user", "content": "only call a single function, and prefer report_information."}
        ],
        tools: [
          # {
          #   "type": "function",
          #   "function": {
          #     "name": "crawl_web",
          #     "description": "call this only if you absolutely need more information from one of the provided links to fulfill the task.",
          #     "parameters": {
          #       "type": "object",
          #       "properties": {
          #         "url": {
          #           "type": "string",
          #           "description": "The link you need more information from.
          #           DO NOT call this with CURRENT URL, or any url from HISTORY.
          #           If a url is in the history, do not use it again, just summarize and call report_information."
          #         },
          #         "purpose": {
          #           "type": "string",
          #           "description": "The reason for visiting the url. Be detailed."
          #         }
          #       },
          #       "required": ["url", "purpose"]
          #     }
          #   }
          # },
          {
            "type": "function",
            "function": {
              "name": "report_information",
              "description": "DEFAULT - Report with the requested information.",
              "parameters": {
                "type": "object",
                "properties": {
                  "str": {
                    "type": "string",
                    "description": "Your response. Keep this brief."
                  }
                },
                "required": ["str"]
              }
            }
          }
        ]
      }'
    )

    local resp=$(curl -s https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      --data "$json_payload"
    )

    resp=$(sanitize_json "$resp")

    if message=$(echo $resp | jq -r '.choices[0].message.content') && [ -n "$message" ] && ! [ "$message" = "null" ]; then
      echo
      echo "$message"
    fi

    local tool_calls=$(echo "$resp" | jq -rc '.choices[0].message.tool_calls[]')

    # for tool_call in $tool_calls; do
    echo $tool_calls | while read -r tool_call; do
      local fn_name=$(echo "$tool_call" | jq -r '.function.name')

      if [ "$fn_name" = "crawl_web" ]; then
        crawl_web "$tool_call" "$history"

      elif [ "$fn_name" = "fulfill_request" ]; then
        echo
        echo "$tool_call" | jq -r '.function.arguments | fromjson | .str'

      else
        echo
        echo "got a weird response: $tool_call"
        echo "function_name: $fn_name"

      fi
    done

  }

  local tool_calls=$(echo "$sanitized_response" | jq -rc '.choices[0].message.tool_calls[]')
  echo $tool_calls | while read -r tool_call; do
    local function_name=$(echo "$tool_call" | jq -r '.function.name')

    # Check if the function name was extracted successfully
    if [ -z "$function_name" ]; then
      echo "ERROR - LLM returned error or invalid function call structure or json"
      echo $response
      false
      return
    fi

    # Output the function name
    [ "$AI_PRINT_FUNCTION_NAME_RESPONSE" = "1" ] && echo "$function_name"


    # Perform the action
    if [ "$function_name" = "printz" ]; then
      cmd=$(echo $tool_call | jq -r '.function.arguments | fromjson | .command')
      print -z "$cmd"

    elif [ "$function_name" = "echo" ]; then
      str=$(echo $tool_call | jq -r '.function.arguments | fromjson | .str')
      echo "\n$str"

    elif [ "$function_name" = "crawl_web" ]; then
      crawl_web "$(echo $tool_call | jq -r '')"

    elif [ "$function_name" = "gen_image" ]; then
      local json=$(echo $tool_call | jq -r '.function.arguments')

      local n=$(echo $json | jq -r '.n')
      local model=$(echo $json | jq -r '.model')
      local prompt=$(echo $json | jq -r '.prompt')

      echo "generating $n image(s) using: $model, with prompt: $prompt"

      local resp=$(curl -s https://api.openai.com/v1/images/generations \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        --data "$json" \
        | jq -c .
      )

      local data=$(echo "$resp" | jq -rc '.data[]')
      echo $data | while read -r datum; do
        local url=$(echo $datum | jq -r '.url')
        open "$url"
      done

    elif [ "$function_name" = "text_to_speech" ]; then
      local args=$(echo $tool_call | jq -r '.function.arguments')

      voice=$(echo $args | jq -r .voice)
      input=$(echo $args | jq -r .input)

      if [ -z "$voice" ] || [ -z "$input" ]; then
          echo "Error: LLM returned invalid json: $args"
      else
          echo "Generating audio using voice: $voice and input: $input"
      fi

      curl -s https://api.openai.com/v1/audio/speech \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$args" \
        | mpg123 - 2>/dev/null

    elif content=$(echo $sanitized_response | jq -r '.choices[0].message.content') && [ -n "$content" ]; then
      echo "$content"

    fi
  done

}
