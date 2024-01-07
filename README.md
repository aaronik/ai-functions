# Aaronik's zsh ai functions

*zsh functions that integrate OpenAI LLMs into your command line.*

Works on OSX and linux environments that use gnome.

## Available commands

| Command | Description |
|---------|-------------|
| `ai` | **Create bash one liners**. You tell it what you want the bash command to do, it generates one and puts it right into the command buffer for you. You can also ask it things that aren't meant to be bash one liners, and it will echo the response to the terminal. |
| `ai-vision` | **Screen grab, add text, ask vision model**. Uses OS builtins for screen grab _and_ text input/output popups. Designed to be mapped to an OS keyboard shortcut and used outside a terminal. |
| `ai-openai-models` | **Enumerate what models your OPENAI_API_KEY has access to**. It just lists out all the openai models you currently have access to, easy peazy. |

## Requirements

* `OPENAI_API_KEY` environment variable set.
  As it stands, you'll also need access to the `gpt-4` based models, which you can get by *prepaying* for the openai API at https://platform.openai.com/account/billing/overview.

## Installation

In your `~/.zshrc`, where path/to/ai-functions/ is this project's root,

```zsh
# aaronik/ai-functions https://github.com/Aaronik/ai-functions
export PATH=path/to/ai-functions/bin:$PATH # Get ai-openai-models and ai-vision
source /path/to/ai-functions/ai.zsh # Source as zsh function so `print -z` works
```

---

## Usage

### Examples

#### ai
* `ai list all open ports`
* `ai show me the weather in my local region`
* `ai watch star wars in the terminal`
* `ai monitor CPU and memory usage and alert if too high`
* `ai convert all jpg images in a folder to png`
* `ai create a new user with sudo privileges`
* `ai set up a cron job to run a script every day at midnight`
* `lsusb | ai disconnect from all bluetooth devices`
* `ifconfig | ai port knock my local machine`
* `tail -20 /var/log/syslog | ai is there any unusual activity in this log?`
* `cat /var/log/auth.log | ai are there any suspicious login attempts here?`

#### others
* `ai-vision`
* `ai-openai-models`

## Notes

You can see a video demo of the `ai()` function here: https://youtu.be/a_5-7qCuzpw

## TODO

* a vision - can I supply an area for it to use for memory,  that summarizes what its learned and would
  like to hold on to in order to better answer future requests? For each request,
  in 20 lines only, each of no more than 80 character's width, which exists between the -----'s,
  it can modify what's in the 20 80 width lines of memory any way it wants, but it can't
  exceed that many lines so that the memory can best serve it to answer future questions.
* another - add image creation. If the user asked to create an image, call a function
  that saves the created image, call the fn to populate the command buffer with
  `open path/to/image`.
* Allow models to be swapped out
