#!/usr/bin/bash

### Colorize prompt
function fancy_prompt {
    declare -A colors

    colors[black]="\e[0;30m"
    colors[red]="\[\033[01;31m\]"
    colors[green]="\[\033[01;32m\]"
    colors[yellow]="\e[0;33m"
    colors[blue]="\[\033[01;34m\]"
    colors[purple]="\[\033[01;35m\]"
    colors[cyan]="\e[0;36m"
    colors[white]="\[\033[00m\]"

    colors[bold-black]="\e[1;30m"
    colors[bold-red]="\e[1;31m"
    colors[bold-green]="\e[1;32m"
    colors[bold-yellow]="\e[1;33m"
    colors[bold-blue]="\e[1;34m"
    colors[bold-purple]="\e[1;35m"
    colors[bold-cyan]="\e[1;36m"
    colors[bold-white]="\e[1;37m"

 	colors[intense-black]="\e[0;90m"
    colors[intense-red]="\e[0;91m"
    colors[intense-green]="\e[0;92m"
    colors[intense-yellow]="\e[0;93m"
    colors[intense-blue]="\e[0;94m"
    colors[intense-purple]="\e[0;95m"
    colors[intense-cyan]="\e[0;96m"
    colors[intense-white]="\e[0;97m"

 	colors[intense-bold-black]="\e[1;90m"
    colors[intense-bold-red]="\e[1;91m"
    colors[intense-bold-green]="\e[1;92m"
    colors[intense-bold-yellow]="\e[1;93m"
    colors[intense-bold-blue]="\e[1;94m"
    colors[intense-bold-purple]="\e[1;95m"
    colors[intense-bold-cyan]="\e[1;96m"
    colors[intense-bold-white]="\e[1;97m"

    local white_="\[\033[00m\]"
    local red_="\[\033[01;31m\]"
    local green_="\[\033[01;32m\]"
    local blue_="\[\033[01;34m\]"
    local purple_="\[\033[01;35m\]"
    local yellow_="\e[0;33m"
    local cyan_="\e[0;36m"
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

    bracket_co_=${colors[$1]}
    user_co_=${colors[$2]}
    at_co_=${colors[$3]}
    host_co_=${colors[$4]}
    path_co_=${colors[$5]}
    git_co_=${colors[$6]}
    prompt_co_=${colors[$7]}

    export PS1="$bracket_co_$openBracket_$user_co_$user_$at_co_$at_$host_co_$host_ $path_co_$relLocation_$git_co_$gitBranch_$bracket_co_$closeBracket_$newLine_$prompt_co_$prompt_$white_ "
}
if echo $HOSTNAME | grep -q 'Arch'; then
    if [ $(whoami) != 'root' ]; then
        bracket_co=blue
        user_co=blue
        at_co=red
        host_co=$user_co
        path_co=green
        git_co=red
        prompt_co=$bracket_co
    else
        bracket_co=blue
        user_co=red
        at_co=white
        host_co=$user_co
        path_co=green
        git_co=red
        prompt_co=$bracket_co
    fi
else
    if [ $(whoami) != 'root' ]; then
        bracket_co=bold-yellow
        user_co=bold-green
        at_co=bold-yellow
        host_co=$user_co
        path_co=bold-yellow
        git_co=bold-red
        prompt_co=$bracket_co
    else
        bracket_co=bold-yellow
        user_co=red
        at_co=bold-yellow
        host_co=$user_co
        path_co=bold-yellow
        git_co=red
        prompt_co=$bracket_co
    fi
fi
fancy_prompt $bracket_co $user_co $at_co $host_co $path_co $git_co $prompt_co



