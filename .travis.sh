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

# Travis CI support script


################################################################################
# Setup
################################################################################

# Arguments parsing
if [ $# -ne 1 ]; then
	echo "Usage: ${0} <STEP>"
	exit 1
fi


################################################################################
# Routines (linux)
################################################################################

# before_install
linux-before_install() {
	sudo add-apt-repository -y ppa:nschloe/cmake-backports
	sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
	sudo apt-get -qq update
}

# install
linux-install() {
	sudo apt-get -qq install cmake\
	                         cmake-data\
	                         gcc-4.7\
	                         g++-4.7\
	                         libasound2-dev\
	                         libgl1-mesa-dev\
	                         libpulse-dev\
	                         libx11-dev\
	                         libxext-dev\
	                         portaudio19-dev\
	                         nasm\
	                         zip
	sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 100\
	                         --slave   /usr/bin/g++ g++ /usr/bin/g++-4.7
}

# before_script
linux-before_script() {
	true
}

# script
linux-script() {
	./build-linux.sh
}

# before_deploy
linux-before_deploy() {
	find linux-* -name \*.pc -delete
	find linux-* -empty -delete
	zip -r9 --symlinks "${TRAVIS_OS_NAME}.zip" linux-*
}


################################################################################
# Routines (osx)
################################################################################

# before_install
osx-before_install() {
	brew update
}

# install
osx-install() {
	brew install coreutils\
	             gnu-sed\
	             gnu-tar
}

# before_script
osx-before_script() {
	true
}

# script
osx-script() {
	./build-osx.sh
}

# before_deploy
osx-before_deploy() {
	find osx-* -name \*.pc -delete
	find osx-* -empty -delete
	zip -r9 --symlinks "${TRAVIS_OS_NAME}.zip" osx-*
}


################################################################################
# Main
################################################################################

# Arguments check
if ! `declare -f "${TRAVIS_OS_NAME}-${1}" > /dev/null`; then
	echo "Error: unknown step \"${TRAVIS_OS_NAME}-${1}\""
	exit 1
fi

# Enable exit on error & display of executing commands
set -ex

# Run <STEP>
${TRAVIS_OS_NAME}-${1}
