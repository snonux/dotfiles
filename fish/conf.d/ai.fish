abbr -a suggest hexai
abbr -a explain 'hexai explain'
if test (uname) = Linux
    set -gx OLLAMA_HOST http://hyperstack.wg1:11434
end

# Claude Code via vLLM + LiteLLM proxy on Hyperstack VM (requires wg1 tunnel active)
abbr -a hyperstack-claude 'ANTHROPIC_BASE_URL=http://hyperstack.wg1:4000 ANTHROPIC_API_KEY=sk-litellm-master claude --model claude-opus-4-6-20260604 --dangerously-skip-permissions'
