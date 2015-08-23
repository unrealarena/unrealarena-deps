#!/bin/bash

# Travis CI support script


# Arguments parsing
if [ $# -ne 1 ]; then
	echo "Usage: ${0} <STEP>"
	exit 1
fi


# Routines (linux) -------------------------------------------------------------

linux-before_install() {
	sudo add-apt-repository -y ppa:smspillaz/cmake-2.8.12
	sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
	sudo apt-get -qq update
}

linux-install() {
	sudo apt-get -qq install cmake cmake-data gcc-4.7 g++-4.7 libasound2-dev libgl1-mesa-dev libx11-dev libxext-dev nasm zip
	sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 100 --slave /usr/bin/g++ g++ /usr/bin/g++-4.7
}

linux-before_script() {
	true
}

linux-script() {
	./build-linux.sh
}

linux-before_deploy() {
	find "linux64-"* -name "*.pc" -delete
	find "linux64-"* -empty -delete
	zip -r9 "deps-linux.zip" "linux64-"*
}


# Main -------------------------------------------------------------------------

# Arguments check
if ! `declare -f "${TRAVIS_OS_NAME}-${1}" > /dev/null`; then
	echo "Error: unknown step \"${TRAVIS_OS_NAME}-${1}\""
	exit 1
fi

# Enable exit on error & display of executing commands
set -ex

# Run <STEP>
${TRAVIS_OS_NAME}-${1}
