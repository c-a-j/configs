#!/usr/bin/bash

if [ ! -z $1 ]; then
    fp=$1
else
    file="link_table"
    fp="/home/cjordan/configs/scripts/$file"
fi

if [ ! -f "$fp" ]; then
    echo "Error: $fp does not exist"
    exit
fi

git_files=$(cat $fp | awk '{print $1}')
git_files=( $git_files )
cfg_files=$(cat $fp | awk '{print $3}')
cfg_files=( $cfg_files )

n=${#git_files[@]}
n=$(( n-1 ))

for i in $(seq 0 $n); do
    git_inum=$(ls -i "${git_files[i]}" | awk '{print $1}')
    if [ -f "${cfg_files[i]}" ]; then
        cfg_inum=$(ls -i "${cfg_files[i]}" | awk '{print $1}')
    fi
    if [ $git_inum -ne $cfg_inum ] && [ -f "${cfg_files[i]}" ]; then
        echo "Do you want to force the following link? [yn]"
        echo ${git_files[i]} ' ---> ' ${cfg_files[i]}
        read answer
        if [ $answer == 'Y' ] || [ $answer == 'y' ]; then
            ln -f ${git_files[i]} ${cfg_files[i]}
            echo 'Link created'
        else
            continue
        fi
    elif [ ! -f "${cfg_files[i]}" ]; then
        echo "Do you want to establish the following link? [yn]"
        echo ${git_files[i]} ' ---> ' ${cfg_files[i]}
        read answer
        if [ $answer == 'Y' ] || [ $answer == 'y' ]; then
            ln -f ${git_files[i]} ${cfg_files[i]}
            echo 'Link created'
        else
            continue
        fi
fi
done
