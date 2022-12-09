#!/usr/bin/bash

ignoreFile='.link_table.ignore'
ignoreRegex=$(cat $HOME/configs/work/$ignoreFile)
fns=$(find $HOME/configs -type f | grep -Ev "$ignoreRegex")
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
    str=$(find $HOME -inum $inum | grep -v $HOME'/configs')
    printf "%s " $fn 
    printf "%0.s-" $(seq 1 $n)
    printf "%s" '> ' 
    printf "%s\n" $str 
done
