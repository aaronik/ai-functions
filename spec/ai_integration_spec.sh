# shellcheck disable=SC2317 # unreachable command when setting up mocks
# shellcheck disable=SC2016 # lots of `` in quotes that we want literally

Include ./ai.zsh

export OPENAI_API_MODEL=gpt-3.5-turbo-1106
export AI_PRINT_FUNCTION_NAME_RESPONSE=1

Describe 'This suite'
  It 'uses gpt-3.5'
    # Tests run against 3.5 for reasons:
    # 1) It's cheaper. These test runs make a lot of calls.
    # 2) 3.5 is worse, which means the prompt has to be more accurate. If it passes for 3.5,
    #   then it's definitely a good prompt.
    # 3) It's faster
    The value $OPENAI_API_MODEL should eq "gpt-3.5-turbo-1106"
  End

  It 'requests the function print the called function name'
    The value $AI_PRINT_FUNCTION_NAME_RESPONSE should eq "1"
  End
End

Describe 'printz (Making a command)'
  Parameters
    "list all open ports"
    "rename all files in the current directory to contain the word awesome"
    "list my subnet mask"
    "show me the weather in my local region"
    "watch star wars in the terminal"
    "monitor CPU and memory usage and alert if too high"
    "convert all jpg images in a folder to png"
    "create a new user with sudo privileges"
    # "set up a cron job to run a script every day at midnight" # TODO failing on echo call
  End

  It "calls printz for: $1"
    print_called=0
    print() {
      print_called=1
      [ "$1" = "-z" ]
    }

    When call ai "$1"
    The status should be success
    The value $print_called should eq 1
    The output should start with "printz"
  End

End

Describe 'echo (Printing information to stdout)'
  Parameters
    "how many quarts are in a gallon"
    "how many US presidents have there been"
    "what color is an elephant?"
  End

  Data "n"

  It "calls echo for: $1"
    When call ai "$1"
    The status should be success
    The output should start with "echo"
  End
End


Describe 'gen_image (Generating an image using dall-e)'
  Parameters
    "generate an image of a cup of coffee"
  End

  It "calls gen_image for: $1"
    # Just ensure this test suite doesnt actually generate the image
    curl() {
      if [[ "$*" == *"images/generations"* ]]; then
        echo '{"created":1706129930,"data":[{"url":"image.biz"}]}'
      else
        /usr/bin/curl $*
      fi
    }

    Data "n"

    When call ai "$1"
    The status should be success
    The output should start with "gen_image"
  End
End

Describe 'text_to_speech (Saying or speaking something)'
  Parameters
    "say hello there in a warm male voice"
  End

  It "calls text_to_speak for: $1"
    curl() {
      if [[ "$*" == *"audio/speech"* ]]; then
        echo 'mp3 file'
      else
        /usr/bin/curl $*
      fi
    }

    When call ai "$1"
    The status should be success
    The output should start with "text_to_speech"
  End
End

Describe 'crawl_web (Crawling a website for information)'
  Parameters
    "summarize reddit.com"
    "what is the first headline from bbc.com?"
  End

  # We're testing the original prompt, this business below prevents the rest of the script,
  # which can be slow and expensive.
  lockfile="/tmp/ai-test-curl-lock"
  curl() {
    if [ -e "$lockfile" ]; then
      rm "$lockfile"
      exit 0
    else
      touch "$lockfile"
      /usr/bin/curl $*
    fi
  }

  It "calls crawl_web for: $1"
    When call ai "$1"
    The status should be success
    The output should start with "crawl_web"
  End
End

