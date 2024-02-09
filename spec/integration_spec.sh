# shellcheck disable=SC2317 # unreachable command when setting up mocks
# shellcheck disable=SC2016 # lots of `` in quotes that we want literally

Include ./ai.zsh

# So running this integration suite is cheaper
export OPENAI_API_MODEL=gpt-3.5-turbo-0125

function function_exists() {
  type "$1" >/dev/null 2>&1
}

Describe 'The test environment itself'
  # This is tested here and in unit - I'm leaving it here because it's really
  # import OPENAI_API_MODEL is set for these integration tests.
  It 'has OPENAI_API_MODEL set to 3.5'
    When call echo "$OPENAI_API_MODEL"
    The output should eq "gpt-3.5-turbo-0125"
  End
End

# Tests system information retrieval
Describe 'System information'
  uname() {
    if [ "$1" = "-s" ]; then
      echo "Linux"
    else
      /usr/bin/uname $*
    fi
  }

  It 'Is provided to the LLM'
    When call ai "What system is this"
    The status should be success
    The output should include "Linux"
  End
End

# Tests piping
Describe 'System information'
  It 'Is provided to the LLM'
    When call eval 'lsusb | ai "please explain what this is"'
    The status should be success
    The output should include "USB"
  End
End

# Tests errors (with bogus model)
Describe 'OpenAI Error'
  It 'Is reported appropriately'
    export OPENAI_API_MODEL="furby"
    When call ai "blah"
    The status should be failure
    The stderr should include "The model \`furby\` does not exist"
  End
End

