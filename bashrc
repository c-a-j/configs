### If not running interactively, don't do anything
[[ $- != *i* ]] && return

### Colorize prompt
# Red user@host, red relative path, prompt on same line
# export PS1="\e[0;31m[\u@\h \W]$ \e[m"

# Red user@host, green absolute path, prompt on next line (errors here)
# export PS1="\e[0;31m[\u@\h\e[m\e[0;32m \$PWD\e[m\e[0;31m]\n$ \e[m"

# user@host relativePath gitBranch (generated at https://bashrcgenerator.com/)
# export PS1="[\u@\h \w \$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/')]\n\\$ \[$(tput sgr0)\]"

function fancy_prompt {
    local white_="\[\033[00m\]"
#     local yellow_="\[\033[01;33m\]"
    local red_="\[\033[01;31m\]"
    local green_="\[\033[01;32m\]"
    local blue_="\[\033[01;34m\]"
#     local purple_="\[\033[01;35m\]"
    local user_="\u"
    local at_="@"
    local host_="\h"
    local relLocation_="\w"
    local absLocation_="\$PWD"
    local gitBranch_='`git branch 2> /dev/null | grep -e ^* | sed "s/^* /\ (/" | sed "s/$/\)/"`'
    local prompt_="$"
    local openBracket_="["
    local closeBracket_="]"
    local newLine_="\n"
    export PS1="$blue_$openBracket_$blue_$user_$red_$at_$blue_$host_ $green_$relLocation_$red_$gitBranch_$blue_$closeBracket_ $blue_$prompt_$white_ "
}
fancy_prompt

### Auto CD
shopt -s autocd

### No Clobber - Dissalows user to overwrite existing files by redirection of shell output - must use >| to manually overwrite
set -o noclobber

### Append to history after each command
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

### User defined aliases
alias vi='vim'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

### User defined functions
function bw-unlock() {
    $(bw unlock | grep 'export BW_SESSION' | awk '{print $2 " " $3}')
}

### User defined export variables
export HISTCONTROL="erasedups:ignorespace"
export HISTSIZE=10000
export HISTFILESIZE=10000
export TERMINAL='alacritty'

### bitwarden
export BW_CLIENTID='user.2fb87eb4-db3a-45e9-8401-ab7900c9972f'
export BW_CLIENTSECRET='lbP8zSDA7v8WqIgKaLycm17nhjPGR3'
