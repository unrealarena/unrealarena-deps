#!/bin/bash

# Copyright (C) 2015-2016  Unreal Arena
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

# Build all the external dependencies needed by Unreal Arena on OS X.


################################################################################
# Setup
################################################################################

# Arguments parsing
if [ $# -gt 0 ]; then
	if [ $# -eq 1 -a "${1}" == "-v" ]; then
		VERBOSE=1
	else
		echo "Usage: ${0} [-v]"
		exit 1
	fi
fi

# Enable exit on error
set -e

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
NASM_VERSION=2.11.08
NETTLE_VERSION=3.1.1
OGG_VERSION=1.3.2
OPENAL_VERSION=1.16.0
OPUSFILE_VERSION=0.6
OPUS_VERSION=1.1
PNG_VERSION=1.6.18
PKGCONFIG_VERSION=0.28
SDL2_VERSION=2.0.3
SPEEX_VERSION=1.2rc2  # 1.2rc1
THEORA_VERSION=1.1.1
VORBIS_VERSION=1.3.5
WEBP_VERSION=0.4.3
ZLIB_VERSION=1.2.8

# Build environment
ROOTDIR="$(dirname "$(greadlink -f "${BASH_SOURCE[0]}")")"
CACHEDIR="${ROOTDIR}/cache"
BUILDDIR="${ROOTDIR}/build"
DESTDIR="${ROOTDIR}/osx-${DEPS_VERSION}"
mkdir -p "${CACHEDIR}"
mkdir -p "${BUILDDIR}"
rm -rf "${DESTDIR}"
mkdir -p "${DESTDIR}"

# Compiler
export HOST="x86_64-apple-darwin"
export CFLAGS="-arch x86_64 -O2"
export CXXFLAGS="-arch x86_64 -O2"
export CPPFLAGS="${CPPFLAGS:-} -I${DESTDIR}/include"
export LDFLAGS="${LDFLAGS:-} -L${DESTDIR}/lib"
export PATH="${DESTDIR}/bin:${PATH}"
export PKG_CONFIG_PATH="${DESTDIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export CMAKE_OSX_ARCHITECTURES="x86_64"
export CMAKE_OSX_DEPLOYMENT_TARGET="10.9"
export CMAKE_BUILD_TYPE="Release"

# Limit parallel jobs to avoid being killed when on Travis CI
export MAKEFLAGS="-j$(($(sysctl -n hw.ncpu)<8?$(sysctl -n hw.ncpu):8))"


################################################################################
# Utilities
################################################################################

# Enable quiet mode
# Usage: _begin_quiet
_begin_quiet() {
	exec 3>&1
	exec 4>&2
	exec &> /dev/null
}

# Disable quiet mode
# Usage: _end_quiet
_end_quiet() {
	exec 1>&3 3>&-
	exec 2>&4 4>&-
}

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
		*.dmg)
			rm -rf "${BUILDDIR}/${FILENAME%.dmg}"
			mkdir -p "${BUILDDIR}/${FILENAME%.dmg}"
			mkdir -p "${BUILDDIR}/mnt"
			hdiutil attach -quiet -mountpoint "${BUILDDIR}/mnt" "${CACHEDIR}/${FILENAME}"
			cp -a "${BUILDDIR}/mnt/"* "${BUILDDIR}/${FILENAME%.dmg}"
			hdiutil detach -quiet "${BUILDDIR}/mnt"
			rmdir "${BUILDDIR}/mnt"
			;;
		*.tar.bz2|*.tar.gz|*.tgz)
			gtar xf "${CACHEDIR}/${FILENAME}" -C "${BUILDDIR}" --recursive-unlink
			;;
		*.zip)
			rm -rf "${BUILDDIR}/${FILENAME%.zip}"
			unzip -q "${CACHEDIR}/${FILENAME}" -d "${BUILDDIR}"
			;;
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

