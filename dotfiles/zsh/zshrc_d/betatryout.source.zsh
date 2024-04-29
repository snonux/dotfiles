# This file only contains snippets which i am currently only trying out.

# Shell genie
shellgenie::ask () {
    shell-genie ask "$@" --explain
}
alias g=shellgenie::ask
