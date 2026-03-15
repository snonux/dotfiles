abbr -a suggest hexai
abbr -a explain 'hexai explain'
if test (uname) = Linux
    set -gx OLLAMA_HOST http://hyperstack.wg1:11434
end
