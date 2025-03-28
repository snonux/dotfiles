# AI tools in here need API keys to be configured. That's
# not done automatically through Rex yet.

ai::chatgpt () {
    chatgpt "$@" | less
}

alias gpt=ai::chatgpt
alias gpti='chatgpt --interactive'

copilot::suggest () {
    gh copilot suggest "$@"
}

copilot::explain () {
    gh copilot explain "$@"
}

alias suggest=copilot::suggest
alias explain=copilot::explain