# Prepare for build (configure)
# Usage: _configure <LIBNAME> <OPTIONS>
_configure() {
	LIBNAME="${1}"
	OPTIONS="${@:2}"

	[[ $VERBOSE ]] || _begin_quiet

	./configure --build="${HOST}"\
	            --prefix="${DESTDIR}"\
	            ${OPTIONS}

	[[ $VERBOSE ]] || _end_quiet
}

# Prepare for build (cmake)
# Usage: _cmake <LIBNAME> <OPTIONS>
_cmake() {
	LIBNAME="${1}"
	OPTIONS="${@:2}"

	[[ $VERBOSE ]] || _begin_quiet

	cmake -DCMAKE_OSX_ARCHITECTURES="${CMAKE_OSX_ARCHITECTURES}"\
	      -DCMAKE_OSX_DEPLOYMENT_TARGET="${CMAKE_OSX_DEPLOYMENT_TARGET}"\
	      -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"\
	      -DCMAKE_INSTALL_PREFIX="${DESTDIR}"\
	      ${OPTIONS}

	[[ $VERBOSE ]] || _end_quiet
}

# Build a package
# Usage: _build <LIBNAME>
_build() {
	LIBNAME="${1}"

	echo "Building ${LIBNAME} ..."

	[[ $VERBOSE ]] || _begin_quiet

	make

	[[ $VERBOSE ]] || _end_quiet
}

# Install a package
# Usage: _install <LIBNAME>
_install() {
	LIBNAME="${1}"

	echo "Installing ${LIBNAME} ..."

	[[ $VERBOSE ]] || _begin_quiet

	make install

	[[ $VERBOSE ]] || _end_quiet
}

# Notify successful library installation
# Usage: _done
_done() {
	echo "Done!"
}


################################################################################
# Routines
################################################################################

# Build curl
build_curl() {
	LIBNAME="curl"

	_get "http://curl.haxx.se/download/curl-${CURL_VERSION}.tar.bz2"
	_cd "curl-${CURL_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared\
	                        --disable-ldap\
	                        --without-ssl\
	                        --without-libssh2\
	                        --without-librtmp\
	                        --without-libidn
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

	gsed -i -e "/AUX.*.gxvalid/s@^# @@" -e "/AUX.*.otvalid/s@^# @@" modules.cfg
	# gsed -ri -e 's:.*(#.*SUBPIXEL.*) .*:\1:' include/config/ftoption.h

	_configure "${LIBNAME}" --disable-shared\
	                        --without-bzip2\
	                        --without-png\
	                        --without-harfbuzz
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

	_configure "${LIBNAME}" --disable-shared
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

	install_name_tool -id "@rpath/libGLEW.${GLEW_VERSION}.dylib" "${DESTDIR}/lib/libGLEW.${GLEW_VERSION}.dylib"

	rm -rf "${DESTDIR}/lib/libGLEW.a"

	_done
}

# Build GMP
build_gmp() {
	LIBNAME="GMP"

	_get "https://gmplib.org/download/gmp/gmp-${GMP_VERSION}a.tar.bz2"
	_cd "gmp-${GMP_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared
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

	export NASM="${BUILDDIR}/nasm-${NASM_VERSION}/nasm"

	_get "http://downloads.sourceforge.net/project/libjpeg-turbo/${JPEG_VERSION}/libjpeg-turbo-${JPEG_VERSION}.tar.gz"
	_cd "libjpeg-turbo-${JPEG_VERSION}"
	_prepare "${LIBNAME}"

	gsed -i -e "/^docdir/ s:$:/libjpeg-turbo-${JPEG_VERSION}:" Makefile.in

	_configure "${LIBNAME}" "--mandir=${DESTDIR}/share/man"\
	                        --disable-shared\
	                        --with-jpeg8\
	                        --without-turbojpeg
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/cjpeg"
	rm -rf "${DESTDIR}/bin/djpeg"
	rm -rf "${DESTDIR}/bin/jpegtran"
	rm -rf "${DESTDIR}/bin/rdjpgcom"
	rm -rf "${DESTDIR}/bin/wrjpgcom"
	rm -rf "${DESTDIR}/lib/libjpeg.la"
	rm -rf "${DESTDIR}/share/doc/libjpeg-turbo-${JPEG_VERSION}"
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

	gsed -i -e "/^PLAT=/s:none:macosx:" -e "/^INSTALL_TOP=/s:/usr/local:${DESTDIR}:" Makefile

	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/lua"*
	rm -rf "${DESTDIR}/man/man1/lua"*

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

	cp -a "ports/include/freetype2" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/lauxlib.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/luaconf.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/lua.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/lua.hpp" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/lualib.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/png.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/pngconf.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/libpng16" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/include/pnglibconf.h" "${DESTDIR}/pnacl_deps/include"
	cp -a "ports/lib/newlib_pnacl/Release/libfreetype.a" "${DESTDIR}/pnacl_deps/lib"
	cp -a "ports/lib/newlib_pnacl/Release/liblua.a" "${DESTDIR}/pnacl_deps/lib"
	cp -a "ports/lib/newlib_pnacl/Release/libpng16.a" "${DESTDIR}/pnacl_deps/lib"
	cp -a "ports/lib/newlib_pnacl/Release/libpng.a" "${DESTDIR}/pnacl_deps/lib"

	_done
}

