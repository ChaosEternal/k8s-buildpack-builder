#!/bin/bash

CMDNAME=$0

usage() {
    cat <<EOF
The usage
$CMDNAME name priority zip|dir targetdir
EOF
}

if [ $# -lt 3 ]
then
    usage
    exit 1
fi

name="$1"
pri="$2"
bp="$3"
target="$4"

bphash=`echo -n "$name"|md5sum|awk '{print $1}'`

bpdirname="${target}"/"${bphash}"
[ -d "$bpdirname" ] && rm -fr "$bpdirname"
mkdir -p "$bpdirname"

if [ -f "$target"/buildpacks.lst ]
then
    sed -i "/$bphash/d" "$target"/buildpacks.lst
fi

echo "$name":"$pri":"$bphash" >> "$target"/buildpacks.lst

if [ -f "$bp" ] && echo "$bp"|grep -q '\.zip$'
then
    unzip "$bp" -d "$bpdirname"
elif [ -d "$bp" ]
then
    cp -r "$bp" "$bpdirname"
fi
    

