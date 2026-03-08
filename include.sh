#!/usr/bin/env bash

MOD_PARAGON_ITEMGEN_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/" && pwd )"

source "$MOD_PARAGON_ITEMGEN_ROOT/conf/conf.sh.dist"

if [ -f "$MOD_PARAGON_ITEMGEN_ROOT/conf/conf.sh" ]; then
    source "$MOD_PARAGON_ITEMGEN_ROOT/conf/conf.sh"
fi
