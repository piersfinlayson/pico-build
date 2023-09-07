#!/bin/bash
set -e

# This script installs all of the necessary code and components on a machine to be able to build and flash Pico Python and C programs.
# It supports 

# There's three options below - Raspberry Pi OS 64-bit, Raspberry Pi OS 32-bit and x86_64.  Both assume you already have the OS and basic applications (like vi and git) installed.  Only the GNU ARM toolchain install varies between the architectures.

INSTALL_DIR=$1
if [ -z $INSTALL_DIR ] || [ $INSTALL_DIR = "-h" ] || [ $INSTALL_DIR = "-?" ] || [ $INSTALL_DIR = "-help" ] || [ $INSTALL_DIR = "--help" ]; then
  printf "Usage: %s <install_dir>\n" $0
  printf "  <install_dir> - base path you want the various components installed\n"
  printf "  Auto-detects architecture, supporting x86_64 (Ubuntu), and AArch64 and AArch32 (Raspberry Pi OS)\n"
  exit
fi

SUPPRESS_OUTPUT=""
#SUPPRESS_OUTPUT="1> /dev/null 2> /dev/null"

printf "Installing:\n  Pico C SDK\n  Picotool  \n  MicroPython\n"

# Install base packages:
printf "Installing base packages: %s\n" $BASE_PACKAGES
DEBIAN_FRONTEND=noninteractive sudo apt update ${SUPPRESS_OUTPUT}
BASE_PACKAGES="build-essential cmake coreutils pkg-config libusb-1.0-0-dev xz-utils git python3"
DEBIAN_FRONTEND=noninteractive sudo apt -y install $BASE_PACKAGES ${SUPPRESS_OUTPUT}

# Need coreutils to be able to detect architecture
printf "Detecting architecture\n"
ARCH=`arch`
if [ $ARCH = "armv6l" ] || [ $ARCH = "armv7l" ]; then
  ARCH="aarch32"
elif [ $ARCH != "x86_64" ] && [ $ARCH != "aarch64" ]; then
  printf "Unsupported architecture: %s\n" $ARCH
  exit
fi
printf "Architecture: %s\n" $ARCH

# Installing ARM GNU toolchain
printf "Installing ARM GNU toolchain\n"
mkdir -p ${INSTALL_DIR}
if [ $ARCH = "aarch32" ]; then
  TOOLCHAIN_PKGS="gcc-arm-none-eabi libnewlib-arm-none-eabi"
  DEBIAN_FRONTEND=noninteractive sudo apt -y install ${TOOLCHAIN_PKGS} ${SUPPRESS_OUTPUT}
  ln -s /usr ${INSTALL_DIR}/arm-gnu-toolchain
else
  TOOLCHAIN_VER="12.3.rel1"
  TOOLCHAIN="arm-gnu-toolchain-${TOOLCHAIN_VER}-$ARCH-arm-none-eabi"
  TOOLCHAIN_BASE_URL="https://developer.arm.com/-/media/Files/downloads/gnu/${TOOLCHAIN_VER}/binrel/${TOOLCHAIN}"
  wget "${TOOLCHAIN_BASE_URL}.tar.xz" -q --show-progress --progress=bar:force -O /tmp/${TOOLCHAIN}.tar.xz
  wget "${TOOLCHAIN_BASE_URL}.tar.xz.sha256asc" -q --show-progress --progress=bar:force -O /tmp/${TOOLCHAIN}.tar.xz.sha256asc
  cd /tmp
  sha256sum ${TOOLCHAIN}.tar.xz > /tmp/${TOOLCHAIN}.tar.xz.sha256asc.calculated
  if ! cmp -s "/tmp/${TOOLCHAIN}.tar.xz.sha256asc.calculated" "/tmp/${TOOLCHAIN}.tar.xz.sha256asc"; then
    printf "Checksum of downloaded toolchain is unexpected - exiting\n"
    exit
  fi
  unxz /tmp/${TOOLCHAIN}.tar.xz
  tar -x -f /tmp/${TOOLCHAIN}.tar -C ${INSTALL_DIR}/
  rm /tmp/${TOOLCHAIN}.tar*
  ln -s ${INSTALL_DIR}/${TOOLCHAIN} ${INSTALL_DIR}/arm-gnu-toolchain
fi
export PICO_TOOLCHAIN_PATH=${INSTALL_DIR}/arm-gnu-toolchain

# Get the SDK
printf "Getting the SDK\n"
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}
git clone https://github.com/raspberrypi/pico-sdk ${SUPPRESS_OUTPUT}
cd ${INSTALL_DIR}/pico-sdk
git submodule update --init ${SUPPRESS_OUTPUT}
export PICO_SDK_PATH=${INSTALL_DIR}/pico-sdk

# Getting Picotool
printf "Getting Picotool\n"
cd ${INSTALL_DIR}
git clone https://github.com/raspberrypi/picotool ${SUPPRESS_OUTPUT}

# Build and install Picotool
printf "Building and installing Picotool\n"
cd ${INSTALL_DIR}/picotool
cmake . ${SUPPRESS_OUTPUT}
make -j 4 ${SUPPRESS_OUTPUT}
sudo make install ${SUPPRESS_OUTPUT}
if [ ! -e /etc/udev ]; then
  printf "Don't update udev, as it doesn't exist"
else
  sudo cp udev/99-picotool.rules /etc/udev/rules.d/ ${SUPPRESS_OUTPUT}
  sudo udevadm control --reload-rules && sudo udevadm trigger ${SUPPRESS_OUTPUT}
fi

# Getting MicroPython
printf "Getting MicroPython\n"
cd ${INSTALL_DIR}
git clone https://github.com/MicroPython/MicroPython ${SUPPRESS_OUTPUT}
cd ${INSTALL_DIR}/MicroPython
make -C ports/rp2 submodules BOARD=RPI_PICO_W ${SUPPRESS_OUTPUT}

# Build MicroPython
printf "Building MicroPython\n"
make -C mpy-cross ${SUPPRESS_OUTPUT}
make -C ports/rp2 -j 4 BOARD=RPI_PICO_W

# Set .bashrc file
if [ ! -e "~/.bashrc" ]; then
  touch ~/.bashrc
fi
echo "export PICO_SDK_PATH=${INSTALL_DIR}/pico-sdk" >> ~/.bashrc
echo "export PICO_TOOLCHAIN_PATH=${INSTALL_DIR}/arm-gnu-toolchain" >> ~/.bashrc

# Finished
printf "Installed:"
printf "  Pico C SDK: %s\n" ${INSTALL_DIR}/pico-sdk
printf "  Picotool: %s\n" ${INSTALL_DIR}/picotool
printf "  MicroPython\n" ${INSTALL_DIR}/MicroPython
printf "The following have been added to ~/.bashrc:\n"
printf "  PICO_SDK_PATH=%s\n" ${INSTALL_DIR}/pico-sdk
printf "  PICO_TOOLCHAIN_PATH=%s\n" ${INSTALL_DIR}/arm-gnu-toolchain
printf "Restart your shell to pick these up or export them manually now using:\n"
printf "  export PICO_SDK_PATH=%s\n" ${INSTALL_DIR}/pico-sdk
printf "  export PICO_TOOLCHAIN_PATH=%s\n" ${INSTALL_DIR}/arm-gnu-toolchain
