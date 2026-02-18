# set -gx HEXAI_PROVIDER copilot

function ai::cursor_agent
    set last_updated_file ~/.cursor_agent_last_updated
    if not test -e $last_updated_file
        cursor-agent update
        touch $last_updated_file
    else
        set current_time (date +%s)
        if test (uname) = Darwin
            set file_time (stat -f %m $last_updated_file 2>/dev/null)
        else
            set file_time (stat -c %Y $last_updated_file 2>/dev/null)
        end
        set time_diff (math "$current_time - $file_time")
        if test $time_diff -gt 86400
            cursor-agent update
            touch $last_updated_file
        end
    end
    touch ~/.nofish
    cursor-agent
end

function ca
    ai::cursor_agent
end

abbr -a suggest hexai
abbr -a explain 'hexai explain'
