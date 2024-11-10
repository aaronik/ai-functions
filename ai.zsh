#!/usr/bin/env zsh

function ai() {
  # This needs to be zsh for `type ai` and `print -z`
  if ! ps -p $$ | grep zsh >/dev/null; then
    echo 'Sorry, ai needs to be run from zsh due to differences in the `type` and `print` shell commands.'
    false
    return
  fi

  local app_dir=$(dirname $(type ai | awk '{print $NF}'))

  # Ensure deps are installed
  if ! $(which go lynx 1>/dev/null) || [ -z "${OPENAI_API_KEY}" ] ; then
    echo "$0 requires \`go\` and \`lynx\`, and the OPENAI_API_KEY env var to be set"
    echo "Install go:         https://go.dev/doc/install"
    echo "Install lynx:       \`brew install lynx\` OR \`sudo apt install lynx\`"
    echo "Set OPENAI_API_KEY: echo \"export OPENAI_API_KEY=<your key here>\" > ~/.zshrc"
    false
    return
  fi

  # Bash commands need to be valid for the system they're run on
  local system_content="$(uname -a)"

  # Prompt
  local prompt="""
    USER INPUT: '$@'
  """

  # Append piped in content
  if [ -p /dev/stdin ]; then
    piped=$(cat -)
    prompt="$prompt\n\nADDITIONAL CONTEXT: $piped"
  fi

  model="${OPENAI_API_MODEL:-gpt-4o-mini}"
  # model="${OPENAI_API_MODEL:-gpt-4o}"

  # Our response is whatever the go app prints to stdout running its 'primary'
  # subcommand. This makes debugging the go app a bit tricky. Easiest to log in
  # the go tests or echoing resp here.
  resp=$(cd $app_dir; go run main.go primary --model "$model"  --system_content "$system_content" --prompt "$prompt"2>&1)
  if ! [ "$?" = "0" ]; then
    echo "initial call to openai failure: $resp" >&2
    false
    return
  fi

  # Look weird? In order to make sure we can print -z to the command buffer, we
  # break apart the process of request / handle, so we can put things that take
  # a single step onto the output, and those that will be more verbose over
  # multiple steps, to print themselves from the go app.
  if [[ $resp == printz\ * ]]; then
    print -z "${resp:7}"
  elif [[ $resp == info\ * ]]; then
    echo "${resp:5}"
  elif [[ $resp == crawl_web\ * ]]; then
    (cd $app_dir; go run main.go crawl_web --model "$model" --jsonParams "${resp:10}")
  elif [[ $resp == gen_image\ * ]]; then
    (cd $app_dir; go run main.go gen_image --jsonParams "${resp:10}")
  elif [[ $resp == message\ * ]]; then
    echo "${resp:8}"
  elif [[ $resp == error\ * ]]; then
    echo "${resp:6}" >&2
    false
  else
    echo "$0 errored - received unexpected response from go app: $resp" >&2
    false
  fi
}
