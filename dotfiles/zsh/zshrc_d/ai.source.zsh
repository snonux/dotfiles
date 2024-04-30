# AI tools in here need API keys to be configured. That's
# not done automatically through Rex yet.

# Shell genie
ai::shellgenie::ask () {
    shell-genie ask "$*" --explain
}
alias genie=ai::shellgenie::ask

# ChatGPT command line tool.
alias gpt=chatgpt
