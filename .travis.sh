#!/bin/bash

# Travis CI support script


# Arguments parsing
if [ $# -ne 2 ]; then
	echo "Usage: ${0} <PLATFORM> <STEP>"
	exit 1
fi

# Enable exit on error & display of executing commands
set -ex


# Routines ---------------------------------------------------------------------

# linux64

# before_install
linux64-before_install() {
	sudo add-apt-repository -y ppa:smspillaz/cmake-2.8.12
	sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
	sudo apt-get -qq update
}

# install
linux64-install() {
	sudo apt-get -qq install cmake cmake-data gcc-4.7 g++-4.7 libasound2-dev libgl1-mesa-dev libx11-dev libxext-dev nasm zip
}

# before_script
linux64-before_script() {
	sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 100 --slave /usr/bin/g++ g++ /usr/bin/g++-4.7
}

# script
linux64-script() {
	./build-linux64.sh
}

# before_deploy
linux64-before_deploy() {
	find "linux64-${DEPS_VERSION}" -name "*.pc" -delete
	find "linux64-${DEPS_VERSION}" -empty -delete
	tar cJvf "${ARCHIVE}" "linux64-${DEPS_VERSION}"
}


# Main -------------------------------------------------------------------------

"${1}-${2}"
