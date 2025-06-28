function update::tools
    go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
    go install golang.org/x/tools/cmd/goimports@latest
    go install codeberg.org/snonux/tasksamurai/cmd/tasksamurai@latest
    if [ "$(uname)" = Linux ]
        then
        echo "Installing gos from codeberg.org/snonux/gos/cmd/gos@latest"
        go install codeberg.org/snonux/gos/cmd/gos@latest
        echo "Installing gitsyncer from codeberg.org/snonux/gitsyncer/cmd/gitsyncer@latest"
        go install codeberg.org/snonux/gitsyncer/cmd/gitsyncer@latest
        echo "Installing @anthropic-ai/claude-code globally via npm"
        doas npm i -g @anthropic-ai/claude-code
        echo "Installing @openai/codex globally via npm"
        doas npm install -g @openai/codex
        echo "Installing @google/gemini-cli globally via npm"
        doas npm install -g @google/gemini-cli
        fi
    end
end
