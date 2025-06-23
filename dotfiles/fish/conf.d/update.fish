function update::tools
    go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
    go install golang.org/x/tools/cmd/goimports@latest
    go install codeberg.org/snonux/tasksamurai/cmd/tasksamurai@latest
    go install codeberg.org/snonux/gos/cmd/gos@latest
    go install codeberg.org/snonux/gitsyncer/cmd/gitsyncer@latest
    doas npm i -g @anthropic-ai/claude-code 2
end
