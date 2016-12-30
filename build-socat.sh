#!/bin/bash

cd "$(dirname "$0")"
source functions.sh

build_musl
build_ncurses
build_readline
build_openssl
build_socat