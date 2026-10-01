function update::record_status --argument-names status_file
    set -e argv[1]
    $argv
    set -l result $status
    printf '%s\n' $result >"$status_file"
end

function update::tools
    set -l status_dir (mktemp -d)
    or return 1
    set -l status_files
    set -l pids
    set -l failed 0

    echo "Installing/updating gofumpt"
    update::record_status "$status_dir/gofumpt" go install mvdan.cc/gofumpt@latest &
    set -a pids $last_pid
    set -a status_files "$status_dir/gofumpt"

    echo "Installing/updating mage"
    update::record_status "$status_dir/mage" go install github.com/magefile/mage@latest &
    set -a pids $last_pid
    set -a status_files "$status_dir/mage"

    echo "Installing/updating golangci-lint"
    update::record_status "$status_dir/golangci-lint" go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest &
    set -a pids $last_pid
    set -a status_files "$status_dir/golangci-lint"

    echo "Installing/updating goimports"
    update::record_status "$status_dir/goimports" go install golang.org/x/tools/cmd/goimports@latest &
    set -a pids $last_pid
    set -a status_files "$status_dir/goimports"

    for prog in hexai hexai-lsp-server hexai-tmux-action hexai-mcp-server ask
        if not test -x $HOME/go/bin/$prog
            echo "Skipping $prog (no binary in $HOME/go/bin)"
            continue
        end
        echo "Installing/updating $prog from github.com/snonux/hexai/cmd/$prog@latest"
        update::record_status "$status_dir/$prog" go install github.com/snonux/hexai/cmd/$prog@latest &
        set -a pids $last_pid
        set -a status_files "$status_dir/$prog"
    end

    for prog in tasksamurai timesamurai gt loadbars foostore gonf
        if not test -x $HOME/go/bin/$prog
            echo "Skipping $prog (no binary in $HOME/go/bin)"
            continue
        end
        echo "Installing/updating $prog from github.com/snonux/$prog/cmd/$prog@latest"
        update::record_status "$status_dir/$prog" go install github.com/snonux/$prog/cmd/$prog@latest &
        set -a pids $last_pid
        set -a status_files "$status_dir/$prog"
    end

    update::record_status "$status_dir/cursor-agent" cursor-agent update &
    set -a pids $last_pid
    set -a status_files "$status_dir/cursor-agent"

    echo 'Updating claude'
    update::record_status "$status_dir/claude" claude update &
    set -a pids $last_pid
    set -a status_files "$status_dir/claude"

    if test (uname) = Linux
        echo "Installing/updating @openai/codex globally via npm"
        # doas npm uninstall -g @openai/codex
        doas npm install -g @openai/codex
        or set failed 1

        # echo "Installing/updating @google/gemini-cli globally via npm"
        # # doas npm uninstall -g @google/gemini-cli
        # doas npm install -g @google/gemini-cli

        echo "Installing/updating @sourcegraph/amp globally"
        doas npm install -g @ampcode/cli
        or set failed 1

        # echo "Installing/updating opencode-ai globally via npm"
        # # doas npm uninstall -g opencode-ai
        # doas npm install -g opencode-ai

        echo "installing/updating pi-coding-agent globally via npm"
        doas npm install -g @earendil-works/pi-coding-agent
        or set failed 1
    end

    for pid in $pids
        wait $pid
        or set failed 1
    end
    for status_file in $status_files
        set -l job_status
        read -l job_status <"$status_file"
        if test $status -ne 0; or test "$job_status" != 0
            set failed 1
        end
    end
    rm -rf "$status_dir"
    or set failed 1
    return $failed
end
