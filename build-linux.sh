#!/bin/bash

# Shell script
# Copyright (C) 2015  Unreal Arena
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Build all the external dependencies needed for Unreal Arena on Linux.


# Arguments parsing
if [ $# -eq 1 -a "${1}" == "-v" ]; then
	VERBOSE=1
elif [ $# -gt 0 ]; then
	echo "Usage: ${0} [-v]"
	exit 1
fi

# Enable exit on error
set -e


# Setup ------------------------------------------------------------------------

# Dependencies version
DEPS_VERSION=4

# Libraries versions
CURL_VERSION=7.43.0
FREETYPE_VERSION=2.6
GEOIP_VERSION=1.6.4
GLEW_VERSION=1.12.0
GMP_VERSION=6.0.0
JPEG_VERSION=1.4.1
LUA_VERSION=5.3.1
NACLSDK_VERSION=44.0.2403.155
NCURSES_VERSION=5.9
NETTLE_VERSION=3.1.1
OGG_VERSION=1.3.2
OPENAL_VERSION=1.16.0
OPUSFILE_VERSION=0.6
OPUS_VERSION=1.1
PNG_VERSION=1.6.18
SDL2_VERSION=2.0.3
SPEEX_VERSION=1.2rc1
THEORA_VERSION=1.1.1
VORBIS_VERSION=1.3.5
WEBP_VERSION=0.4.3
ZLIB_VERSION=1.2.8

# Build environment
ROOTDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CACHEDIR="${ROOTDIR}/cache"
BUILDDIR="${ROOTDIR}/build-linux-${DEPS_VERSION}"
DESTDIR="${ROOTDIR}/linux64-${DEPS_VERSION}"
mkdir -p "${CACHEDIR}"
mkdir -p "${BUILDDIR}"
rm -rf "${DESTDIR}"
mkdir -p "${DESTDIR}"

# Compiler
export CHOST="x86_64-unknown-linux-gnu"
export CFLAGS="-m64 -fPIC -Os -pipe"  # -fPIC is needed for 64-bit static libraries
export CXXFLAGS="-m64 -fPIC -Os -pipe"  # -fPIC is needed for 64-bit static libraries
export CPPFLAGS="${CPPFLAGS:-} -I${DESTDIR}/include"
export LDFLAGS="${LDFLAGS:-} -L${DESTDIR}/lib -L${DESTDIR}/lib64"
export PATH="${DESTDIR}/bin:${PATH}"
export PKG_CONFIG_PATH="${DESTDIR}/lib/pkgconfig:${DESTDIR}/lib64/pkgconfig:${PKG_CONFIG_PATH}"

# Limit parallel jobs to avoid being killed when on Travis CI
export MAKEFLAGS="-j$(($(nproc)<8?$(nproc):8))"


# Utilities --------------------------------------------------------------------

# Download a package (if it is not in the cache) and extract it
# Usage: _get <URL>
_get() {
	URL="${1}"
	FILENAME="$(basename "${URL}")"

	# Download
	echo "Downloading ${FILENAME} ..."
	if [ ! -f "${CACHEDIR}/${FILENAME}" ]; then
		wget -qcO "${CACHEDIR}/${FILENAME}" "${URL}"
	fi

	# Extract
	echo "Extracting ${FILENAME} ..."
	case "${FILENAME}" in
		*.tar.bz2|*.tar.gz|*.tgz)
			tar xf "${CACHEDIR}/${FILENAME}" -C "${BUILDDIR}" --recursive-unlink
			;;
		# *.zip)
		# 	rm -rf "${BUILDDIR}/${FILENAME%.zip}"
		# 	unzip -q "${CACHEDIR}/${FILENAME}" -d "${BUILDDIR}"
		# 	;;
		*)
			echo "Error: unknown archive type (${FILENAME})"
			exit 1
			;;
	esac
}

# Change to the library directory
# Usage: _cd <LIBDIR>
_cd() {
	LIBDIR="${1}"

	cd "${BUILDDIR}/${LIBDIR}"
}

# Notify the beginning of the prepare stage
# Usage: _prepare <LIBNAME>
_prepare() {
	LIBNAME="${1}"

	echo "Preparing ${LIBNAME} ..."
}

