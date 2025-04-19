# AI tools in here need API keys to be configured. That's
# not done automatically through Rex yet.

function ai::chatgpt
    chatgpt $argv | less
end
alias gpt="ai::chatgpt"
alias gpti="chatgpt --interactive"

function copilot::suggest
    gh copilot suggest $argv
end

function copilot::explain
    gh copilot explain $argv
end

alias suggest="copilot::suggest"
alias explain="copilot::explain"
