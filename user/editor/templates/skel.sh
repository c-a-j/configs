#!/usr/bin/env bash

set -eou pipefail

usage() {
  printf 'Usage: %s [opt]\n' "${0##*/}"
}

help() {
  cat <<EOF
Usage:
  $(basename "$0") [OPTION] [ARG]

Description:
  print something.

Operations (choose one):
  -h    Print help
  -p    Print a message
EOF
}

print=0
read_file=0
while getopts ':hp:f:' opt; do
  case "$opt" in
    p) 
      print=1
      msg=$OPTARG ;;
    f)
      read_file=1
      file=$OPTARG ;;
    h) help; exit 0;;
    :) 
      echo "option -$OPTARG requires an argument" >&2
      exit 2 ;;
    \?)
      echo "unknown option -$OPTARG" >&2
      exit 2 ;;
    *)
      usage; exit 2 ;;
  esac
done
shift "$((OPTIND - 1))"

if (( print )); then
  echo ${msg:-}
fi

if (( read_file )); then
  if [ ! -f ${file:-} ]; then
    echo "$file does not exist" >&2
    exit 1
  fi
  while IFS= read -r line; do
    printf '%s\n' "$line"
  done < $file
fi

if [[ ! -z ${@} ]]; then
  for arg in ${@}; do
    echo $arg
  done
fi