# Prepare for build
# Usage: _configure <LIBNAME> <OPTIONS>
_configure() {
	LIBNAME="${1}"
	OPTIONS="${2}"

	if [ $VERBOSE ]; then
		./configure --prefix="${DESTDIR}" ${OPTIONS}
	else
		./configure --prefix="${DESTDIR}" ${OPTIONS} &> /dev/null
	fi
}

# Build a package
# Usage: _build <LIBNAME>
_build() {
	LIBNAME="${1}"

	echo "Building ${LIBNAME} ..."

	if [ $VERBOSE ]; then
		make
	else
		make &> /dev/null
	fi
}

# Install a package
# Usage: _install <LIBNAME>
_install() {
	LIBNAME="${1}"

	echo "Installing ${LIBNAME} ..."

	if [ $VERBOSE ]; then
		make install
	else
		make install &> /dev/null
	fi
}

# Notify successful library installation
# Usage: _done
_done() {
	echo "Done!"
}


# Routines ---------------------------------------------------------------------

# Build curl
build_curl() {
	LIBNAME="curl"

	_get "http://curl.haxx.se/download/curl-${CURL_VERSION}.tar.bz2"
	_cd "curl-${CURL_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared --disable-ldap --without-ssl --without-libssh2 --without-librtmp --without-libidn"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/curl"*
	rm -rf "${DESTDIR}/lib/libcurl.la"
	rm -rf "${DESTDIR}/share/aclocal/libcurl.m4"
	rm -rf "${DESTDIR}/share/man/man1/curl"*
	rm -rf "${DESTDIR}/share/man/man3/curl"*
	rm -rf "${DESTDIR}/share/man/man3/CURL"*
	rm -rf "${DESTDIR}/share/man/man3/libcurl"*

	_done
}

# Build FreeType
build_freetype() {
	LIBNAME="FreeType"

	_get "http://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.bz2"
	_cd "freetype-${FREETYPE_VERSION}"
	_prepare "${LIBNAME}"

	sed -i  -e "/AUX.*.gxvalid/s@^# @@" -e "/AUX.*.otvalid/s@^# @@" modules.cfg
	# sed -ri -e 's:.*(#.*SUBPIXEL.*) .*:\1:' include/config/ftoption.h

	_configure "${LIBNAME}" "--disable-shared --without-bzip2 --without-png --without-harfbuzz"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/freetype-config"
	rm -rf "${DESTDIR}/lib/libfreetype.la"
	rm -rf "${DESTDIR}/share/aclocal/freetype2.m4"
	rm -rf "${DESTDIR}/share/man/man1/freetype-config.1"

	_done
}

# Build GeoIP
build_geoip() {
	LIBNAME="GeoIP"

	_get "https://github.com/maxmind/geoip-api-c/archive/v${GEOIP_VERSION}.tar.gz"
	_cd "geoip-api-c-${GEOIP_VERSION}"
	_prepare "${LIBNAME}"

	autoreconf -fi &> /dev/null

	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/geoiplookup"*
	rm -rf "${DESTDIR}/lib/libGeoIP.la"
	rm -rf "${DESTDIR}/share/man/man1/geoiplookup"*

	_done
}

# Build GLEW
build_glew() {
	LIBNAME="GLEW"

	_get "http://downloads.sourceforge.net/project/glew/glew/${GLEW_VERSION}/glew-${GLEW_VERSION}.tgz"
	_cd "glew-${GLEW_VERSION}"
	_prepare "${LIBNAME}"

	export GLEW_DEST="${DESTDIR}"

	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib64/libGLEW.so"*

	_done
}

# Build GMP
build_gmp() {
	LIBNAME="GMP"

	_get "https://gmplib.org/download/gmp/gmp-${GMP_VERSION}a.tar.bz2"
	_cd "gmp-${GMP_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libgmp.la"
	rm -rf "${DESTDIR}/share/info/dir"
	rm -rf "${DESTDIR}/share/info/gmp"*

	_done
}

