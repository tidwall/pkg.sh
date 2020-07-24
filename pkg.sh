#!/bin/bash

# A generalized package manager for whatever code.
# 
# Copyright 2020 Joshua J Baker. All rights reserved.
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file.
#
# Documentation at https://github.com/tidwall/pkg.sh

set -e
set -o pipefail

ln=0
cmd="$1"
wd=$(pwd)
counter=0
idir="./$3"
self="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )/$(basename "$0")"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename $0).XXXXXXXXXXXX")

# mkurl generates a url from an import directive
mkurl() {
    if case $1 in ../*|./*|/*) ;; *) false;; esac; then
        echo "file://$1"
    elif case $1 in *://*) ;; *) false;; esac; then
        echo $1
    elif case $1 in github.com/*) ;; *) false;; esac; then
        tag="${1:11}"
        if [ "$2" == "" ]; then branch="master"; else branch="$2"; fi
        if [ "$3" == "" ]; then file=".package"; else file="$3"; fi
        echo "https://raw.githubusercontent.com/$tag/$branch/$file"
    else 
        >&2 echo "line $ln: invalid location: '$1'"; exit 1
    fi
}

curlx() {
    # if case $1 in file:///*) ;; *) false;; esac; then
    #     cat ${1:7}
    #el
    if case $1 in file://*) ;; *) false;; esac; then
        wd1=$(pwd) && cd $wd && cat ${1:7} && cd $wd1
    else
        curl -m 60 -f -s -S "$1"
    fi
}

# fetch downloads files associated with an import directive. If the import is
# a .package file then the operation will recursively download all dependencies.
fetch() {
    counter=$(expr $counter + 1)
    pdir="$tmpdir/$counter"
    mkdir -p $pdir
    cd $pdir
    if [ $(basename "$2") == .package ]; then
        >&2 echo "[get] $2"
        curlx "$url" > $(basename $url)
        echo "" | cat .package |  sed -e 's/^[ \t]*//' | grep '^file *' | \
        while read line ; do
            fname=$(echo $line | cut -d' ' -f2-)
            fname=$(echo $fname | sed 's:#.*$::g; /^[[:space:]]*$/d' | xargs)
            url=$(dirname $2)/$fname
            mkdir -p $(dirname "$fname")
            if [ "$1" == "clean" ]; then
                echo "${idir%/}/${3%/}/$fname"
                touch $fname
            else      
                >&2 echo "[get] $url"
                curlx "$url" > $fname
            fi
        done
        $self $1 inner "$3"
        rm -rf .package
    elif [ "$1" == "clean" ]; then
        echo ${idir%/}/${3%/}/$(basename $2)
        touch $(basename $2)
    else
        >&2 echo "[get] $2"
        curlx "$2" > $(basename $2)
    fi
    cd $wd
    if [ $1 != clean ]; then
        mkdir -p $3
        cp -rf $pdir/* $3/
    fi
}

# rname cleans a file name and returns the minimum relative path to the current
# working directory.
rname() {
    fname=$(cd $(dirname $1); pwd)/$(basename $1)
    if case $fname in $wd*) ;; *) false;; esac; then
        fname=${fname:${#wd}+1}
        echo $fname
    else
        >&2 echo "file outside working directory"; exit 1
    fi
}

# import executes a single "import" directive.
import() {
    outdir="."
    i=0
    for var in "$@"; do
        if [ "$var" == "->" ]; then
            outdir="${@:i+2:1}"
            if [[ "$outdir" == *".."* ]] || [[ "$outdir" == "/"* ]]; then
                # protect against directory traversal attacks
                >&2 echo "line $ln: invalid output directory: $outdir"; exit 1
            fi
            set -- "${@:0:i+1}"
            break
        fi
        i=$(expr $i + 1)
    done
    url=$(mkurl "$1" "$2" "$3")
    if [ "$cmd" == "import" ]; then
        fetch import $url $outdir
    elif [ "$cmd" == "clean" ]; then
        fetch clean $url $outdir
    fi
}

# file executes a single "file" directive
file() {
    if [ ! -f "$1" ]; then
        >&2 echo "line $ln: missing local file: $1"; exit 1;
    fi
}

# sum executes a single "sum" directive
sum() {
    if [ "$NOSUM" != "1" ] && [ "$(shasum "$2")" != "$1  $2" ]; then
        >&2 echo "line $ln: checksum failed"; exit 1
    fi 
}

# proc processes a single .package directive
proc() {
    if [ "$1" == "import" ] || [ "$1" == "file" ] || [ "$1" == "sum" ]; then
        $(echo "$@")
    else
        >&2 echo "line $ln: unknown directive: $1"; exit 1
    fi
}

# the main routine
if [ "$cmd" == "clean" ] && [ "$2" != "inner" ]; then
    n=0
    NOSUM=1 $self clean inner | while read fname ; do 
        if [ -f "$fname" ]; then
            >&2 echo "[del] $(rname $fname)"
            rm -f $fname
            n=$(expr $n + 1)
        fi
        pardir=$(dirname "$fname")
        if [ -d "$pardir" ] && [ -z "$(ls -A $pardir)" ]; then
            tdir=$(cd $pardir && pwd)
            >&2 echo "[del] $(rname $tdir)/"
            rmdir $tdir
        fi
    done
    >&2 echo "[yay] all clean"
elif [ "$cmd" == "sum" ]; then
    if [ "$2" != "-y" ]; then
        printf "Checksum .package? "
        read pie
        if [[ ! $pie == y* ]]; then
            echo Aborted
            exit
        fi
    fi
    NOSUM=1 $self import inner
    NOSUM=1 $self clean inner | while read fname ; do 
        fname=$(rname "$fname")
        >&2 echo "[sum] $fname"
        echo "sum $(shasum "$fname")" >> $tmpdir/sums
    done
    cat .package | sed '/^[ \t]*sum*[ \t]/d' > $tmpdir/.package
    cat $tmpdir/sums >> $tmpdir/.package
    mv $tmpdir/.package .package
    >&2 echo "[yay] checksums complete"    
elif [ "$1" == "import" ] || [ "$1" == "clean" ]; then
    # loop over each line in .package and process the local directives
    cat .package >> /dev/null
    echo "" | cat .package - | while read line ; do 
        ln=$(expr $ln + 1)
        $(echo $line | sed 's:#.*$::g; /^[[:space:]]*$/d; s/^/proc /')
    done
    rm -rf "$tmpdir"
    if [ "$2" != "inner" ]; then
        >&2 echo "[yay] import complete"
    fi
else
    >&2 echo "usage pkg.sh [command] [options]"
    >&2 echo ""
    >&2 echo "Commands:"
    >&2 echo "   import    Import files from .package into working directory"
    >&2 echo "   sum       Add checksums to .package"
    >&2 echo "   clean     Remove all imported files"
    >&2 echo ""
    >&2 echo "Examples:"
    >&2 echo "   pkg.sh import   # import files"
    >&2 echo "   pkg.sh sum      # generate checksums"
    >&2 echo "   pkg.sh sum -y   # generate checksums and ignore prompt"
    >&2 echo "   pkg.sh clean    # remove all imports"
    >&2 echo ""
    >&2 echo "Documentation can be found at https://github.com/tidwall/pkg.sh"
    exit 1
fi
