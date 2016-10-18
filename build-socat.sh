#!/bin/bash

set -o pipefail
set -ex

MUSL_VERSION=1.1.10
SOCAT_VERSION=1.7.3.0
NCURSES_VERSION=5.9
READLINE_VERSION=6.3
OPENSSL_VERSION=1.0.2h

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
    download "http://www.musl-libc.org/releases/musl-${MUSL_VERSION}.tar.gz" "musl-${MUSL_VERSION}.tar.gz"
    download "http://invisible-island.net/datafiles/release/ncurses.tar.gz"  "ncurses-${NCURSES_VERSION}.tar.gz"
    download "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" "openssl-${OPENSSL_VERSION}.tar.gz"
    download "http://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz" "readline-${READLINE_VERSION}.tar.gz"
    download "http://www.dest-unreach.org/socat/download/socat-${SOCAT_VERSION}.tar.gz" "socat-${SOCAT_VERSION}.tar.gz"
}

function build_musl() 
{
    tar xf /distfiles/musl-${MUSL_VERSION}.tar.gz -C /build/
    cd /build/musl-${MUSL_VERSION}

    # Build
    ./configure -q
    make -j4
    make install
}

function build_ncurses() 
{
    tar xf /distfiles/ncurses-${NCURSES_VERSION}.tar.gz -C /build/
    cd /build/ncurses-${NCURSES_VERSION}

    # Build
    CC='/usr/local/musl/bin/musl-gcc -static' CFLAGS='-fPIC' ./configure -q \
        --disable-shared \
        --enable-static
}

function build_readline() 
{
    tar xf /distfiles/readline-${READLINE_VERSION}.tar.gz -C /build/
    cd /build/readline-${READLINE_VERSION}

    # Build
    CC='/usr/local/musl/bin/musl-gcc -static' CFLAGS='-fPIC' ./configure -q \
        --disable-shared \
        --enable-static
    make -j4

    # Note that socat looks for readline in <readline/readline.h>, so we need
    # that directory to exist.
    ln -s /build/readline-${READLINE_VERSION} /build/readline
}

function build_openssl() 
{
    tar xf /distfiles/openssl-${OPENSSL_VERSION}.tar.gz -C /build/
    cd /build/openssl-${OPENSSL_VERSION}

    # Configure
    CC='/usr/local/musl/bin/musl-gcc -static' ./configure -q no-shared linux-x86_64

    # Build
    make
    echo "** Finished building OpenSSL"
}

function build_socat() 
{
    tar xf /distfiles/socat-${SOCAT_VERSION}.tar.gz -C /build/
    cd /build/socat-${SOCAT_VERSION}

    # Build
    # NOTE: `NETDB_INTERNAL` is non-POSIX, and thus not defined by MUSL.
    # We define it this way manually.
    CC='/usr/local/musl/bin/musl-gcc -static' \
        CFLAGS="-fPIC -DWITH_OPENSSL -I/build -I/build/openssl-${OPENSSL_VERSION}/include -DNETDB_INTERNAL=-1" \
        CPPFLAGS="-DWITH_OPENSSL -I/build -I/build/openssl-${OPENSSL_VERSION}/include -DNETDB_INTERNAL=-1" \
        LDFLAGS="-L/build/readline-${READLINE_VERSION} -L/build/ncurses-${NCURSES_VERSION}/lib -L/build/openssl-${OPENSSL_VERSION}" \
        ./configure -q --prefix /output/socat/
    make -j4
    strip socat
    make install
}

init
prepare

build_musl
build_ncurses
build_readline
build_openssl
build_socat

cp /build/socat-${SOCAT_VERSION}/socat /output/
ls -lh /output/socat

