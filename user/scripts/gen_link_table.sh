#!/usr/bin/bash

# To do:
# make faster by using link_table to search only where files are expected
# add options for not running as root, i.e. make it work for work

if [ $USER != 'root' ]; then
    echo 'This script must be executed as root'
    exit
fi

user='cjordan'
repoDir='configs'
homeDir="/home/$user"
ignoreFile='.ignore'
ignoreRegex=$(cat "$homeDir/$repoDir/scripts/$ignoreFile")
fns=$(find $homeDir/$repoDir/ -type f | grep -Ev "$ignoreRegex")
fns=( $fns )
maxChar=0

# Find maximum number of characters in filenames
for fn in ${fns[@]}; do
    charCount=$(echo $fn | wc -L)
    if [ $charCount -gt $maxChar ]; then
        maxChar=$charCount
    fi
done

# Print link table to std out
maxChar=$(( $maxChar+3 ))
for fn in ${fns[@]}; do
    inum=$(ls -i $fn | awk '{print $1}')
    charCount=$(echo $fn | wc -L)
    n=$(( maxChar-charCount ))
    str=$(find $homeDir -inum $inum | grep -v "$homeDir/$repoDir")
    if [ -z "$str" ]; then
        str=$(find /etc /usr -inum $inum | grep -v "$homeDir/$repoDir")
    fi
    printf "%s " $fn 
    printf "%0.s-" $(seq 1 $n)
    printf "%s" '> ' 
    printf "%s\n" $str 
done
