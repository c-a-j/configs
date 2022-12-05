#!/usr/bin/bash

if [ $USER != 'root' ]; then
    echo 'This script must be executed as root'
    exit
fi

user='cjordan'
homeDir='/home/'$user

fns=$(ls -li $homeDir/configs | awk -F ' ' 'NR > 1 {print $10}')
fns=( $fns )

indexNums=$(ls -li $homeDir/configs | awk -F ' ' 'NR > 1 {print $1}')
indexNums=( $indexNums )

linkCounts=$(ls -li $homeDir/configs | awk -F ' ' 'NR > 1 {print $3}')
linkCounts=( $linkCounts )

n=$(( ${#indexNums[@]}-1 ))
maxChar=0

# Find maximum number of characters in filenames
for i in $(seq 0 $n); do
    charCount=$(echo ${fns[i]} | wc -L)
    if [ $charCount -gt $maxChar ] && [ ${linkCounts[i]} -gt 1 ]; then
        maxChar=$charCount
    fi
done

# Print link table to $homeDir/configs/link_table
>| $homeDir/configs/link_table
maxChar=$(( $maxChar+1 ))
for i in $(seq 0 $n); do
    if [ ${linkCounts[i]} -gt 1 ]; then
        str=$(find $homeDir /etc  -inum ${indexNums[i]} | grep -v $homeDir'/configs')
        printf "%-${maxChar}s %s   %s\n" ${fns[i]} '-->' $str 
    fi
done
