#!/bin/sh
set -e
export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1

platform="$(uname -s)"
platform_arch="$(uname -m)"

if [ -x "$(which apk 2>/dev/null)" ]
    then
        apk add --no-cache git gcc make musl-dev autoconf automake libtool ninja \
            linux-headers bash meson cmake pkgconfig libcap-static libcap-dev \
            libselinux-dev libxslt bash-completion xz
fi

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [ -d release ]
    then
        echo "= removing previous release directory"
        rm -rf release
fi

# create build and release directory
mkdir build
mkdir release
cd build

# download bubblewrap
git clone https://github.com/containers/bubblewrap.git
bubblewrap_version="$(cd bubblewrap && git describe --long --tags|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
mv bubblewrap "bubblewrap-${bubblewrap_version}"
echo "= downloading bubblewrap v${bubblewrap_version}"

if [ "$platform" == "Linux" ]
    then
        export CFLAGS="-static"
        export LDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building bubblewrap"
cd bubblewrap-${bubblewrap_version}
meson build
ninja -C build bwrap.p/bubblewrap.c.o bwrap.p/bind-mount.c.o bwrap.p/network.c.o bwrap.p/utils.c.o
(
cd build && \
cc -o bwrap bwrap.p/bubblewrap.c.o bwrap.p/bind-mount.c.o bwrap.p/network.c.o bwrap.p/utils.c.o \
    -static -L/usr/lib -lcap -lselinux
)
cd ../..

echo "= extracting bubblewrap binary"
mv build/bubblewrap-${bubblewrap_version}/build/bwrap release 2>/dev/null

echo "= striptease"
strip -s -R .comment -R .gnu.version --strip-unneeded release/bwrap 2>/dev/null

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        upx -9 --best release/bwrap 2>/dev/null
fi

echo "= create release tar.xz"
tar --xz -acf bubblewrap-static-v${bubblewrap_version}-${platform_arch}.tar.xz release
# cp bubblewrap-static-*.tar.xz ~/ 2>/dev/null

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release build
fi

echo "= bubblewrap v${bubblewrap_version} done"
