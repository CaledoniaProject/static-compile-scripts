#!/bin/bash

set -o pipefail
set -ex

OPENSSL_VERSION=1.0.2h
NMAP_VERSION=7.30

function init()
{
    mkdir -p /build/ /output/ /distfiles/
}

function download()
{
    wget "$1" -O /distfiles/"$2"
}

function prepare()
{
    download "http://nmap.org/dist/nmap-${NMAP_VERSION}.tar.bz2"  "nmap-${NMAP_VERSION}.tar.bz2"
    download "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" "openssl-${OPENSSL_VERSION}.tar.gz"
}

function build_openssl() 
{
    tar xvf /distfiles/openssl-${OPENSSL_VERSION}.tar.gz -C /build/
    cd /build/openssl-${OPENSSL_VERSION}

    # Configure
    CC='/usr/local/musl/bin/musl-gcc -static' ./configure -q no-shared linux-x86_64

    # Build
    make
    echo "** Finished building OpenSSL"
}

function build_nmap()
{
    tar xf /distfiles/nmap-${NMAP_VERSION}.tar.bz2 -C /build/
    cd /build/nmap-${NMAP_VERSION}

    # Configure
    CC='gcc -static -fPIC -DLUA_C89_NUMBERS' \
        CXX='g++ -static -static-libstdc++ -fPIC -DLUA_C89_NUMBERS' \
        LD=ld \
        LDFLAGS="-L/build/openssl-${OPENSSL_VERSION}"   \
        ./configure \
            -q \
            --without-ndiff \
            --without-zenmap \
            --without-nmap-update \
            --with-pcap=linux \
            --with-openssl=/build/openssl-${OPENSSL_VERSION} \
            --prefix /output/nmap/

    # Don't build the libpcap.so file
    sed -i -e 's/shared\: /shared\: #/' libpcap/Makefile

    # Build
    make -j4
    strip nmap ncat/ncat nping/nping
    make install
}

init
prepare
build_nmap

