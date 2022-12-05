#!/usr/bin/bash

if [ $USER != 'root' ]; then
    echo 'This script must be executed as root'
    exit
fi

user='cjordan'
homeDir='/home/'$user
ignoreFile='.link_table.ignore'
ignoreRegex=$(cat $homeDir/configs/$HOSTNAME/$ignoreFile)

fns=$(find $homeDir/configs/ -type f | grep -Ev "$ignoreRegex")
fns=( $fns )

maxChar=0

# Find maximum number of characters in filenames
for fn in ${fns[@]}; do
    charCount=$(echo $fn | wc -L)
    if [ $charCount -gt $maxChar ]; then
        maxChar=$charCount
    fi
done

# Print link table to $homeDir/configs/link_table
>| $homeDir/configs/$HOSTNAME/link_table
maxChar=$(( $maxChar+1 ))
for fn in ${fns[@]}; do
    inum=$(ls -i $fn | awk '{print $1}')
    str=$(find $homeDir /etc  -inum $inum | grep -v $homeDir'/configs')
    printf "%-${maxChar}s %s   %s\n" $fn '-->' $str 
done
