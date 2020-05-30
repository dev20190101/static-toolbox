#!/bin/bash
#set -e
set -o pipefail
set -x
NMAP_COMMIT=

build_musl() {
    if [ ! -f "/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-gcc" ];then
        git clone https://github.com/dev20190101/musl-cross.git /build/musl
        cd /build/musl
        git clean -fdx
        ./build.sh
        echo "[+] Finished building musl-cross x86_64"
	fi
}

build_openssl() {
    if [ ! -f "/build/openssl/apps/openssl" ];then
        git clone -b OpenSSL_1_0_2-stable https://github.com/dev20190101/openssl.git /build/openssl
        cd /build/openssl
        git clean -fdx
        make clean
        CC='/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-gcc -static' ./Configure no-shared linux-x86_64
        make -j4
        echo "[+] Finished building OpenSSL x86_64"
    fi
}

build_ncat() {
    if [ ! -d "/build/nmap" ];then
        git clone https://github.com/dev20190101/nmap.git /build/nmap
    fi
	
    cd /build/nmap
    git clean -fdx
    make clean
    cd /build/nmap/libz
    CC='/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-gcc -static -fPIC' \
        CXX='/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-g++ -static -static-libstdc++ -fPIC' \
        cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_LINKER=/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-ld .
    make zlibstatic
    cd /build/nmap
    CC='/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-gcc -static -fPIC' \
        CXX='/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-g++ -static -static-libstdc++ -fPIC' \
        CXXFLAGS="-I/build/nmap/libz" \
        LD=/opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-ld \
        LDFLAGS="-L/build/openssl -L/build/nmap/libz" \
        ./configure \
            --without-ndiff \
            --without-PACKAGE \
            --without-ndiff \
            --without-nping \
            --without-liblua \
            --without-zenmap \
            --without-nmap-update \
            --without-libssh2 \
            --with-pcap=linux \
            --with-libz=/build/nmap/libz \
            --with-openssl=/build/openssl
    sed -i -e 's/shared\: /shared\: #/' libpcap/Makefile
    sed -i 's|LIBS = |& libz/libz.a |' Makefile
    sed -i 's/all: .*/all:  $(BUILDNCAT)/' Makefile
    make -j4
    /opt/cross/x86_64-linux-musl/bin/x86_64-linux-musl-strip ncat/ncat
}

build_x86_64(){

    build_musl
    build_openssl
    build_ncat
    if [ ! -f "/build/nmap/ncat/ncat" ];then
        echo "[-] Building Nmap x86_64 failed!"
        exit 1
    fi
    echo "[+] /build/nmap/ncat/ncat "
    echo "[+] Finished building x86_64"
}

main() {
    if [ -n "$(command -v yum)" ];then
        yum update && \
        yum -y groupinstall 'Development Tools' && \
        yum -y install epel-release
        yum -y install cmake gmp-devel mpfr-devel libmpc-devel wget automake checkinstall pkg-config python
    fi

    if [ -n "$(command -v apt-get)" ];then
        apt-get update && \
        apt upgrade -yy && \
        apt install -yy automake cmake build-essential checkinstall libgmp-dev libmpfr-dev libmpc-dev wget git pkg-config python
    fi
    fetch
    build_x86_64
}

main

