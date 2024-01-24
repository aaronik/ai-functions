# shellcheck disable=SC2317 # unreachable command when setting up mocks

function function_exists() {
  type "$1" >/dev/null 2>&1
}

Describe 'The test environment itself'
  It 'has OPENAI_API_MODEL set to 3.5'
    When call echo "$OPENAI_API_MODEL"
    The output should eq "gpt-3.5-turbo-1106"
  End

  Include ./ai.zsh

  It 'has ai available to call'
    When call type ai
    The status should be success
    The output should equal "ai is a shell function from ./ai.zsh"
  End
End

Describe 'With known responses'
  Include ./ai.zsh

  It 'populates the cli'
    # if print is called without -z or with the wrong command, this errors and the test fails
    print() {
      [ "$1" = "-z" ] && [ "$2" = "netstat -tuln" ]
    }

    curl() {
      echo '{"id":"chatcmpl-8ke56lXgPHCQa6RgrwEZHiiKspf3e","object":"chat.completion","created":1706127852,"model":"gpt-3.5-turbo-1106","choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_I2KCCqMN2cZkODrs7UtUTjgx","type":"function","function":{"name":"printz","arguments":"{\"command\":\"netstat -tuln\"}"}}]},"logprobs":null,"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":728,"completion_tokens":19,"total_tokens":747},"system_fingerprint":"fp_aaa20cc2ba"}'
    }

    When call ai list all open ports
    The status should be success
  End

  It 'echoes'
    curl() {
      echo '{"id":"chatcmpl-8keAIrZbNUGhLsW7ONNUmIfKUkOwQ","object":"chat.completion","created":1706128174,"model":"gpt-4-1106-preview","choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_HlFBMZfERkgSTADCrgrYrybd","type":"function","function":{"name":"echo","arguments":"{\"str\":\"Elephants are usually gray in color.\"}"}}]},"logprobs":null,"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":730,"completion_tokens":20,"total_tokens":750},"system_fingerprint":"fp_f71eafccde"}'
    }

    When call ai "what color is an elephant usually?"
    The status should be success
    The output should equal "
Elephants are usually gray in color."
  End

  It 'generates images'
    curl() {
      if [[ "$*" == *"chat/completions"* ]]; then
        echo '{"id":"chatcmpl-8keEGMO32jwb5Hd5tWpxIFsfyhIbD","object":"chat.completion","created":1706128420,"model":"gpt-4-1106-preview","choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_jiQkKZFpNbgrO6vWWRgNgkU2","type":"function","function":{"name":"gen_image","arguments":"{\"model\":\"dall-e-2\",\"prompt\":\"a cow\",\"n\":1,\"size\":\"1024x1024\"}"}}]},"logprobs":null,"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":730,"completion_tokens":35,"total_tokens":765},"system_fingerprint":"fp_de93422283"}'

      elif [[ "$*" == *"images/generations"* ]]; then
        echo '{"created":1706129930,"data":[{"url":"image.biz"}]}'
      fi
    }

    print() {
      [ "$1" = "-z" ] && [ "$2" = "open 'image.biz'" ]
    }

    Data "Y"

    When call ai "Generate an image of a cow"
    The status should be success
    The output should include '{"model":"dall-e-2","prompt":"a cow","n":1,"size":"1024x1024"}'
  End

  It 'generates text to speech'
    curl() {
      if [[ "$*" == *"chat/completions"* ]]; then
        echo '{"id":"chatcmpl-8keoIjopsPAQt6vMWO51gvyYTWsIN","object":"chat.completion","created":1706130654,"model":"gpt-4-1106-preview","choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":[{"id":"call_JbBjyw9VRNyi8jpoXbN9cOdO","type":"function","function":{"name":"text_to_speech","arguments":"{  \"json\": {    \"model\": \"tts-1\",    \"input\": \"hello\",    \"voice\": \"shimmer\"  }}"}}]},"logprobs":null,"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":731,"completion_tokens":45,"total_tokens":776},"system_fingerprint":"fp_de93422283"}'

      elif [[ "$*" == *"audio/speech"* ]]; then
        echo "mp3 file"
      fi
    }

    mpg123() {
      if ! grep -q "mp3 file"; then
        return 1
      fi
    }

    When call ai 'Say hello in a warm female voice'
    The status should be success
    The output should include "Generating audio using voice: shimmer and input: hello"
  End
End
