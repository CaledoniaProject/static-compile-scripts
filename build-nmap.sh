#!/bin/bash

cd "$(dirname "$0")"
source functions.sh

build_musl
build_openssl
build_nmap
