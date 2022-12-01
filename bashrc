### If not running interactively, don't do anything
[[ $- != *i* ]] && return

### Colorize prompt
# Red user@host, red relative path, prompt on same line
# export PS1="\e[0;31m[\u@\h \W]$ \e[m"
#
# Red user@host, green absolute path, prompt on next line
export PS1="\e[0;31m[\u@\h\e[m\e[0;32m \$PWD\e[m\e[0;31m]\n$ \e[m"

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
