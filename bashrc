#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

# AUTO CD
shopt -s autocd

# NO CLOBBER - DISSALOWS EXISTING USER TO OVERWRITE EXISTING FILES BY REDIRECTION OF SHELL OUTPUT - MUST USE >| TO MANUALLY OVERWRITE
set -o noclobber

# USER DEFINED ALIASES
alias vi='vim'
alias ls='ls --color=auto'

# USER DEFINED EXPORT VARIABLES
export HISTCONTROL="erasedups:ignorespace"
export TERMINAL='alacritty'
