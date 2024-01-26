# shellcheck disable=SC2317 # unreachable command when setting up mocks
# shellcheck disable=SC2016 # lots of `` in quotes that we want literally

Include ./ai.zsh

Describe 'INTEGRATION'
  set_model() {
    export OPENAI_API_MODEL=gpt-3.5-turbo-1106
  }
  Before 'set_model'

  It 'Makes a command'
    print_called=0
    print() {
      print_called=1
      [ "$1" = "-z" ]
    }

    When call ai 'list all open ports'
    The status should be success
    The value $print_called should eq 1
  End

  It 'Echoes information'
    When call ai 'how many quarts are in a gallon'
    The status should be success
    The output should include "4"
  End

  It 'Generates images'
    # Just ensure this test suite doesnt actually generate the image
    curl() {
      if [[ "$*" == *"images/generations"* ]]; then
        echo '{"created":1706129930,"data":[{"url":"image.biz"}]}'
      else
        /usr/bin/curl $*
      fi
    }

    Data "n"

    When call ai 'generate an image of a cup of coffee'
    The status should be success
    The output should include "continue"
  End

  It 'Speaks'
    curl() {
      if [[ "$*" == *"audio/speech"* ]]; then
        echo 'mp3 file'
      else
        /usr/bin/curl $*
      fi
    }

    When call ai 'say hello there in a warm male voice'
    The status should be success
    The output should include "Generating audio"
  End

  It 'crawls the web'
    When call ai 'summarize reddit.com'
    The status should be success
    The output should include "crawling https://www.reddit.com"
  End
End

