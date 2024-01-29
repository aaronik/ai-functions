#!/usr/bin/env zsh

function ai() {
  # Ensure deps are installed
  if ! $(which curl jq mpg123 lynx 1>/dev/null) || [ -z "${OPENAI_API_KEY}" ] ; then
    echo "$0 requires \`curl\`, \`jq\`, \`lynx\`, and \`mpg123\` for audio output, and the OPENAI_API_KEY env var to be set"
    false
    return
  fi

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
        {"role": "user", "content": $prompt}
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
            "description": "use this IF AND ONLY IF the user is EXPLICITLY requesting an image.",
            "parameters": {
              "type": "object",
              "properties": {
                "n": {
                  "type": "integer",
                  "description": "1"
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
            "description": "crawl_web({ url: string, purpose: string }) - call this only if the user has explicitly requested to crawl the web, and supplied a URL to crawl. Do not call this if the user has not supplied a url.",
            "parameters": {
              "type": "object",
              "properties": {
                "url": {
                  "type": "string",
                  "description": "The url the user has requested to be crawled"
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
    https://api.openai.com/v1/chat/completions \
    | jq -c .
  )

  # Filter out control characters (they trip up jq)
  # TODO I think this step is getting in the way of responses with quotes.
  response=$(echo "$response" | tr -d '\000-\037')

  # Which fn the model chose
  local function_name=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.name')

  [ "$AI_PRINT_FUNCTION_NAME_RESPONSE" = "1" ] && echo "$function_name"

  # Try to process the raw string, rather than treating it like json.
  # It's too much trouble to reliably extract it via jq. This way is, believe it or not, more reliable.
  # This shouldn't need to be done if the control characters issue is fixed,
  # allowing responses with quotes to come through properly.
  function raw_extract() {
    # arg here will be a highly escaped _almost json_ string.
    local arg=$(echo "$response" | jq -r '.choices[0].message.tool_calls[0].function.arguments')

    local start_pos=$1
    local end_offset=2
    local end_pos=$((${#arg}-end_offset))

    cmd=$(echo $arg | cut -c${start_pos}-${end_pos})

    echo "$cmd"
  }

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
          {"role": "user", "content": $prompt}
        ],
        tools: [
          {
            "type": "function",
            "function": {
              "name": "crawl_web",
              "description": "call this only if you absolutely need more information from one of the provided links to fulfill the task.",
              "parameters": {
                "type": "object",
                "properties": {
                  "url": {
                    "type": "string",
                    "description": "The link you need more information from.
                    DO NOT call this with CURRENT URL, or any url from HISTORY"
                  },
                  "purpose": {
                    "type": "string",
                    "description": "The reason for visiting the url. Be detailed."
                  }
                },
                "required": ["url", "purpose"]
              }
            }
          },
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
      --data "$json_payload" \
      | jq -c .
    )

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

  # Perform the action
  if [ "$function_name" = "printz" ]; then
    cmd=$(raw_extract 13)
    print -z "$cmd"

  elif [ "$function_name" = "echo" ]; then
    str=$(raw_extract 9)
    echo "\n$str"

  elif [ "$function_name" = "crawl_web" ]; then
    crawl_web "$(echo $response | jq -r '.choices[0].message.tool_calls[0]')"

  elif [ "$function_name" = "gen_image" ]; then
    local json=$(echo $response | jq -r '.choices[0].message.tool_calls[0].function.arguments')

    # Ask before generating image
    echo "generating image with details: $json"
    printf "continue? Y/n "
    read choice
    if [ "$choice" != "Y" ] && [ "$choice" != "" ]; then
      return
    fi

    local resp=$(curl -s https://api.openai.com/v1/images/generations \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      --data "$json" \
      | jq -c .
    )

    local url=$(echo $resp | jq -r '.data[0].url')

    print -z "open '$url'"

  elif [ "$function_name" = "text_to_speech" ]; then
    local args=$(echo $response | jq -r '.choices[0].message.tool_calls[0].function.arguments')

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

  elif content=$(echo $response | jq -r '.choices[0].message.content') && [ -n "$content" ]; then
    echo "$content"

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
