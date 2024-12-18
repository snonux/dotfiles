# AI tools in here need API keys to be configured. That's
# not done automatically through Rex yet.

ai::chatgpt () {
    chatgpt "$@" | less
}

alias gpt=ai::chatgpt
alias gpti='chatgpt --interactive'