# Build JPEG
build_jpeg() {
	LIBNAME="JPEG"

	_get "http://downloads.sourceforge.net/project/libjpeg-turbo/${JPEG_VERSION}/libjpeg-turbo-${JPEG_VERSION}.tar.gz"
	_cd "libjpeg-turbo-${JPEG_VERSION}"
	_prepare "${LIBNAME}"

	sed -i -e '/^docdir/ s:$:/libjpeg-turbo-1.4.1:' Makefile.in

	_configure "${LIBNAME}" "--mandir=${DESTDIR}/share/man --disable-shared --with-jpeg8 --without-turbojpeg"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/cjpeg"
	rm -rf "${DESTDIR}/bin/djpeg"
	rm -rf "${DESTDIR}/bin/jpegtran"
	rm -rf "${DESTDIR}/bin/rdjpgcom"
	rm -rf "${DESTDIR}/bin/wrjpgcom"
	rm -rf "${DESTDIR}/lib/libjpeg.la"
	rm -rf "${DESTDIR}/share/doc/libjpeg-turbo-1.4.1/"
	rm -rf "${DESTDIR}/share/man/man1/cjpeg.1"
	rm -rf "${DESTDIR}/share/man/man1/djpeg.1"
	rm -rf "${DESTDIR}/share/man/man1/jpegtran.1"
	rm -rf "${DESTDIR}/share/man/man1/rdjpgcom.1"
	rm -rf "${DESTDIR}/share/man/man1/wrjpgcom.1"

	_done
}

# Build Lua
build_lua() {
	LIBNAME="Lua"

	_get "http://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
	_cd "lua-${LUA_VERSION}"
	_prepare "${LIBNAME}"

	sed -i -e "/^PLAT=/s:none:linux:" -e "/^INSTALL_TOP=/s:/usr/local:${DESTDIR}:" Makefile

	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/lua"*
	rm -rf "${DESTDIR}/bin/luac"*
	rm -rf "${DESTDIR}/man/man1/lua.1"
	rm -rf "${DESTDIR}/man/man1/luac.1"

	_done
}

# Build NaCl Ports
build_naclports() {
	LIBNAME="NaCl Ports"

	_get "https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/${NACLSDK_VERSION}/naclports.tar.bz2"
	_cd "pepper_${NACLSDK_VERSION%%.*}"

	echo "Installing ${LIBNAME} ..."

	mkdir -p "${DESTDIR}/pnacl_deps/include"
	mkdir -p "${DESTDIR}/pnacl_deps/lib"

	cp -a "ports/include/"{lauxlib.h,luaconf.h,lua.h,lua.hpp,lualib.h} "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/freetype2" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/lib/newlib_pnacl/Release/"{libfreetype.a,liblua.a,libpng16.a,libpng.a} "${DESTDIR}/pnacl_deps/lib"

	_done
}

# Build NaCl SDK
build_naclsdk() {
	LIBNAME="NaCl SDK"

	_get "https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/${NACLSDK_VERSION}/naclsdk_linux.tar.bz2"
	_cd "pepper_${NACLSDK_VERSION%%.*}"

	echo "Installing ${LIBNAME} ..."

	cp -a "tools/sel_ldr_x86_64" "${DESTDIR}/sel_ldr"
	cp -a "tools/irt_core_x86_64.nexe" "${DESTDIR}/irt_core-x86_64.nexe"
	cp -a "tools/nacl_helper_bootstrap_x86_64" "${DESTDIR}/nacl_helper_bootstrap"
	# cp -a "toolchain/linux_x86_newlib/bin/x86_64-nacl-gdb" "${DESTDIR}/nacl-gdb"
	cp -a "toolchain/linux_pnacl" "${DESTDIR}/pnacl"

	rm -rf "${DESTDIR}/pnacl/arm-nacl"
	rm -rf "${DESTDIR}/pnacl/arm_bc-nacl"
	rm -rf "${DESTDIR}/pnacl/bin/"{arm,i686,x86_64}-nacl-*
	rm -rf "${DESTDIR}/pnacl/docs"
	rm -rf "${DESTDIR}/pnacl/FEATURE_VERSION"
	rm -rf "${DESTDIR}/pnacl/i686_bc-nacl"
	rm -rf "${DESTDIR}/pnacl/include"
	rm -rf "${DESTDIR}/pnacl/pnacl_newlib"*
	rm -rf "${DESTDIR}/pnacl/README"
	rm -rf "${DESTDIR}/pnacl/REV"
	rm -rf "${DESTDIR}/pnacl/share"
	rm -rf "${DESTDIR}/pnacl/x86_64-nacl"
	rm -rf "${DESTDIR}/pnacl/x86_64_bc-nacl"

	_done
}