# Build NaCl SDK
build_naclsdk() {
	LIBNAME="NaCl SDK"

	_get "https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/${NACLSDK_VERSION}/naclsdk_mac.tar.bz2"
	_cd "pepper_${NACLSDK_VERSION%%.*}"

	echo "Installing ${LIBNAME} ..."

	cp -a "tools/sel_ldr_x86_64" "${DESTDIR}/sel_ldr"
	cp -a "tools/irt_core_x86_64.nexe" "${DESTDIR}/irt_core-x86_64.nexe"
	# cp -a "toolchain/mac_x86_newlib/bin/x86_64-nacl-gdb" "${DESTDIR}/nacl-gdb"
	cp -a "toolchain/mac_pnacl" "${DESTDIR}/pnacl"

	rm -rf "${DESTDIR}/pnacl/arm-nacl"
	rm -rf "${DESTDIR}/pnacl/arm_bc-nacl"
	rm -rf "${DESTDIR}/pnacl/bin/arm-nacl-"*
	rm -rf "${DESTDIR}/pnacl/bin/i686-nacl-"*
	rm -rf "${DESTDIR}/pnacl/bin/x86_64-nacl-"*
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

# Build NASM
build_nasm() {
	LIBNAME="NASM"

	_get "http://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/macosx/nasm-${NASM_VERSION}-macosx.zip"

	_done
}

# Build Nettle
build_nettle() {
	LIBNAME="Nettle"

	_get "http://www.lysator.liu.se/~nisse/archive/nettle-${NETTLE_VERSION}.tar.gz"
	_cd "nettle-${NETTLE_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared\
	                        --disable-documentation
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
	_configure "${LIBNAME}" --disable-shared
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libogg.la"
	rm -rf "${DESTDIR}/share/aclocal/ogg.m4"
	rm -rf "${DESTDIR}/share/doc/libogg"

	_done
}

# Build OpenAL
build_openal() {
	LIBNAME="OpenAL"

	_get "http://kcat.strangesoft.net/openal-releases/openal-soft-${OPENAL_VERSION}.tar.bz2"
	_cd "openal-soft-${OPENAL_VERSION}"
	_cmake "${LIBNAME}" -DALSOFT_UTILS=OFF\
	                    -DALSOFT_EXAMPLES=OFF
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	install_name_tool -id "@rpath/libopenal.${OPENAL_VERSION}.dylib" "${DESTDIR}/lib/libopenal.${OPENAL_VERSION}.dylib"

	rm -rf "${DESTDIR}/share/openal"

	_done
}

# Build Opus
build_opus() {
	LIBNAME="Opus"

	_get "http://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz"
	_cd "opus-${OPUS_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared\
	                        --disable-extra-programs\
	                        --disable-doc
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
	_configure "${LIBNAME}" --disable-shared\
	                        --disable-http\
	                        --disable-doc
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libopusfile.la"
	rm -rf "${DESTDIR}/lib/libopusurl.la"
	rm -rf "${DESTDIR}/share/doc/opusfile"

	_done
}

# Build pkg-config
build_pkgconfig() {
	LIBNAME="pkg-config"

	_get "http://pkgconfig.freedesktop.org/releases/pkg-config-${PKGCONFIG_VERSION}.tar.gz"
	_cd "pkg-config-${PKGCONFIG_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --with-internal-glib
	_build "${LIBNAME}"

	_done
}

# Build PNG
build_png() {
	LIBNAME="PNG"

	_get "http://download.sourceforge.net/libpng/libpng-${PNG_VERSION}.tar.gz"
	_cd "libpng-${PNG_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/libpng"*
	rm -rf "${DESTDIR}/bin/png"*
	rm -rf "${DESTDIR}/lib/libpng.la"
	rm -rf "${DESTDIR}/lib/libpng16.la"
	rm -rf "${DESTDIR}/share/man/man3/libpng"*
	rm -rf "${DESTDIR}/share/man/man5/png.5"

	_done
}

# Build SDL2
build_sdl2() {
	LIBNAME="SDL2"

	_get "http://libsdl.org/release/SDL2-${SDL2_VERSION}.dmg"
	_cd "SDL2-${SDL2_VERSION}"

	echo "Installing ${LIBNAME} ..."

	cp -a "SDL2.framework" "${DESTDIR}"

	_done
}

# Build Speex
build_speex() {
	LIBNAME="Speex"

	_get "http://downloads.xiph.org/releases/speex/speex-${SPEEX_VERSION}.tar.gz"
	_cd "speex-${SPEEX_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libspeex.la"
	rm -rf "${DESTDIR}/share/aclocal/speex.m4"
	rm -rf "${DESTDIR}/share/doc/speex/manual.pdf"

	_done
}

# Build Theora
build_theora() {
	LIBNAME="Theora"

	_get "http://downloads.xiph.org/releases/theora/libtheora-${THEORA_VERSION}.tar.bz2"
	_cd "libtheora-${THEORA_VERSION}"
	_prepare "${LIBNAME}"

	gsed -i -e "s/ -fforce-addr//" configure

	_configure "${LIBNAME}" --disable-shared\
	                        --disable-encode\
	                        --disable-examples
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libtheora.la"
	rm -rf "${DESTDIR}/lib/libtheoradec.la"
	rm -rf "${DESTDIR}/lib/libtheoraenc.la"
	rm -rf "${DESTDIR}/share/doc/libtheora-${THEORA_VERSION}"

	_done
}

# Build Vorbis
build_vorbis() {
	LIBNAME="Vorbis"

	_get "http://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz"
	_cd "libvorbis-${VORBIS_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/lib/libvorbis.la"
	rm -rf "${DESTDIR}/lib/libvorbisenc.la"
	rm -rf "${DESTDIR}/lib/libvorbisfile.la"
	rm -rf "${DESTDIR}/share/aclocal/vorbis.m4"
	rm -rf "${DESTDIR}/share/doc/libvorbis-${VORBIS_VERSION}"

	_done
}

# Build WebP
build_webp() {
	LIBNAME="WebP"

	_get "http://downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz"
	_cd "libwebp-${WEBP_VERSION}"
	_prepare "${LIBNAME}"
	_configure "${LIBNAME}" --disable-shared
	_build "${LIBNAME}"
	_install "${LIBNAME}"

	rm -rf "${DESTDIR}/bin/cwebp"
	rm -rf "${DESTDIR}/bin/dwebp"
	rm -rf "${DESTDIR}/lib/libwebp.la"
	rm -rf "${DESTDIR}/share/man/man1/cwebp.1"
	rm -rf "${DESTDIR}/share/man/man1/dwebp.1"

	_done
}


################################################################################
# Main
################################################################################


# build_pkgconfig
build_nasm

build_curl
build_freetype
build_geoip
build_glew
build_gmp
build_jpeg  # [deps: nasm]
build_lua
build_naclports
build_naclsdk
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
