# Remote AI agent on the rocky VM — tmux session name matches continue-reminder skill.
set -gx ROCKY_AI_TMUX_SESSION ior

function rocky --description 'SSH to rocky and attach to the AI agent tmux session'
    set -l remote_cmd "tmux attach-session -d -t $ROCKY_AI_TMUX_SESSION || exec tmux new-session -s $ROCKY_AI_TMUX_SESSION"
    set -l ssh_common -A -t -o ConnectTimeout=5
    ssh $ssh_common paul@rocky $remote_cmd; or ssh $ssh_common paul@rocky.wg0 $remote_cmd
end

abbr R rocky

function skills
    ls ~/Notes/Prompts/skills
end

function prompts
    ls ~/Notes/Prompts/prompts
end

abbr -a suggest hexai
abbr -a explain 'hexai explain'
abbr -a research 'hexai research'

if test -f ~/git/hypr/hypr.fish
    source ~/git/hypr/hypr.fish
end

set -l ask_bin ~/go/bin/ask

if test -x $ask_bin
    $ask_bin fish | source
else
    echo No $ask_bin found
end

function cl
    claude --dangerously-skip-permissions $argv
end

# Stamp an audit/<date> tag on the current repo's HEAD and push it to
# origin — the end-marker step of the audit-tagging skill
# (~/.claude/skills/audit-tagging), so `audit-due` measures the next
# audit's churn from here rather than re-counting this one's fixes.
# Appends -2, -3, ... on a same-day collision, matching the skill's own
# naming rule.
function audit-tag --description 'Tag the current repo audit/<date> and push it to origin'
    set -l date_str (date +%F)
    set -l tag audit/$date_str
    set -l n 2
    while git rev-parse -q --verify refs/tags/$tag >/dev/null
        set tag audit/{$date_str}-{$n}
        set n (math $n + 1)
    end
    git tag $tag; and git push origin $tag
end