# Build Ncurses
build_ncurses() {
	LIBNAME="Ncurses"

	_get "http://ftp.gnu.org/pub/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"
	_cd "ncurses-${NCURSES_VERSION}"
	_prepare "${LIBNAME}"

	wget -qcO "ncurses-5.9-gcc5_buildfixes-1.patch" "http://lfs-matrix.net/patches/lfs/development/ncurses-5.9-gcc5_buildfixes-1.patch"
	patch -sNp1 -i ncurses-5.9-gcc5_buildfixes-1.patch
	sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in

	_configure "${LIBNAME}" "--without-manpages --without-progs --without-tests --without-debug --enable-widec"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	ln -s "libncursesw.a" "${DESTDIR}/lib/libcursesw.a"
	rm -rf "${DESTDIR}/bin/ncursesw5-config"
	rm -rf "${DESTDIR}/lib/terminfo"
	rm -rf "${DESTDIR}/share/tabset"
	rm -rf "${DESTDIR}/share/terminfo"

	_done
}

# Build Nettle
build_nettle() {
	LIBNAME="Nettle"

	_get "http://www.lysator.liu.se/~nisse/archive/nettle-${NETTLE_VERSION}.tar.gz"
	_cd "nettle-${NETTLE_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared --disable-documentation"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/nettle"*
	rm -rf "${DESTDIR}/bin/pkcs1-conv"
	rm -rf "${DESTDIR}/bin/sexp-conv"

	_done
}

# Build Ogg
build_ogg() {
	LIBNAME="Ogg"

	_get "http://downloads.xiph.org/releases/ogg/libogg-${OGG_VERSION}.tar.gz"
	_cd "libogg-${OGG_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libogg.la"
	rm -rf "${DESTDIR}/share/aclocal/ogg.m4"
	rm -rf "${DESTDIR}/share/doc/libogg/"

	_done
}

# Build OpenAL
build_openal() {
	LIBNAME="OpenAL"

	_get "http://kcat.strangesoft.net/openal-releases/openal-soft-${OPENAL_VERSION}.tar.bz2"
	_cd "openal-soft-${OPENAL_VERSION}"
	_prepare "${LIBNAME}"

	if [ $VERBOSE ]; then
		cmake -DCMAKE_INSTALL_PREFIX="${DESTDIR}" -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF
	else
		cmake -DCMAKE_INSTALL_PREFIX="${DESTDIR}" -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF &> /dev/null
	fi

	_build "${LIBNAME}"
	_install "${LIBNAME}"

	echo -ne "create libopenal.pre.a\naddlib libopenal.a\naddlib libcommon.a\nsave\nend\n" | ar -M
	cp -f libopenal.pre.a "${DESTDIR}/lib/libopenal.a"
	rm -rf "${DESTDIR}/share/openal"

	_done
}

# Build Opus
build_opus() {
	LIBNAME="Opus"

	_get "http://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz"
	_cd "opus-${OPUS_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared --disable-extra-programs --disable-doc"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libopus.la"
	rm -rf "${DESTDIR}/share/aclocal/opus.m4"

	_done
}

# Build Opusfile
build_opusfile() {
	LIBNAME="Opusfile"

	_get "http://downloads.xiph.org/releases/opus/opusfile-${OPUSFILE_VERSION}.tar.gz"
	_cd "opusfile-${OPUSFILE_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared --disable-http --disable-doc"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libopusfile.la"
	rm -rf "${DESTDIR}/lib/libopusurl.la"
	rm -rf "${DESTDIR}/share/doc/opusfile"

	_done
}

