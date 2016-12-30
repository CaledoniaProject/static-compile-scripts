#!/bin/bash

set -o pipefail
set -ex

basedir=/root/static-compile-scripts/

openssl_version=1.0.2j
nmap_version=7.40
musl_version=1.1.10
ncurses_version=5.9
readline_version=6.3

function init()
{
    mkdir -p "$basedir"/{build,output,distfiles}
}

function download()
{
    wget "$1" --no-check-certificate -c -O "$basedir/distfiles/$2"
}

function build_openssl() 
{
    if [[ -f "${basedir}/build/openssl-${openssl_version}/libssl.a" ]]; then
        echo OpenSSL already built
        return
    fi

    download "https://www.openssl.org/source/openssl-${openssl_version}.tar.gz" "openssl-${openssl_version}.tar.gz"

    tar xvf "$basedir"/distfiles/openssl-${openssl_version}.tar.gz -C "$basedir"/build/
    cd "$basedir"/build/openssl-${openssl_version}

    # Configure
    CC='/usr/local/musl/bin/musl-gcc -static' ./Configure -q no-shared linux-x86_64

    # Build
    make
    echo "** Finished building OpenSSL"
}

function build_ncurses()
{
    download "http://invisible-island.net/datafiles/release/ncurses.tar.gz"  "ncurses-${ncurses_version}.tar.gz"

    tar xf "$basedir"/distfiles/ncurses-${ncurses_version}.tar.gz -C "$basedir"/build/
    cd "$basedir"/build/ncurses-${ncurses_version}

    # Build
    CC='/usr/local/musl/bin/musl-gcc -static' CFLAGS='-fPIC' ./configure -q \
        --disable-shared \
        --enable-static
}

function build_readline()
{
    download "http://ftp.gnu.org/gnu/readline/readline-${readline_version}.tar.gz" "readline-${readline_version}.tar.gz"

    tar xf "$basedir"/distfiles/readline-${readline_version}.tar.gz -C "$basedir"/build/
    cd "$basedir"/build/readline-${readline_version}

    # Build
    CC='/usr/local/musl/bin/musl-gcc -static' CFLAGS='-fPIC' ./configure -q \
        --disable-shared \
        --enable-static
    make -j4

    # Note that socat looks for readline in <readline/readline.h>, so we need
    # that directory to exist.
    ln -s "$basedir"/build/readline-${readline_version} "$basedir"/build/readline
}

function build_musl() 
{
    if [[ -f /usr/local/musl/bin/musl-gcc ]]; then
        echo MUSL gcc already installed, skipping
        return
    fi

    download "http://www.musl-libc.org/releases/musl-${musl_version}.tar.gz" "musl-${musl_version}.tar.gz"

    tar xf "$basedir"/distfiles/musl-${musl_version}.tar.gz -C "$basedir"/build/
    cd "$basedir"/build/musl-${musl_version}

    # Build
    ./configure -q
    make -j4
    make install
}

function build_socat() 
{
    download "http://www.dest-unreach.org/socat/download/socat-${socat_version}.tar.gz" "socat-${socat_version}.tar.gz"

    tar xf /distfiles/socat-${SOCAT_VERSION}.tar.gz -C /build/
    cd /build/socat-${SOCAT_VERSION}

    # Build
    # NOTE: `NETDB_INTERNAL` is non-POSIX, and thus not defined by MUSL.
    # We define it this way manually.
    CC='/usr/local/musl/bin/musl-gcc -static' \
        CFLAGS="-fPIC -DWITH_OPENSSL -I${basedir}/build -I${basedir}/build/openssl-${openssl_version}/include -DNETDB_INTERNAL=-1" \
        CPPFLAGS="-DWITH_OPENSSL -I${basedir}/build -I${basedir}/build/openssl-${openssl_version}/include -DNETDB_INTERNAL=-1" \
        LDFLAGS="-L${basedir}/build/readline-${readline_version} -L${basedir}/build/ncurses-${ncurses_version}/lib -L${basedir}/build/openssl-${openssl_version}" \
        ./configure -q --prefix "$basedir"/output/socat/
    make -j4
    strip socat
    make install
}

function build_nmap()
{
    download "http://nmap.org/dist/nmap-${nmap_version}.tar.bz2"  "nmap-${nmap_version}.tar.bz2"

    tar xf "$basedir"/distfiles/nmap-${nmap_version}.tar.bz2 -C "$basedir"/build/
    cd "$basedir"/build/nmap-${nmap_version}

    # Configure
    CC="gcc -static -fPIC -DLUA_C89_NUMBERS" \
    CXX="g++ -static -static-libstdc++ -fPIC -DLUA_C89_NUMBERS" \
    LD=ld \
    LDFLAGS="-L$basedir/build/openssl-${openssl_version}" \
    ./configure \
       -q \
       --without-ndiff \
       --without-zenmap \
       --without-nping \
       --without-ncat \
       --without-nmap-update \
       --with-pcap=linux \
       --with-openssl="$basedir/build/openssl-${openssl_version}" \
       --prefix "$basedir/output/nmap/"

    # Don't build the libpcap.so file
    sed -i -e 's/shared\: /shared\: #/' libpcap/Makefile

    # Build
    make -j4
    strip nmap
    make install
}

init
