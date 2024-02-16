# Unit spec for ai zsh script
#
# shellcheck disable=SC2317 # unreachable command when setting up mocks
# shellcheck disable=SC2016 # lots of `` in quotes that we want literally

Include ./ai.zsh

# So running this integration suite is cheaper
export OPENAI_API_MODEL=gpt-3.5-turbo-0125

function function_exists() {
  type "$1" >/dev/null 2>&1
}

# Test env
Describe 'The test environment itself'
  It 'has OPENAI_API_MODEL set to 3.5'
    When call echo "$OPENAI_API_MODEL"
    The output should eq "gpt-3.5-turbo-0125"
  End

  It 'has ai available to call'
    When call type ai
    The status should be success
    The output should equal "ai is a shell function from ./ai.zsh"
  End
End

# Deps
Describe 'When being called without the requisite dependencies'
  It 'does not continue without programs'
    which() {
      false
    }

    When call ai "blah"
    The status should be failure
    The output should include 'ai requires `go` and `lynx`'
  End

  It 'does not continue without OPENAI_API_KEY'
    unset OPENAI_API_KEY

    When call ai "blah"
    The status should be failure
    The output should include 'OPENAI_API_KEY'
  End

  It 'does not continue with blank OPENAI_API_KEY'
    export OPENAI_API_KEY=""

    When call ai "blah"
    The status should be failure
    The output should include 'OPENAI_API_KEY'
  End
End

# System
Describe 'System information'
  uname() {
    if [ "$1" = "-a" ]; then
      echo "Linux"
    else
      echo "whatevs"
    fi
  }

  go() {
    if [[ "$*" =~ --system_content.*Linux.* ]]; then
      echo "info works"
    else
      echo "error no system content"
    fi
  }

  It 'Is included'
    When call ai "blah"
    The status should be success
    The output should be defined
  End
End

# Pipes
Describe 'When data is piped in'
  go() {
    if [[ "$*" =~ "ADDITIONAL CONTEXT: additional context" ]]; then
      echo "info works"
    else
      echo "error additional context not detected"
    fi
  }

  It "It includes it under the heading ADDITIONAL CONTEXT"
    When call eval 'echo "additional context" | ai "blah"'
    The status should be success
    The output should eq "works"
  End
End

# Model
Describe 'When a model is specified via OPENAI_API_MODEL'
  go() {
    if [[ "$*" =~ " --model furby " ]]; then
      echo "info works"
    else
      echo "error model didnt work"
    fi
  }

  It 'Is read from the env'
    export OPENAI_API_MODEL="furby"
    When call ai "blah"
    The status should be success
    The output should be defined
  End
End

# Received non function message
Describe 'When answering with a message'
  go() {
    if [[ "$*" =~ "primary" ]]; then
      echo "message hello"
    else
      echo "ERROR: go called with unknown params"
    fi
  }

  It "It calls the go app's crawl_web subcommand"
    When call ai "blah"
    The status should be success
    The output should eq "hello"
  End
End

# Received error
Describe 'When error from api'
  go() {
    if [[ "$*" =~ "primary" ]]; then
      echo "error hello"
    else
      echo "ERROR: go called with unknown params"
    fi
  }

  It "It calls the go app's error subcommand"
    When call ai "blah"
    The status should be failure
    The stderr should include hello
  End
End

# Unexpected go app response
Describe 'When encountering an unexpected response from the go primary request'
  go() {
    echo "nonextentfunction"
  }

  It 'Errors to stderr'
    When call ai "blah"
    The status should be failure
    The stderr should include "errored - received unexpected response from go app:"
  End
End

# Tests print -z
Describe 'When asked for a bash one liner'
  go() {
    echo "printz works"
  }

  print() {
    if [ "$1" = "-z" ] && [ "$2" = "works" ]; then
      true
    else
      false
    fi
  }

  It 'Is provided to the LLM'
    When call ai "blah"
    The status should be success
  End
End

# Tests info
Describe 'When asked for an info'
  go() {
    printf "info works"
  }

  echo() {
    if [ "$1" = "works" ]; then
      true
    else
      false
    fi
  }

  It 'Is provided to the LLM'
    When call ai "blah"
    The status should be success
  End
End

# Tests gen_image
Describe 'When asked for an image'
  go() {
    if [[ "$*" =~ "primary" ]]; then
      echo "gen_image params"
    elif [[ "$*" =~ "gen_image" ]] && [[ "$*" =~ "--jsonParams params" ]]; then
      printf "coming from inside the go app"
    else
      echo "ERROR: go called with unknown params"
    fi
  }

  It "It calls the go app's gen_image subcommand"
    When call ai "blah"
    The status should be success
    The output should eq "coming from inside the go app"
  End
End

# Tests crawl_web
Describe 'When asked to crawl the web'
  go() {
    if [[ "$*" =~ "primary" ]]; then
      echo "crawl_web params"
    elif [[ "$*" =~ "crawl_web" ]] && [[ "$*" =~ "--jsonParams params" ]]; then
      printf "coming from inside the go app"
    else
      echo "ERROR: go called with unknown params"
    fi
  }

  It "It calls the go app's crawl_web subcommand"
    When call ai "blah"
    The status should be success
    The output should eq "coming from inside the go app"
  End
End
