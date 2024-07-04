# AI tools in here need API keys to be configured. That's
# not done automatically through Rex yet.

# Shell genie
ai::shellgenie::ask () {
    shell-genie ask "$*" --explain
}
alias genie=ai::shellgenie::ask

ai::chatgpt () {
    chatgpt "$@" | less
}

alias gpt=ai::chatgpt
