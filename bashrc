#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# AUTO CD
shopt -s autocd

### NO CLOBBER - DISSALOWS EXISTING USER TO OVERWRITE EXISTING FILES BY REDIRECTION OF SHELL OUTPUT - MUST USE >| TO MANUALLY OVERWRITE
set -o noclobber

# APPEND TO HISTORY FILE AFER EACH COMMAND
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

### USER DEFINED ALIASES
alias vi='vim'
alias ls='ls --color=auto'
function bw-unlock() {
    $(bw unlock | grep 'export BW_SESSION' | awk '{print $2 " " $3}')
}
PS1='[\u@\h \W]\$ ' # no idea what this is, it was included in the default bashrc

### USER DEFINED EXPORT VARIABLES
export HISTCONTROL="erasedups:ignorespace"
export HISTSIZE=10000
export HISTFILESIZE=10000
export TERMINAL='alacritty'

### bitwarden
export BW_CLIENTID='user.2fb87eb4-db3a-45e9-8401-ab7900c9972f'
export BW_CLIENTSECRET='lbP8zSDA7v8WqIgKaLycm17nhjPGR3'
