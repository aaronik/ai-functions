# Aaronik's zsh ai functions

*zsh functions that integrate OpenAI LLMs into your command line.*

Works on OSX and linux environments that use gnome.

## Available commands

| Command | Description |
|---------|-------------|
| `ai` | **General Purpose AI CLI tool**. You can ask it to create a shell command, and it'll put it directly into the command buffer. You can ask it for information or to analyze piped in content, and it'll echo it to the terminal. You can ask it to generate images, and it'll generate some and open them in your browser. You can ask it to crawl the web for information. |
| `ai-vision` | **Screen grab, add text, ask vision model**. Uses OS builtins for screen grab _and_ text input/output popups. Designed to be mapped to an OS keyboard shortcut and used outside a terminal. |
| `ai-openai-models` | **Enumerate what models your OPENAI_API_KEY has access to**. It just lists out all the openai models you currently have access to, easy peazy. |

## Requirements

* `OPENAI_API_KEY` environment variable set (see https://platform.openai.com/account/billing/overview)

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
* `ai command to show me the weather`
* `ai watch star wars in the terminal`
* `ai monitor CPU and memory usage and alert if too high`
* `ai convert all jpg images in a folder to png`
* `ai create a new user with sudo privileges`
* `ai set up a cron job to run a script every day at midnight`
* `lsusb | ai how many USB drives are plugged in`
* `ifconfig | ai how much total outbound traffic`
* `tail -20 /var/log/syslog | ai is there any unusual activity in this log?`
* `cat /var/log/auth.log | ai are there any suspicious login attempts here?`
* `ai generate an image of a dog meditating on saturn`
* `ai generate a high quality image, in a hyper realistic style, of a computer coming to life`
* `summarize the headlines from reddit.com`

#### others
* `ai-vision`
* `ai-openai-models`

### Tweaks

You can set `OPENAI_API_MODEL` to specify what model you want, ex `OPENAI_API_MODEL=gpt-4-turbo-preview ai list all open ports`,
or add `export OPENAI_API_MODEL=gpt-4-turbo-preview` to your rc file.

## Notes

You can see an old video demo of the `ai()` function here: https://youtu.be/a_5-7qCuzpw