# Build PNG
build_png() {
	LIBNAME="PNG"

	_get "http://download.sourceforge.net/libpng/libpng-${PNG_VERSION}.tar.gz"
	_cd "libpng-${PNG_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/libpng"*
	rm -rf "${DESTDIR}/bin/png"*
	rm -rf "${DESTDIR}/lib/libpng.la"
	rm -rf "${DESTDIR}/lib/libpng16.la"
	rm -rf "${DESTDIR}/lib/pkgconfig/libpng"*
	rm -rf "${DESTDIR}/share/man/man3/libpng"*
	rm -rf "${DESTDIR}/share/man/man5/png.5"

	_done
}

# Build SDL2
build_sdl2() {
	LIBNAME="SDL2"

	_get "https://www.libsdl.org/release/SDL2-${SDL2_VERSION}.tar.gz"
	_cd "SDL2-${SDL2_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared --disable-alsatest"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/sdl2-config"
	rm -rf "${DESTDIR}/lib/libSDL2.la"
	rm -rf "${DESTDIR}/share/aclocal/sdl2.m4"

	_done
}

# Build Speex
build_speex() {
	LIBNAME="Speex"

	_get "http://downloads.xiph.org/releases/speex/speex-${SPEEX_VERSION}.tar.gz"
	_cd "speex-${SPEEX_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/speex"*
	rm -rf "${DESTDIR}/lib/libspeex.la"
	rm -rf "${DESTDIR}/lib/libspeexdsp.la"
	rm -rf "${DESTDIR}/share/aclocal/speex.m4"
	rm -rf "${DESTDIR}/share/doc/speex"
	rm -rf "${DESTDIR}/share/man/man1/speex"*

	_done
}

# Build Theora
build_theora() {
	LIBNAME="Theora"

	_get "http://downloads.xiph.org/releases/theora/libtheora-${THEORA_VERSION}.tar.bz2"
	_cd "libtheora-${THEORA_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared --disable-encode --disable-examples"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libtheoradec.la"
	rm -rf "${DESTDIR}/lib/libtheoraenc.la"
	rm -rf "${DESTDIR}/lib/libtheora.la"
	rm -rf "${DESTDIR}/lib/pkgconfig/theora"*
	rm -rf "${DESTDIR}/share/doc/libtheora-1.1.1"

	_done
}

# Build Vorbis
build_vorbis() {
	LIBNAME="Vorbis"

	_get "http://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz"
	_cd "libvorbis-${VORBIS_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libvorbisenc.la"
	rm -rf "${DESTDIR}/lib/libvorbisfile.la"
	rm -rf "${DESTDIR}/lib/libvorbis.la"
	rm -rf "${DESTDIR}/lib/pkgconfig/vorbis"*
	rm -rf "${DESTDIR}/share/aclocal/vorbis.m4"
	rm -rf "${DESTDIR}/share/doc/libvorbis-1.3.5/"

	_done
}

# Build WebP
build_webp() {
	LIBNAME="WebP"

	_get "http://downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz"
	_cd "libwebp-${WEBP_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--disable-shared"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/cwebp"
	rm -rf "${DESTDIR}/bin/dwebp"
	rm -rf "${DESTDIR}/lib/libwebp.la"
	rm -rf "${DESTDIR}/share/man/man1/cwebp.1"
	rm -rf "${DESTDIR}/share/man/man1/dwebp.1"

	_done
}

# Build zlib
build_zlib() {
	LIBNAME="zlib"

	_get "http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz"
	_cd "zlib-${ZLIB_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" "--const --static"
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/share/man/man3/zlib.3"

	_done
}


# Main -------------------------------------------------------------------------

build_curl
build_freetype
build_geoip
build_glew
build_gmp
build_jpeg  # [deps: nasm]
build_lua
build_naclports
build_naclsdk
build_ncurses
build_nettle  # [deps: gmp]
build_ogg
build_openal
build_opus
build_opusfile  # [deps: ogg, opus]
build_png
build_sdl2
build_speex  # [deps: ogg]
build_vorbis  # [deps: ogg]
build_theora  # [deps: ogg, vorbis, png]
build_webp
# build_zlib