# shellcheck disable=SC2317 # unreachable command when setting up mocks
# shellcheck disable=SC2016 # lots of `` in quotes that we want literally

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

Describe 'When being called without the requisite dependencies'
  Include ./ai.zsh

  It 'does not continue without programs'
    which() {
      false
    }

    When call ai "blah blah whatever"
    The status should be failure
    The output should include 'ai requires `curl`, `jq`, and `mpg123`'
  End

  It 'does not continue without OPENAI_API_KEY'
    unset OPENAI_API_KEY

    When call ai "blah blah whatever"
    The status should be failure
    The output should include 'ai requires `curl`, `jq`, and `mpg123`'
  End

  It 'does not continue with blank OPENAI_API_KEY'
    export OPENAI_API_KEY=""

    When call ai "blah blah whatever"
    The status should be failure
    The output should include 'ai requires `curl`, `jq`, and `mpg123`'
  End
End

Describe 'With known responses'
  Include ./ai.zsh

  Describe 'populating the command buffer (printz)'
    It 'works with a basic response'
      # if print is called without -z or with the wrong command, this errors and the test fails
      print() {
        [ "$1" = "-z" ] && [ "$2" = "netstat -tuln" ]
      }

      curl() {
        cat "$JSON_DIR/basic_command.json"
      }

      When call ai 'list all open ports'
      The status should be success
    End

    It 'works with a response with soft quotes'
      print() {
        [ "$1" = "-z" ] && [ "$2" = 'for file in *; do mv -- "${file}" "awesome_${file}"; done' ]
      }

      curl() {
        cat "$JSON_DIR/command_with_soft_quotes.json"
      }

      When call ai 'rename all files to include the word awesome'
      The status should be success
    End

    It 'works with a response with escaped hard quotes'
      Skip "this functionality does not yet work"
      print() {
        [ "$1" = "-z" ]
      }

      curl() {
        cat "$JSON_DIR/command_with_escaped_hard_quotes.json"
      }

      When call ai 'list my subnet mask'
      The status should be success
    End
  End

  It 'echoes'
    curl() {
      cat "$JSON_DIR/basic_echo.json"
    }

    When call ai "what color is an elephant usually?"
    The status should be success
    The output should equal "
Elephants are usually gray in color."
  End

  It 'generates images'
    curl() {
      if [[ "$*" == *"chat/completions"* ]]; then
        cat "$JSON_DIR/image_json.json"
      elif [[ "$*" == *"images/generations"* ]]; then
        echo '{"created":1706129930,"data":[{"url":"image.biz"}]}'
      fi
    }

    print_called=0
    print() {
      print_called=1
      [ "$1" = "-z" ] && [ "$2" = "open 'image.biz'" ]
    }

    Data "Y"

    When call ai "Generate an image of a cow"
    The status should be success
    The output should include '{"model":"dall-e-2","prompt":"a cow","n":1,"size":"1024x1024"}'

    if ! [ $print_called = 1 ]; then
      >&2 echo "print -z was never called during the image generation"
      false
    fi
  End

  It "doesn't generate images when the user rejects the original json"
    curl() {
      if [[ "$*" == *"chat/completions"* ]]; then
        cat "$JSON_DIR/image_json.json"
      elif [[ "$*" == *"images/generations"* ]]; then
        echo 'this will make jq choke'
      fi
    }

    Data "n"

    When call ai "Generate an image of a cow"
    The output should include '{"model":"dall-e-2","prompt":"a cow","n":1,"size":"1024x1024"}'
    The status should be success
    The error should be blank
  End

  It 'generates text to speech'
    curl() {
      if [[ "$*" == *"chat/completions"* ]]; then
        cat "$JSON_DIR/text_to_speech.json"

      elif [[ "$*" == *"audio/speech"* ]]; then
        echo "mp3 file"
      fi
    }

    mpg123_called=0
    mpg123() {
      if ! grep -q "mp3 file"; then
        return 1
      fi
      mpg123_called=1
    }

    When call ai 'Say hello in a warm female voice'
    The status should be success
    The output should include "Generating audio using voice: shimmer and input: hello"
    if ! [ $mpg123_called = 1 ]; then
      >&2 echo "mpg123 was never called"
      false
    fi
  End
End
