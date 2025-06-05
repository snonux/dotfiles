abbr -a gpt chatgpt
abbr -a gpti "chatgpt --interactive"
abbr -a suggest 'gh copilot suggest'
abbr -a explain 'gh copilot explain'
abbr -a aic 'aichat -e'

function aimodels
    set -l NVIM_DIR "$HOME/.config/nvim/"
    set -l COPILOT_CHAT_DIR "$NVIM_DIR/pack/copilotchat/start/CopilotChat.nvim/lua/CopilotChat"

    printf "gpt-4o\ngpt-4.1\nclaude-3.7-sonnet\nclaude-3.7-sonnet-thought\n" >~/.aimodels
    set -gx COPILOT_MODEL (cat ~/.aimodels | fzf)

    if test -d $COPILOT_CHAT_DIR
        set -l model_config "$COPILOT_CHAT_DIR/config-$COPILOT_MODEL.lua"
        if test -f "$model_config"
            echo "Using CopilotChat config from $model_config"
            cp -v $model_config "$COPILOT_CHAT_DIR/config.lua"
        else
            echo "No config found at $model_config"
        end
    end
end
